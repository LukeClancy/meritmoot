require 'date'
require 'json'
require 'time'

# frozen_string_literal: true
class Mmrollcall < ActiveRecord::Base
  extend MmCategoryUpdate
  extend MootLogs
  self.primary_key= "mm_primary"
  has_many :mmrollcallvote
  has_one :post, through: :post_id, dependent: :destroy
  has_one :topic, through: :topic_id, dependent: :destroy
  
  #possibilities
  # 1 - need to refresh due to changes in models with like has_many
  # 2 - class is fucking broke.

  #as multiple inheritence is not allowed in ruby - - - 
  #def self.getCatId(); ::MmCategoryUpdate::getCatId(Mmrollcall, "Roll Calls"); end
  #def attachTags(); ::MmCategoryUpdate::attachTags(self); end 
  #def self.clearJobLeftovers(); ::MmCategoryUpdate::clearJobLeftovers(Mmrollcall); end

  #reference Mmbill for similar code
  ATTR = {
    categoryId: nil
  }
  #primary set to unique
  @@defaults = {
    mm_primary: nil,
    congress: nil,
    session: nil,
    chamber: nil,
    roll_call: nil,
    source: nil,
    url: nil,
    bill_id: nil,
    bill_number: nil,
    bill_title: nil,
    question: nil,
    description: nil, 
    vote_type: nil,
    date: nil,
    time: nil,
    result: nil,
    document_number: nil,
    document_title: nil,
    democratic_yes: nil,
    democratic_no: nil,
    republican_yes: nil,
    republican_no: nil,
    total_yes: nil,
    total_no: nil,
    democratic_majority_position: nil,
    republican_majority_position: nil,
    topic_id: nil,
    post_id: nil 
  }

  def self.defaults
    #key in self.defaults iff attribute in MmrollcallSerializer
    return  @@defaults.dup
  end

  def self.propublicaUpdateCols
    cols = @@defaults.keys.map {|fuckWhy| fuckWhy.to_sym} #for some reason getting the keys
      #of class wide or constant hashes seems to return a string for no fucking reason.
    return cols - [:topic_id, :post_id] + [:created_at, :updated_at]
  end

  def self.bumpWhenChanged
    false
  end
  def bumpWhenChanged()
    Mmbill.bumpWhenChanged
  end

  def self.upsertList(lst)
    p "IN RC UPSERT LIST"
    if lst.length == 0
      p("\n\nROLLCALLS LENGTH AT ZERO\n\n")
      return
    end
    cols = self.propublicaUpdateCols
    idDoWhat = ActiveRecord::Base.transaction do
      idDoWhat = Mmrollcall.updateHelper(Mmrollcall, ::MmCategoryUpdate::Rctemp, lst, updateColumns=cols, foreign_key=:mm_primary)
      p "#{idDoWhat[:updateThese].ntuples} / #{lst.length} MmRollCalls to be updated"
      p "#{idDoWhat[:createThese].ntuples} / #{lst.length} MmRollCalls to be created"
      p "#{lst.length - idDoWhat[:updateThese].ntuples - idDoWhat[:createThese].ntuples} skipped."
      bulkUpdate = []
      x=0; while x < idDoWhat[:updateThese].ntuples
        x % 10 == 1 ? pr("!") : nil
        bulkUpdate << Mmrollcall.mmupdate(idDoWhat[:updateThese].tuple(x))
      x+=1; end
      ::MmCategoryUpdate::TopicsBulkAction.postgresql_bulk_post_topic_update(bulkUpdate, "Roll Calls") if bulkUpdate.length > 0
      next idDoWhat
    end #DO NOT MOVE BEYOND CREATE 1. unfinished will be deleted (transaction not needed) 2. will reset because create takes too long (will be harmful)
    x=0; while x < idDoWhat[:createThese].ntuples
      x % 10 == 0 ? pr("+") : nil
      mm_primary = idDoWhat[:createThese].tuple(x)["mm_primary"]
      Mmrollcall.find_by(mm_primary: mm_primary).mmcreate
    x+=1; end
  end

  def getCooked
    Mmrollcall.getCooked(self.attributes)
  end
  def self.getCooked(attri)
    #todo frontload link from Bill Title to bill
    createdAt = []
    createdAt += attri['date'].split('-')
    createdAt += attri['time'].split(':')
    createdAt = Time.new(*createdAt)
    attri["bill_title"] != nil and attri['bill_title'] != '' ? bill_title = "Bill Title: #{attri['bill_title']} <br/>" : bill_title = ""
    return "<p> Question: #{attri['question']} <br/>
