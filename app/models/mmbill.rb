# frozen_string_literal: true

require 'json'
require 'date'
require 'time'

class Mmbill < ActiveRecord::Base
  #has_many :bvotes, dependant: :delete_all
  extend MmCategoryUpdate
  extend MootLogs
  self.primary_key= "bill_id"
  has_many :mmbill_affect
  has_one :post, through: :post_id, dependent: :destroy
  has_one :topic, through: :topic_id, dependent: :destroy
  #belongs_to :post, through: :post_id, dependent: :destroy
  #belongs_to :topic, through: :topic_id, dependent: :destroy

  #as multiple inheritence is not allowed in ruby - - - 
  #def self.getCatId(); ::MmCategoryUpdate::getCatId(Mmbill, "Bills"); end
  #def self.attachTags(tags); ::MmCategoryUpdate::attachTags(tags) ; end
  #def self.clearJobLeftovers(); ::MmCategoryUpdate::clearJobLeftovers(Mmbill, :bill_id); end

  @@defaults = {
      bill_id: nil,
      do_reformat: nil,
      bulk: nil,
      post_id: nil,
      topic_id: nil,
    }

  @@update_times = {
    total: 0,
    tag: 0,
    title: 0,
    body: 0
  }

  @@bulk_tracked = [
    "actions",
    "bill_type",
    "number",
    "congress",
    "summary",
    "history",
    "sponsor",
    "short_title",
    "titles",
    "official_title",
    "introduced_at",
    "moot_tagging"
  ]

  ATTR = {
    categoryId: nil
  }

  def self.defaults
    #since the pointer is constant but not the actual end values.
    return @@defaults.dup
  end
  def self.bulk_tracked
    return @@bulk_tracked.dup
  end

  def self.propublicaUpdateCols
    cols = @@defaults.keys.map {|a| a.to_sym}
    return cols - [:topic_id, :post_id] + [:created_at, :updated_at]
  end

  def self.bumpWhenChanged
    return false
  end

  def bumpWhenChanged()
    Mmbill.bumpWhenChanged()
    #if final[:latest_major_action_date] != self.latest_major_action_date or
    #  final[:latest_major_action] != self.latest_major_action
    #  return true
    #else
    #  return false
    #end
  end

  def getCooked
    Mmbill.getCooked(self.bulk.dup, self.bill_id.dup)
  end

  def self.getCooked(bulk, bill_id)
    #check valid
    #Get list of bill links during lifetime, mark with the stat.
    pdfUrl = "/meritmoot/bills/pdf?billtype=#{bulk['bill_type']}&billnum=#{bulk['number']}&congress=#{bulk['congress']}"
    iframeLnk = "<iframe src=\"#{pdfUrl}\" style=\"border: 1px solid #666CCC\" frameborder=\"1\" scrolling=\"auto\" height=\"800\" width=\"100%\"> pdf not viewable on current browser </iframe>"
    #get the actions
    actList = ""
    acts = bulk["actions"].sort{ |a, b| Time.parse(b["acted_at"]).to_i() <=> Time.parse(a["acted_at"]).to_i() }
    a = 0; while a < acts.length()
      act = acts[a]
      actList += "<li>"
      act['acted_at'] ? actList += "<p> #{Time.parse(act['acted_at']).strftime("%B %d %Y %I:%M%p")} <br/>" : nil
      act['text'] ? actList += "#{act['text']}<br/>" : nil
      act['roll'] ? actList += "#{act['roll']}<br/>" : nil #(connect to mmrolls)
      #connect through preprocessing in the process bills step.
      #act['vote_type'] ? actList += "#{act['vote_type']}<br/>" : nil
      #act['status'] ? actList += "#{act['status']}" : nil
      #act['bill_ids'] ? actList += "#{act['bill_ids']}<br/>" : nil #(connect to other mmbill)
      #connect through preprocessing in the process bills step.
      #act['action_code'] ? actList += "<p> #{act['action_code']} </p>" : nil
      actList += "</p> </li>"
    a += 1; end

    #puts "billId: #{self.bill_id}"
    #DO NOT TABULATE BELOW
    if bulk['summary']
      bulk['summary']['as'] ? as = bulk['summary']['as'] : as = ""
      bulk['summary']['date'] ? date = Time.parse(bulk['summary']['date']).strftime("%B %d %Y %I:%M%p") : date = ""
      bulk['summary']['text'] ? txt = bulk['summary']['text'] : txt = ""
      inf = "<p>#{as} - #{date}</p>
<p>#{txt}</p>"
    else
      inf = ""
    end
    sponsTit = bulk['sponsor']['title']
    sponsNme = bulk['sponsor']['name']
    sponsState = bulk['sponsor']['state']
    title = bulk['official_title']
    #DO NOT TABULATE
    ret = "<h3>#{title}</h3>
