module MmCategoryUpdate
  extend MootLogs

  class Mmtemp < ActiveRecord::Base
    extend MootLogs
    @@tempNum = 0
    @@in_use = false
    #when subclassing make own stub

    def self.stub
      return ""
    end

    def self.baseTable
      return ""
    end

    def self.customize
      nil
    end

    def self.create_table(id = false)
      table_name = "mmtemp_#{@@tempNum}#{stub}"
      @@tempNum += 1
      p "tn: #{table_name}, id: #{id}"
      id = :integer if id == true
      if baseTable != ""
        ActiveRecord::Migration::create_table table_name.to_sym(), temporary: true, id: id, options: "( LIKE #{baseTable} )"
      else
        #got some weird errors so.
        if id
          ActiveRecord::Migration::create_table table_name.to_sym(), temporary: true, id: id
        else
          ActiveRecord::Migration::create_table table_name.to_sym(), temporary: true, id: id, options: "()"
        end
      end
      self.table_name = table_name
      self.customize
    end

    def self.failSafe(id = false)
      begin
        #raise StandardError.new("temp table needs to be LIKE other table. Subclass and override baseTable method") if baseTable == ""
        raise StandardError.new("make a new class if you are multithreading, class does not support multiple threads.") if @@in_use == true
        @@in_use = true
        self.create_table(id)
        yield
      rescue Exception => e
        p "catch in failsafe"
        p e.class
        p e.message
        p e.backtrace
        raise e
      ensure
        ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{self.table_name}")
        @@in_use = false
      end
    end
  end

  class Blatemp < Mmtemp
    def self.baseTable
      return "mmbillaffects"
    end
    def self.stub
      return "bla"
    end
  end

  class MmTagTemp < Mmtemp
    def self.baseTable
      return "topic_tags"
    end
    def self.stub
      return "tt"
    end
  end

  class Rctemp < Mmtemp
    def self.baseTable
      return "mmrollcalls"
    end
    def self.stub
      return "rc"
    end
  end

  class Bltemp < Mmtemp
    def self.baseTable
      return "mmbills"
    end
    def self.stub
      return "bl"
    end
  end

  class MmPostTemp < Mmtemp
    def self.stub
      return "pst"
    end
    def self.customize
      #id autocreated
      #ActiveRecord::Migration::add_column self.table_name.to_sym, :id, :integer
      ActiveRecord::Migration::add_column self.table_name.to_sym, :cooked, :text
      ActiveRecord::Migration::add_column self.table_name.to_sym, :raw, :text
      ActiveRecord::Migration::add_column self.table_name.to_sym, :updated_at, :datetime
      ActiveRecord::Migration::add_column self.table_name.to_sym, :word_count, :integer
    end
  end

  class MmTopicTemp < Mmtemp
    def self.stub
      return "tpc"
    end
    def self.customize
      #id autocreated
      #ActiveRecord::Migration::add_column self.table_name.to_sym, :id, :integer
      ActiveRecord::Migration::add_column self.table_name.to_sym, :title, :text
      ActiveRecord::Migration::add_column self.table_name.to_sym, :slug, :text
      ActiveRecord::Migration::add_column self.table_name.to_sym, :fancy_title, :text
      ActiveRecord::Migration::add_column self.table_name.to_sym, :updated_at, :datetime
      ActiveRecord::Migration::add_column self.table_name.to_sym, :word_count, :integer
    end
  end

  class MmIdTemp < Mmtemp
    def self.stub
      return "id"
    end
    def self.customize
      #just holds ids
    end
  end

  class BlIdTemp < Mmtemp
    def self.stub
      return "blid"
    end
    def self.customize
      ActiveRecord::Migration::add_column self.table_name.to_sym, :bill_id, :string
    end
  end

  class RcExstTemp < Mmtemp
    def self.stub
      return "rcexst"
    end
    def self.customize
      ActiveRecord::Migration::add_column self.table_name.to_sym, :bill_id, :string
    end
  end

  #def postgresql_bulk_post_topic_update(lst)
  #  TopicsBulkAction.postgresql_bulk_post_topic_update(lst)
  #end

  class TopicsBulkAction
    extend MootLogs
    def self.getSlug(tit) #tit=title
      slug_len_limit = 90 #set ideal length
      slug_len_limit = tit.length if tit.length < 90 #edge case for short stuff
      tit = tit.gsub(/\s+/m, ' ').gsub(/^\s+|\s+$/m, '').gsub('-', ' ').split(' ') #kill unnessesary white space, change - to " ", split
      slg = tit[0] #add first word in case its just like, one long word ?
      titPlc = 1 
      while slg.length < slug_len_limit and titPlc < tit.length
        slg << "-" + tit[titPlc] #add words until its long
      titPlc += 1; end
      slg = slg.gsub(/[^a-zA-Z0-9]/i, '').downcase #kill any weirdness
      return slg
    end
    def self.postgresql_bulk_post_topic_update(lst, category_name)
      # input
      #   -lst of hashes containing cooked, post_id, topic_id, title, updated_at, tags (raw will point to cooked)
      #   [{post_id: #, cooked: "", topic_id: #, title: "", updated_at: date_time, tags: [{tag: "", tagGroup: ""}, ... ] } ,  ... ]
      #   -category_name, the name of the category being updated. This is used for search indexing.

      # optional hash attributes to include in list items:
      #   -raw, if not included will be equal to cooked.
      #   -fancy_title, if not included will be equal to title
      #   -slug, if not included will be processed from title (this is related to its url)

      #use case, updating topics regularly from a changing non-discourse backend datasource in an efficient manner
      #to mirror updating information. Note that this is not made for general post or topic posting, but for updating
      #topic's title, and the topic's MAIN post. For general post revision, go to PostRevisor in lib/post_revisor.rb

      # - Assumes pre-cooked, custom cooked, or viewed as-is. Data is not validated.
      # - posts should have (cook_methods: Post.cook_methods[:raw_html]) set on creation if your raw == cooked.
      #     You would do this if you are writing custom html to display inside the post. 
      #     Otherwise discourse may re-cook it in the future which would be bad. Make sure source of information
      #     is trusted and its contents escaped.
      # - If the above is not ideal, then make sure to include raw, set the correct cook method in your post's creation
      #     (in case system re-cooks) run raw through your chosen cook method, and include raw, and the outputted cooked
      #     in your hashes.
      # - Keeps track of word_count through noting differences in the before and after word counts of the post, and passing that
      #     to the topic.
      
      #were the optional tags included?

      ActiveRecord::Base.transaction do
          
        if lst[0].keys.include?(:raw)
          rawPoints = :raw
        else
          rawPoints = :cooked
        end
        if lst[0].keys.include?(:fancy_title)
          fancyPoints = :fancy_title
        else
          fancyPoints = :title
        end
        if not lst[0].keys.include?(:slug)
          #uniqueness does not matter on this, just needs to make a nice url.
          x=0; while x < lst.length;
            lst[x][:slug] = self.getSlug(lst[x][:title])
          x+=1; end
        end
        x = 0; while x < lst.length
          lst[x][:word_count] = lst[x][rawPoints].scan(/[[:word:]]+/).size
        x+=1; end

        #do the update, get return values
        p "entering posts"
        postsInf = lst.map(){ |li| { id: li[:post_id], cooked: li[:cooked], raw: li[rawPoints], updated_at: li[:updated_at], word_count: li[:word_count] } }
        opts = {
          returnCols: [:id, {func: :difference, vars: {col: :word_count}, out: :wordDif} ], 
          whereCols: [ {func: :skip, col: :word_count}, {func: :skip, col: :updated_at} ]
        }
        changedPosts_wordDif = self.postgresql_bulk_post_update( postsInf, opts ) #category_name is for search indexing

        #map results back into list
        post_id_to_word_dif = changedPosts_wordDif.map{|li| [li[:post_id], li[:wordDif]] }.to_h
        x=0; while x < lst.length;
          po_id = lst[x][:post_id]
          wdif = post_id_to_word_dif[ po_id ]
          if wdif.nil?
            lst[x][:wordDif] = 0
          else
            lst[x][:wordDif] = wdif
          end
        x+=1; end
        
        p "entering topics"
        #cooked needed for search indexing. 
        topicsInf = lst.map(){ |li| { id: li[:topic_id], title: li[:title], fancy_title: li[fancyPoints], slug: li[:slug], updated_at: li[:updated_at], word_count: li[:wordDif] } }
        opts = {
          setCols: [{func: :addition, col: :word_count }], #adds temp word_count (aka wordDif) to the topics pre-existing word_count
          whereCols: [{func: :skip, col: :word_count}, {func: :skip, col: :updated_at} ]
        } #customizing the SET part of the update for word_count column
        changedTopics = self.postgresql_bulk_topic_update( topicsInf, opts)

        for item in lst
          #maybe convert to bulk if it takes a while ? ? ? ? ? / ? ? ? ? = 5/4 * ? Whatever, seems fast enough for my purposes.
          #if they had a seperate format function I would have but
          SearchIndexer.update_posts_index(item[:post_id], item[:title], category_name, item[:tags].map{|t| t[:tag]}.join(' '), item[:cooked])
          SearchIndexer.update_topics_index(item[:topic_id], item[:title], item[:cooked])
        end
        
        if lst[0].keys.include?(:tags)
          hasssssh = {}
          for li in lst
            hasssssh[li[:topic_id]] = li[:tags]
          end
          self.postgresql_bulk_unsafe_tagging(hasssssh) #index happens in here too.
        end
        return [post_id_to_word_dif.keys, changedTopics]
      end
    end
    def self.postgresql_bulk_post_update(lst, opts = {})
      #need word count difference for topic word_count update
      #outputs id and wordDif
      returnedInfo = self.private_postgresql_bulk_update(lst, mainTable=Post, tempTable=MmPostTemp, opts = opts)
      return returnedInfo
    end
    def self.postgresql_bulk_topic_update(lst, opts = {})
      returnedInfo =  self.private_postgresql_bulk_update(lst, mainTable=Topic, tempTable=MmTopicTemp, opts = opts)
      return returnedInfo
    end
    def self.private_postgresql_bulk_update(lst, mainTable, tempTable, opts = {} )
      
      #This function is made to be customizeable through its options and case statements.
      #     look at :diffrence, :addition, and :skip
      #The temptable expected should be a subclass of Mmtemp
      #The maintable should be whatever you want it to be.

      opts = {pk: :id, returnCols: [], setCols: [], whereCols: []}.merge(opts)
      returnCols = opts[:returnCols]
      setCols = opts[:setCols]
      whereCols = opts[:whereCols]
      pk = opts[:pk]

      #should we create the id column in the temp table?
      pk.to_sym == :id ? id = true : id = false
      tempTable.failSafe(id){
        columns = lst[0].keys
        raise StandardError("column needs to include primary key (id)") unless columns.include?(pk)
        
        #get the RETURN part of the sql statement
        sqlRet = ""
        #in case not added upstream
        returnCols << pk.to_sym if not returnCols.include?(pk.to_sym)

        for col in returnCols
          if col.class == Hash
            # if we want to do custom return functions, throw in a hash with the variables desired. You can then put the function in the case statement below.
            vars = col[:vars] if col.include?(:vars)
            out = col[:out]
            case col[:func]
            when :difference
              sqlRet += "( #{tempTable.table_name}.#{vars[:col].to_s} - #{mainTable.table_name}.#{vars[:col].to_s} ) AS #{out.to_s}, "
            end
          else
            sqlRet += "#{mainTable.table_name}.#{col.to_s}, "
          end
        end
        sqlRet = sqlRet[0...sqlRet.length - 2] #kill trailing ,
        
        #get the SET part of the sql statement
        p setCols
        sqlSet = ""
        removeCols = setCols.map{|statement| statement[:col]}
        setCols += columns
        setCols -= removeCols # makes sure our statement overrides the default
        p setCols
        for col in setCols
          next if col == pk
          #for the custom statements
          if col.class == Hash
            vars = col[:vars] if col.include?(:vars)
            column = col[:col]
            case col[:func]
            when :addition
              sqlSet += " #{column.to_s} = ( #{mainTable.table_name}.#{column.to_s} + #{tempTable.table_name}.#{column.to_s} ), "
            end
          else
            sqlSet += "#{col.to_s} = #{tempTable.table_name}.#{col.to_s}, "
          end
        end
        sqlSet = sqlSet[0...sqlSet.length - 2] #kill trailing ,
        p "sqlSet: #{sqlSet}"
        
        #get the WHERE part of the sql statement
        sqlWhere = ""
        removeCols = whereCols.map{|statement| statement[:col]}
        whereCols += columns
        whereCols -= removeCols # makes sure our statement overrides the default
        for col in columns
          next if col == pk or col.to_sym == :updated_at #if it was updated, but nothing changed, then it wasn't really updated.
          if col.class == Hash
            vars = col[:vars] if col.include?(:vars)
            column = col[:col]
            case col[:func]
            when :skip
              nil
            end
          else
            sqlWhere += "#{tempTable.table_name}.#{col.to_s} != #{mainTable.table_name}.#{col.to_s} OR "
          end
        end
        sqlWhere = sqlWhere[0...sqlWhere.length - 3] #kill trailing or
        p "sqlWhere: #{sqlWhere}"
        
        #we move the data to the temptable, and then from the temptable to the actual table if its different.
        tempTable.insert_all(lst)
        sqlStr = %Q{
          UPDATE #{mainTable.table_name}
          SET #{sqlSet}
          FROM #{tempTable.table_name}
          WHERE #{tempTable.table_name}.#{pk} = #{mainTable.table_name}.#{pk} AND ( #{sqlWhere} )
          RETURNING #{sqlRet}
        }
        p "update sql #{sqlStr}"
        actualChange = ActiveRecord::Base.connection.execute(sqlStr)
        
        #format return information based on returnCols
        returns = []
        x = 0; while x < actualChange.ntuples
          ac = {}
          for col in returnCols
            col = col[:out] if col.class == Hash
            ac[col] = actualChange.tuple(x)[col.to_s]
          end
          returns << ac
        x+=1; end
        return returns
      }
    end
    def self.attachTags(tags)
      #puts "#{self}"
      tagNameList = [] #[tag, tag, tag] format
      for tag in tags
        tgroup = TagGroup.find_by(name: tag[:tagGroup])
        if tgroup == nil
          #puts "this should only print once, creating system_tags tag group"
          tgroup = TagGroup.create!({name: tag[:tagGroup]})
        end
        tagNameList << tag[:tag]
        begin 
          tgroup.tag_names=([tag[:tag]])
        rescue ActiveRecord::RecordInvalid => e
          unless e.message.include?("Name has already been taken")
            raise e
          end
        end
      end
      return tagNameList
    end
    def self.postgresql_bulk_unsafe_tagging(topic_id_tag_list_hash)
      #we are connecting it topic in efficient manner
      #map names to ids sequentially since prob low number of tags (relatively)
      
      titnh = topic_id_tag_list_hash #hate long names
      if titnh.keys.length == 0
        return
      end
      #if tagGroup does not exist, set to system_tags
      titnh = titnh.map{|k, l| 
        l.map!{ |t|
          t[:tagGroup] = "system_tags" unless t.keys.include?(:tagGroup)
          #mutilate tags to fit discourse settings (max len 30, stick to basic chars, no spaces.
          t[:tag] = t[:tag].gsub(/[^a-zA-Z0-9\_\- ]/i, '') #should probably replace with discourses tag string filter function... but cant find it so yeah.
          if t[:tag].length > 30
            t[:tag] = t[:tag][0...30]
          end
          next t
        }
        next [k, l]
      }.to_h
      #create tag groups and tags. Get unique tag names without the groups
      logWatch("titnh"){ p "titnh: #{titnh.inspect}" }
      tags_names_groups = titnh.map{|k, v| v }.flatten.uniq
      tag_names = self.attachTags(tags_names_groups) #create both groups and names, return names.
      #p "tag names: #{tag_names}"
      #get unique_tag_names => tag_id hash
      name_to_id = {}
      tag_names.map{ |v|
        #p "name: #{v}"
        begin
          id = Tag.find_by(name: v).id
        rescue NoMethodError => e
          logWatch("database_irregularities") {
            p "tagName: #{v} has no ID. (Does it mesh with the discourse tagname settings?)"
          }
        end
        name_to_id[v] = id
      }
      p name_to_id #<------------------------------------------ turn this off once its figured out
      #format data (id will be default)
      sqlFormat = []
      time = Time.now
      i = 0
      for topicId in titnh.keys
        y=0; while y < titnh[topicId].length
          i += 1
          #replace each tag name with its id
          #get the id of [ topic Id's #y's tagname ]
          tagId = name_to_id[ titnh[topicId] [y] [:tag] ]
          raise StandardError.new("#{i}-#{tagId}-#{topicId}-#{y}-#{titnh[topicId]}-#{titnh[topicId][y]}") if tagId.nil?
          #put in sql format for temp table upsert
          sqlFormat << {id: i, topic_id: topicId, tag_id: tagId, created_at: time, updated_at: time}
        y+=1; end
      end
      
      MmTagTemp.failSafe{
        tmp = MmTagTemp
        MmTagTemp.insert_all(sqlFormat)
        ActiveRecord::Base.transaction do
          #delete tags which have been removed
          sqlStr = %Q{
            DELETE FROM topic_tags
            WHERE topic_id IN (SELECT topic_id FROM #{tmp.table_name}) AND
              tag_id NOT IN (SELECT tag_id FROM #{tmp.table_name} WHERE #{tmp.table_name}.topic_id = topic_tags.topic_id)
            RETURNING tag_id
          }
          p "update sql #{sqlStr}"
          deIncrementThese = ActiveRecord::Base.connection.execute(sqlStr)
          #record removals for tags by tag id
          tagCountDif = {}
          x=0; while x < deIncrementThese.ntuples();
            tagId = deIncrementThese.tuple(x)['tag_id']
            if tagCountDif[tagId].nil?
              tagCountDif[tagId] = 0
            end
            tagCountDif[tagId] -= 1
          x+=1;end
          p "tagCountDif (-): #{tagCountDif.inspect}"
          #insert tags that have been added
          sqlStr = %Q{
            INSERT INTO topic_tags(topic_id, tag_id, created_at, updated_at)
            SELECT topic_id, tag_id, created_at, updated_at
            FROM #{tmp.table_name}
            WHERE #{tmp.table_name}.tag_id NOT IN (SELECT tag_id FROM topic_tags WHERE #{tmp.table_name}.topic_id = topic_tags.topic_id )
            RETURNING tag_id
          }
          p "update sql #{sqlStr}"
          incrementThese = ActiveRecord::Base.connection.execute(sqlStr)
          #record additions
          x=0; while x < incrementThese.ntuples();
            tagId = incrementThese.tuple(x)['tag_id']
            if tagCountDif[tagId].nil?
              tagCountDif[tagId] = 0
            end
            tagCountDif[tagId] += 1
          x+=1; end
          p "tagCountDif (-+): #{tagCountDif.inspect}"
          #once again relatively less amount of tags to topics validates sequential use. Though speedup could be
          #acheived through use of a seperate temp table both here and above.
          for key in tagCountDif.keys
            tg = Tag.find_by(id: key)
            tg.topic_count += tagCountDif[key]
            #update the search index.
            SearchIndexer.update_tags_index(key, tg.name)
          end
        end
      }
    end
  end

  def self.bills_exists(lst)
    return which_exists(lst, "bill_id", ["topic_id"], Mmbill, BlIdTemp)
  end

  def self.bill_votes(lst_bill_ids)
    #for use when the
    lst = lst_bill_ids
    rollcalls = Mmrollcall.where("bill_id IN ? AND question = ?", lst, 'On Passage')
    rollcallvotes = Mmrollcallvote.where("mmrollcall_id IN ?", rollcalls.map{|rc| rc.mm_primary})
    return rollcallvotes
    #return which_exists(lst, "bill_id", ["mm_primary"], Mmrollcall, RcIdTemp, { appendToWhere: "AND question = \'On Passage\'" })
  end

  def self.roll_calls_exists(lst)
    #here we are getting rollcalls related to a bill where the question is 'On Passage'
    return which_exists(lst, "bill_id", ["question", "roll_call", "topic_id", "date", "time"], Mmrollcall, RcExstTemp)
  end

  def self.which_exists(id_lst, pk, otherReturns, mainTable, tempTable, opts = {})
    opts = {appendToWhere: ""}.merge(opts)
    pk == "id" ? id = true : id = false
    tempTable.failSafe(id){
      id_lst.map!{ |id| {pk.to_sym => id} }
      tempTable.insert_all(id_lst, returning: false)
      sqlStr = %Q{
        SELECT #{pk} #{"," if otherReturns.length > 0} #{otherReturns.join(", ")} FROM #{mainTable.table_name}
        WHERE #{mainTable.table_name}.#{pk} IN (SELECT #{pk} FROM #{tempTable.table_name}) #{opts[:appendToWhere]}
      }
      idTuples = ActiveRecord::Base.connection.execute(sqlStr)
      verifiedIds = []
      x=0; while x < idTuples.ntuples;
        ret = {}
        ret[pk] = idTuples.tuple(x)[pk]
        i = 0; while i < otherReturns.length;
          ret[otherReturns[i]] = idTuples.tuple(x)[otherReturns[i]]
        i += 1; end
        verifiedIds << ret
      x+=1; end
      return verifiedIds
    }
  end

  def sqlHurts(nameList, splitter, comp, beforeFirst, beforeSecond)
    sqlList = ""
    x = 0; while x < nameList.length
      sqlList << "#{beforeFirst}#{nameList[x]} #{comp} #{beforeSecond}#{nameList[x]}"
      x != nameList.length - 1 ? sqlList << splitter : nil
    x+=1; end
    return sqlList
  end

  def updateHelper(mainClass, tempClass, lst, updateColumns=nil, foreign_key="id")
    tempClass.failSafe{

      #  
      #                         debug for duplicate uniques
      #

      ids = lst.map{|hashy| hashy[foreign_key]}
      uniques = {}
      ids.map{ |id|
        uniques[id] == nil ? uniques[id]=0 : nil
        uniques[id]+=1
      }
      uniqueVals = uniques.keys.length
      dups = uniques.select { |k, v| v > 1 }
      v = 7
      if v >= dups.length
        v = dups.length
      end
      if v > 0
        logWatch("database_irregularities") {
          p "DUPLICATES DETECTED (confirm externaly in bash with curl)"
          p "num ids: #{ids.length}"
          p "unique ids: #{uniqueVals}"
          p "dup ids: #{dups.length}"
          p "ratio dups/unique: #{dups.length / uniqueVals}"
          p "first <=7 dups: #{dups.first(v).inspect}"
          p "fixing and continuing"
        }
        keyVals = {}
        lst.map{|v| keyVals[v[foreign_key]] = v}
        lst = keyVals.map{|k,v| v}
      end

      #
      #                         debug for missing keys
      #

      mismatches = lst.select{|hash| hash.keys.length != updateColumns.length }
      if mismatches.length >= 1
        MootLogs::MootLogging.watch("keysMissing", {overwrite: true}) { |l|
          l.puts "MISMATCHES"
          l.puts "number of items with wrong key length #{mismatches.length}"
          l.puts "colnames: #{mismatches.map{|hsh| hsh.map{|k, v| k}}}"
          l.puts "all: #{mismatches}"
        }
      end

      #
      #                         debug for false updates
      #

      #same = 0
      #dif = 0
      #for bill in lst
        #db_bill = Mmbill.find_by(bill_id: bill[:bill_id])
        #next if db_bill.nil?
        #if bill[:bulk] == db_bill.bulk
          #logWatch("bill_same") {
            #p "---------------------------------------------------------------------"
            #p "DB BILL #{db_bill.bill_id}"
            #p "---------------------------------------------------------------------"
            #pp(db_bill.bulk)
            #p "---------------------------------------------------------------------"
            #p "BILL #{bill[:bill_id]}"
            #p "---------------------------------------------------------------------"
            #pp(bill[:bulk])
          #}
          #same += 1
        #else
          #logWatch("bill_dif") {
            #p "---------------------------------------------------------------------"
            #p "DB BILL #{db_bill.bill_id}"
            #p "---------------------------------------------------------------------"
            #pp(db_bill.bulk)
            #p "---------------------------------------------------------------------"
            #p "BILL #{bill[:bill_id]}"
            #p "---------------------------------------------------------------------"
            #pp(bill[:bulk])
          #}
          #dif += 1
        #end
      #end
      #p "same: #{same}"
      #p "diffrent: #{dif}"

      #
      #                         debug for issues related to bulk having a string instead of hash
      #

      #p "inspecting the first line of update -- "
      #a = lst[0]
      #for k in a
        #pr "#{k.class}: "
        #s = k.inspect()
        #s.length > 90 ? p(s[0...90]) : p(s)
      #end
            

      #
      #                         get to the actual function
      #

      tempClass.create_table
      updateColumns == nil ? updateColumns = mainClass.column_names : nil
      #p "lst - #{lst[0...10]}..."
      #p "lstCols #{lst[0].keys}"
      #p "maincols #{mainClass.column_names}" 
      #p "tempcols #{tempClass.column_names}"
      tempClass.insert_all(lst, returning: false)
      sqlSet = sqlHurts(updateColumns - [:created_at], ", ", "=", "", tempClass.table_name + "." ) #col1 = temptable.col1, col2 = temptable.col2
      sqlWhere = sqlHurts(updateColumns - [:created_at, :updated_at, foreign_key], " OR ", "!=", tempClass.table_name + ".", mainClass.table_name + ".") #temptable.col1 != table.col2 OR temptable.col1 != table.col2

        #UPDATE table
        #SET col1 = temptable.col1, col2 = temptable.col2 #with created_at excluded from cols (notably with updated_at)
        #FROM temptable
        #WHERE table.key = temptable.key AND ( temptable.col1 != table.col2 OR temptable.col1 != table.col2 )
      # INNER JOIN #{tempClass.table_name} ON #{mainClass.table_name}.#{foreign_key} = #{tempClass.table_name}.#{foreign_key}
      sqlStr = %Q{
        UPDATE #{mainClass.table_name}
        SET #{sqlSet}
        FROM #{tempClass.table_name}
        WHERE  #{tempClass.table_name}.#{foreign_key} = #{mainClass.table_name}.#{foreign_key} AND ( #{sqlWhere} )
        RETURNING #{mainClass.table_name}.*;
      }
      p "update sql #{sqlStr}"
      updateThese = ActiveRecord::Base.connection.execute(sqlStr)
      sqlStr = %Q{
        INSERT INTO #{mainClass.table_name}
        (SELECT * FROM #{tempClass.table_name}
        WHERE #{tempClass.table_name}.#{foreign_key} NOT IN (SELECT #{foreign_key} FROM #{mainClass.table_name}))
        RETURNING *
      }
      p "create sql #{sqlStr}"
      createThese = ActiveRecord::Base.connection.execute(sqlStr)
      return {updateThese: updateThese, createThese: createThese}
    }
  end

  @@categoryIds = {}

  def getCatId(name)
    if @@categoryIds[name] == nil
      cats = Category.where(name: name)
      ids = []
      for c in cats
        ids.append(c.id)
      end
      #pretty sure that object ids in ROR go from smallest to largest in order of creation
      if ids.length == 0
        raise ActiveRecord::RecordInvalid
      end
      @@categoryIds[name] = ids.min
    end
    return @@categoryIds[name]
  end
  
  def attachTags(tags)
    TopicsBulkAction.attachTags(tags)
  end

  def clearJobLeftovers(classy, pk=:mm_primary)
    #call this before anything related to upserts,
    #the result of a ton of debugging, its because the job manager quits on interupt
    #    before completion
    #note that there may be one or two posts without a father depending
    p "deleting incomplete #{classy}"
    sqlStr = %Q{
      SELECT *
      FROM #{classy.table_name}
      WHERE post_id IS NULL OR topic_id IS NULL
    }
    delMe = ActiveRecord::Base.connection.execute(sqlStr)
    x = 0; while x < delMe.ntuples
      t = delMe.tuple(x)
      if t['post_id'] != nil
        Post.find_by(id: t['post_id']).destroy!
      end
      if t['topic_id'] != nil
        Topic.find_by(id: t['post_id']).destroy!
      end
      pr "-"
      classy.find_by(classy.primary_key.to_sym => t[classy.primary_key.to_s]).destroy!
    x+=1; end
    
    #x+=1; end
    #trashy = classy.where("post_id IS NULL OR topic_id IS NULL")
    #p trashy.inspect
    #for b in trashy
      #pr "-del"
      #tp = Topic.find_by(id: b.topic_id)
      #if tp != nil
        #tp.delete!()
      #end
      #pst = Post.find_by(id: b.post_id)
      #if pst != nil
        #pst.destroy!()
      #end
      #b.destroy!()
    #end
    #p("")
  end
end