#{bill_title}Description: #{attri['description']} <br/>
Vote Type: #{attri['vote_type']} <br/>
Yes: #{attri['total_yes']} (R:#{attri['republican_yes']} D:#{attri['democratic_yes']}) <br/>
No: #{attri['total_no']} (R:#{attri['republican_no']} D:#{attri['democratic_no']}) <br/>
Result: #{attri['result']} <br/> <br/>
#{attri['mm_primary']}, #{createdAt.strftime("%B %d %Y %I:%M %p")}</p>"
  end

  def getTitle()
    Mmrollcall.getTitle(self.attributes)
  end

  def self.getTitle(attri)
    if attri['description'].length <= 140 && attri['description'].length > 2
      tit = attri['description'].dup
    else
      tit = attri['question'].dup
    end
    if attri['bill_id'] != nil
      tit = attri['bill_id'] + " - " + tit
    end
    if tit.length() > 150
      tit = tit[0..147] + "..."
    end
    return tit
  end

  def getNewTags
    Mmrollcall.getNewTags(self.attributes)
  end
  
  def self.getNewTags(attri)
    tags=[]
    tags << {tag: attri['chamber'].downcase, tagGroup: "chamber"}
    if attri['result'] != nil && attri['result'].length < 20
      res = attri['result'].dup
      res = res.chars.map{|c| c == "_" or c == " " ? "-" : c.downcase }.join #format
      tags << {tag: res, tagGroup: "status"}
    end
    # this bit untested
    if attri['moot_tagging'] != nil
      for tag in attri['moot_tagging'].split(' ')
        tags << { tag: tag, tagGroup: "Categories" }
      end
    end
    return tags
  end

  def mmcreate
    #In case of error or interrupt, save db integrity.
    begin
      #check date, dont bump if its more than like, 1 week
      attri = self.attributes.dup
      createdAt = []
      createdAt += attri['date'].split('-')
      createdAt += attri['time'].split(':')
      createdAt = Time.new(*createdAt)
      tags = Mmrollcall.attachTags(Mmrollcall.getNewTags(attri))
      post = PostCreator.new(Discourse.system_user,
        title: Mmrollcall.getTitle(attri),
        raw: Mmrollcall.getCooked(attri),
        archetype: 'regular',
        cook_method: Post.cook_methods[:raw_html],
        created_at: createdAt,
        skip_validations: true,
        category: Mmrollcall.getCatId("Roll Calls"),
        is_warning: false,
        meta_data: { mm_type: 'roll_call', mm_id: attri['mm_primary'] },
        shared_draft: false,
        topic_opts: {tags: tags, skip_validations: true}
      )
      postRet = post.create!()
      begin
        #get the post and topic id\
        self.update_attributes!({topic_id: postRet.topic_id, post_id: postRet.id})
        if self.topic_id == nil or self.post_id == nil
          raise StandardError, "Topic ID and or Post ID are nil #{Time.new()}, postRet: #{postRet.inspect()}"
        end
        return self
      rescue Exception => e
        Mmrollcall.pr("trashing post-in-progress")
        Topic.find_by(id: post.topic_id).destroy()
        post.destroy()
        raise e
      end
    rescue Exception => e
      Mmrollcall.pr("trashing bill-in-progress")
      self.destroy()
      raise e
    end
  end

  def self.mmupdate(attributes)
    createdAt = attributes['date'].split('-')
    createdAt += attributes['time'].split(':')
    createdAt = Time.new(*createdAt)
    return {
      cooked: Mmrollcall.getCooked(attributes),
      title: Mmrollcall.getTitle(attributes),
      tags: Mmrollcall.getNewTags(attributes),
      post_id: attributes['post_id'],
      topic_id: attributes['topic_id'],
      updated_at: createdAt #rollcalls dont really update, they are just corrected and modified. 
    }
  end

  def mmupdate
    #replace the topic_id and post_id keys to prevent overwrite
    #get post
    pst = Post.find_by(id: self.post_id)
    #changes deserve bump?
    bump = self.bumpWhenChanged?
    tags = self.attachTags
    PostRevisor.new(pst).revise!( Discourse.system_user, { raw: self.getRaw(),
      title: self.getTitle(), tags: tags, skip_validations: true}, bypass_bump: !bump, #bumping is a weird one
      skip_revision: true, skip_validations: true)
    return self
  end
end
# What have I learned through multiple days of debugging this function?
# 1. Anything that can go wrong in databases, will, due to their persistent nature.
#     Make sure your functions are as narrow as possible and expect everything to
#     account for this.
# 2. When debugging, first and formost one should constrain their code into the narrowest
#     pathway.
# 3. Use the ! functions if you want to live
# 4. Ruby is weird.
# 5. Ruby on Rails is weird and complicated. One of the issues (not sure how many 
#     there actually was in the end) turned out to be due to ROR jobs not being completed
#     Upon the interupt. This left a situation where there were jobs without topic/post ids.
#     This was solved in the above method (clearJobLeftovers) which I inserted upstream
# 6. there is allways a better solution, case in point I gutted the function
#     months later because it was inefficient splitting it into parts.