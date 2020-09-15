class Mmmember < ActiveRecord::Base
  self.primary_key= "mm_primary"
  has_many :mmbillaffects
  has_many :mmrollcallvotes
  #belongs_to(:mmrollcall, foreign_key: "mmrollcall")

  #t.string :mm_primary
  #t.index :mm_primary, unique: true
  #t.integer :missed_votes
  #t.integer :total_present
  #t.integer :total_votes
  #t.string :title
  #t.string :short_title
  #t.string :first_name
  #t.string :middle_name
  #t.string :suffix
  #t.string :twitter_account
  #t.string :facebook_account
  #t.string :youtube_account
  #t.string :district
  #t.string :state

  def self.defaults
    return {
      mm_primary: nil,
      mm_latest_congress: nil,
      mm_first_lower: nil,
      mm_last_lower: nil,
      mm_chamber: nil,
      mm_reference_str: nil,
      mm_reference_str_lower: nil,
      mm_tag_str: nil,
      missed_votes: nil,
      total_present: nil,
      total_votes: nil,
      title: nil,
      short_title: nil,
      first_name: nil,
      middle_name: nil,
      last_name: nil,
      suffix: nil,
      twitter_account: nil,
      facebook_account: nil,
      youtube_account: nil,
      district: nil,
      state: nil
    }
  end
  def self.upsertList(lst)
    i = 0
    for a in lst
      i = i + 1
      Mmmember.upsert(a)
      i % 2000 == 0 ? MootLogs.p("\n#{i}") : nil
      i % 50 == 0 ? MootLogs.p(".") : nil
    end
    MootLogs.p("\ndone @ #{i}")
  end
  def getATag(final)
    x = 0
    Meritmoot::asshurt(msg = "attempted to assign tag which is pre-existing") {
      self.mm_tag_str == "" or self.mm_tag_str == nil
    }
    tagStr = ""
    while true
      # go through possible tag formats until we find one that has not yet been taken.
      if x == 0
        tagStr = "#{final[:last_name]}"
        Mmmember.find_by(mm_tag_str: tagStr) == nil ? break : nil #new one? break
      elsif x == 1
        tagStr = "#{final[:first_name][0]} #{final[:last_name]}"
        Mmmember.find_by(mm_tag_str: tagStr) == nil ? break : nil #new one? break
      elsif x == 2
        tagStr = "#{final[:last_name]} #{final[:first_name][0]}"
        Mmmember.find_by(mm_tag_str: tagStr) == nil ? break : nil #new one? break
      elsif x == 3
        tagStr = "#{final[:first_name]} #{final[:last_name]}"
        Mmmember.find_by(mm_tag_str: tagStr) == nil ? break : nil #new one? break
      elsif x == 4
        if final[:middle_name] != nil #mid can be nil
          tagStr = "#{final[:first_name]} #{final[:middle_name][0]} #{final[:last_name]}"
          Mmmember.find_by(mm_tag_str: tagStr) == nil ? break : nil #new one? break
        end
      elsif x == 5
        tagStr = "#{final[:last_name]} #{final[:id]}"
        Mmmember.find_by(mm_tag_str: tagStr) == nil ? break : nil #new one (will be new because of primary)? break
      else
        raise StandardError.new("how?")
      end
      x += 1
    end
    return tagStr
  end
  def self.upsert(item)
    final = Mmmember.defaults()
    #trim list
    for k in final.keys()
      if item.key?(k.to_s)
        final[k] = item[k.to_s]
      end
    end
    final[:missed_votes] = final[:missed_votes].to_i
    final[:total_present] = final[:total_present].to_i
    final[:total_votes] = final[:total_votes].to_i
    final[:mm_latest_congress] = final[:mm_latest_congress].to_i
    begin
      #see of their name isnt taken
      mem = Mmmember.create!(final)
      tag = mem.getATag(final)
      final[:mm_tag_str] = tag
      mem.update_attributes!(final)
    rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation => e
      mem = Mmmember.find_by(mm_primary: final[:mm_primary])
      if mem.mm_tag_str == "" || mem.mm_tag_str == nil
        tag = mem.getATag(final)
        final[:mm_tag_str] = tag
      else
        final.delete(:mm_tag_str)
      end
      mem.update_attributes!(final)
    end
  end
end