#{inf}
<p></p>
<p>#{sponsTit} #{sponsNme} - #{sponsState}</p>
#{iframeLnk}
<p>Actions taken:</p>
<ul>
#{actList}
</ul>
<p></p>
<code><p>#{bill_id}, #{Time.parse(bulk['introduced_at']).strftime("%B %d %Y %I:%M %p")}</p></code>"
    return ret
  end

  def getTitle()
    Mmbill.getTitle(self.bulk, self.bill_id)
  end

  def self.getTitle(bulk, bill_id)
    if bulk['short_title'] != nil and bulk['short_title'].length <= 160
      tit = bulk['short_title'].dup
    else
      tit = bulk['titles'].min{|a,b| a['title'].length <=> b['title'].length}
      tit = tit['title'].dup
    end
    if tit[" Act"] and tit.length > 10 and tit.index(" Act") >= (tit.length / 3)
      tit[tit.index(" Act")...tit.length] = ""
    end
    if tit[tit.length - 1] == "."
      tit = tit[0...(tit.length() - 1)]
    end
    if tit.length() > 150
      tit = bill_id + " - " + tit
      tit = tit[0..147] + "..." 
      tit = tit[0..147] + "..."
    end
    return tit
  end

  def self.upsertList(lst)
    p "IN BILL UPSERT LIST"   
    if lst.length == 0
      p "\n\nBILL LEN @ ZERO\n\n"
      return
    end
    cols = Mmbill.propublicaUpdateCols
    #we have a transaction as if mmcreate / mmupdate fails at some point, there could be inconsistency between mmbills and
    #and posts/topics that will not be resolved in further updates. (aka mmbill is current version, but, post viewed is past version.)
    
    idDoWhat = ActiveRecord::Base.transaction do
      idDoWhat = Mmbill.updateHelper(Mmbill, ::MmCategoryUpdate::Bltemp, lst, updateColumns=cols, foreign_key=:bill_id)
      p "#{idDoWhat[:updateThese].ntuples} / #{lst.length} Mmbills to be updated"
      p "#{idDoWhat[:createThese].ntuples} / #{lst.length} Mmbills to be created"
      p "#{lst.length - idDoWhat[:updateThese].ntuples - idDoWhat[:createThese].ntuples} skipped."

      #                     Bulk Update Code (come back to this later)
      #bulkUpdate = []
      #x=0; while x < idDoWhat[:updateThese].ntuples
        #x % 10 == 0 ? pr("!") : nil
        #bulkUpdate << Mmbill.mmupdate(idDoWhat[:updateThese].tuple(x))
      #x+=1; end
      #p "total: #{@@update_times["total"]}, tag: #{@@update_times['tag']}, title: #{@@update_times['title']}, body #{@@update_times["body"]}" if @update_times['total'] > 0
      #p("Starting bulk update") if bulkUpdate.length > 0
      #TopicsBulkAction.postgresql_bulk_post_topic_update(bulkUpdate) if bulkUpdate.length > 0
      #p("finishing bulk update") if bulkUpdate.length > 0
      bulkUpdate = []
      x=0; while x < idDoWhat[:updateThese].ntuples 
      x % 10 == 1 ? pr("!") : nil 
        bulkUpdate << Mmbill.mmupdate(idDoWhat[:updateThese].tuple(x))
      x+=1; end
      ::MmCategoryUpdate::TopicsBulkAction.postgresql_bulk_post_topic_update(bulkUpdate, "Bills") if bulkUpdate.length > 0
      next idDoWhat
    end #DO NOT MOVE BEYOND CREATE 1. unfinished will be deleted (transaction not needed) 2. will reset because create takes too long (will be harmful)
    x=0; while x < idDoWhat[:createThese].ntuples
      x % 10 == 0 ? pr("+") : nil
      bill_id = idDoWhat[:createThese].tuple(x)["bill_id"]
      Mmbill.find_by(bill_id: bill_id).mmcreate
    x+=1; end
  end

  def getNewTags()
    return Mmbill.getNewTags(self.bulk.dup)
  end

  def self.getNewTags(bulk) #overrides method from mmcategoryupdate
    tags = []
    tags << {tag: ::Meritmoot::shortStateLongState(bulk['sponsor']['state']), tagGroup: "states"}
    spons = Mmmember.find_by(mm_primary: bulk['sponsor']['bioguide_id'])
    if spons != nil and spons.mm_tag_str != nil
      tags << {tag: spons.mm_tag_str, tagGroup: "people" }
    end
    #p "moot tagging"
    #p bulk['moot_tagging']
    if bulk['moot_tagging']
      for tag in bulk['moot_tagging']
        tags << {tag: tag, tagGroup: "subjects"}
      end
    end
    bulk['history']['vetoed'] ? tags << {tag: 'vetoed', tagGroup: "status"} : nil
    bulk['history']['awaiting_signature'] ? tags << {tag: 'desked', tagGroup: "status"} : nil
    bulk['history']['enacted'] ? tags << {tag: "enacted", tagGroup: "status"} : nil
    bulk['history']['house_passage_result'] == "pass" ? tags << {tag: "thru-house", tagGroup: "status" } : nil 
    bulk['history']['senate_passage_result'] == "pass" ? tags << {tag: "thru-senate", tagGroup: "status" } : nil
    tags = tags.map() {|tag|
      tag[:tag] = tag[:tag].chars.map{|c| c == "_" or c == " " ? "-" : c }.join #replace bad spacers
      tag[:tag] = tag[:tag].downcase unless tag[:tagGroup] == "people" or tag[:tagGroup] == "states"
      next tag
    }
    return tags
  end

  def self.mmupdate(data)
    #to be utilized in bulk at later date.

    #post_id
    #topic_id
    #bulk
    #bill_id
    bulk = data['bulk']
    bulk = JSON.parse( bulk ) if bulk.class == String
    #p "bulk is string" if bulk.class  != Hash
    #p history.keys
    
    start = Time.now
      #do we bump the topic? When?
      #bump = self.bumpWhenChanged()
      #get revised at date
      begin
        activeAt = Time.parse(bulk['history']["active_at"])
      rescue Exception => e
        logWatch("err") {
          p "active_at messed up (printing data)"
          MootLogs.pp bulk
          p "#{bulk['history'].inspect}"
        }
        raise e
      end
      #if this step takes too long, will have to overhaul aswell.
      cookStart = Time.now
        cooked = Mmbill.getCooked(bulk, data['bill_id'])
      cookFinish = Time.now
      titleStart = Time.now
        title = Mmbill.getTitle(bulk, data['bill_id'])
      titleFinish = Time.now
      tagStart = Time.now
        tags = Mmbill.getNewTags(bulk)
      tagFinish = Time.now
    finish = Time.now
    @@update_times[:total] += (finish - start)
    @@update_times[:tag] += (tagFinish - tagStart)
    @@update_times[:title] += (titleFinish - titleStart)
    @@update_times[:body] += (cookFinish - cookStart)
    return {post_id: data['post_id'], topic_id: data['topic_id'], updated_at: activeAt, cooked: cooked, title: title, tags: tags}
  end

  def mmupdate()
    bulk = self.bulk.dup #to avoid accidental change in the database which cost me, idk, two months at one point...
    bill_id = self.bill_id.dup
    #determine if attribute changes deserve bump
    bump = self.bumpWhenChanged()
    #update attribute changes
    #get revised at date
    #Mmbill.logWatch("bulk_does_not_contain_active_at"){Mmbill.pp(self.bulk)} if self.bulk['history'].nil?() or self.bulk['history']['active_at'].nil?()
    activeAt = Time.parse(bulk['history']['active_at'])
    #revise post
    cooked = Mmbill.getCooked(bulk, bill_id)
    tags = Mmbill.attachTags(Mmbill.getNewTags(bulk))
    title = Mmbill.getTitle(bulk, bill_id)
    pst = Post.find_by(id: self.post_id)
    #Mmbill.p "tags: #{tags.inspect()}"
    #return {pst: {cooked: cooked, raw: cooked, updated_at: activeAt}, topic: {title: title, updated_at: activeAt}}
    rev = PostRevisor.new(pst).revise!( Discourse.system_user, {cooked: cooked, raw: cooked,
      title: title, tags: tags, skip_validations: true}, bypass_bump: !bump,
      skip_validations: true, revised_at: activeAt, skip_staff_log: true)
  end

  def mmcreate()
    begin
      bulk = self.bulk.dup #to avoid accidental change in the database which cost me, idk, two months at one point...
      bill_id = self.bill_id.dup
      createdAt = Time.parse(bulk["introduced_at"])
      cooked = Mmbill.getCooked(bulk, bill_id)
      raise(StandardError, "Cooked length is zero") if cooked.length == 0
      tags = Mmbill.attachTags(Mmbill.getNewTags(bulk))  #removeTags ignored as this is firest creation.
      post = PostCreator.new(Discourse.system_user,
        title: Mmbill.getTitle(bulk, bill_id),
        raw: cooked,
        cooked: cooked,
        cook_method: Post.cook_methods[:raw_html],
        archetype: 'regular',
        created_at: createdAt,
        category: Mmbill.getCatId("Bills"),
        is_warning: false,
        meta_data: { mm_type: 'bill', mm_id: bill_id },
        shared_draft: false,
        skip_validations: true,
        topic_opts: {tags: tags, skip_validations: true} #passed through post_creator to topic_creator
      )
      #create the bill's post
      postRet = post.create!()
      begin
        #link that
        self.update_attributes!({topic_id: postRet.topic_id, post_id: postRet.id})
        if self.topic_id == nil or self.post_id == nil
          raise StandardError, "Topic ID and or Post ID are nil #{Time.new()}, postRet: #{postRet.inspect()}"
        end
        return
      rescue Exception => e
        Mmbill.p "trashing post in progress"
        Topic.find_by(id: post.topic_id).destroy()
        post.destroy()
        raise e
      end
    rescue Exception => e
      Mmbill.p "trashing bill in progress"
      Mmbill.p "bulk info:"
      Mmbill.pp bulk
      self.destroy()
      raise e
    end
  end
end
