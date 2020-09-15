class Mmbillaffect < ActiveRecord::Base
  belongs_to :mmmember
  belongs_to :mmbill, foreign_key: :bill_id
  extend MootLogs
  @@defaults = {
    affect: nil,
    mmmember_id: nil,
    bill_id: nil,
  }
  def self.defaults
    return @@defaults.dup
  end
  def self.propublicaUpdateCols
    cols = @@defaults.keys.map {|a| a.to_sym}
    return cols
  end
  def self.upsertList(lst)
    #script finds nil values and rows of strange length
    #p "bla lst fails: #{lst.select { |v| v.length != 3 or v.map{|k,v| v}.include?(nil) }}"
    ActiveRecord::Base.transaction do
      bill_ids = lst.map{|af| af[:bill_id]}.uniq
      Mmbillaffect.where(bill_id: bill_ids).delete_all
      Mmbillaffect.insert_all(lst, unique_by: [:bill_id, :mmmember_id, :affect], returning: false)
    end
  end
end