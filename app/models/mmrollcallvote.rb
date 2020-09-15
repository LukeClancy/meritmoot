class Mmrollcallvote < ActiveRecord::Base
  belongs_to :mmrollcall, foreign_key: :mmrollcall_id
  belongs_to :mmmember, foreign_key: :mmmember_id
  extend MootLogs
  include Meritmoot

  @@defaults = { 
    mmrollcall_id: nil,
    mmmember_id: nil,
    vote_position: nil
  }
  def self.defaults
    return defaults.dup
  end
  def self.propublicaUpdateCols
    cols = @@defaults.keys.map {|fuckWhy| fuckWhy.to_sym}
    return cols
  end
  def self.upsertList(list, pout=true)
    if list.length == 0
      p ("\n\nVOTES LENGTH AT ZERO\n\n")
      return
    end
    p list[0...10].to_s
    self.upsert_all list, unique_by: [:mmrollcall_id, :mmmember_id]
  end
  def self.upsert(item)
    final = Mmrollcallvote.defaults()
    #trim list
    for k in final.keys()
      if item.key?(k.to_s)
        final[k] = item[k.to_s]
      end
    end
    final[:mmrollcall_id] = Mmrollcall.find_by(mm_primary: final[:mmrollcall_id]).id
    begin
      final[:mmmember_id] = Mmmember.find_by(mm_primary: final[:mmmember_id]).id
    rescue NoMethodError => e
      return nil #we dont have that member for some reason. Likely not in office anymore
    end
    begin
      begin
        Mmrollcallvote.create!(final)
      rescue ActiveRecord::NotNullViolation => e
        return nil #we have a null value for some reason in mmrollcall_id or mmmember id
      end
    rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation => e
      #update 
      vote = Mmrollcallvote.find_by(mmrollcall_id: final[:mmrollcall_id], mmmember_id: final[:mmmember_id])
      vote.update_attributes!(final)
    end
  end
end