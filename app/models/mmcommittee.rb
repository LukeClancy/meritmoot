class Mmcommittee < ActiveRecord::Base
  @vars = {
    mm_primary: nil,
    chamber: nil,
    name: nil,
    chair: nil,
    chair_id: nil,
    chair_party: nil,
    chair_state: nil,
    ranking_member_id: nil,
    url: nil
  }
  def self.defaults
    return @vars
  end
  def self.upsertList(lst)
    i = 0
    for a in lst
      Mmcommittee.upsert(a)
      i % 2000 == 1999 ? print("\n#{i} ") : nil
      i % 50 == 49 ? print(".") : nil
      i = i + 1
    end
    print("\ndone @ #{i}")
  end
  def self.upsert(attr)
    final = Mmcommittee.defaults
    for k in final.keys()
      if attr.key?(k.to_s)
        final[k] = attr[k.to_s]
      end
    end
    begin
      com = Mmcommittee.create!(final)
    rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation => e
      raise e if not e.message.include?("index_mmcommittees_on_mm_primary")
      com = Mmcommittee.find_by(mm_primary: final["mm_primary"])
      com.update_attributes!(final)
    end
  end
end