class CreateMmbillaffects < ActiveRecord::Migration[6.0]
  def change
    #::Meritmoot::MootLogs.logWatch("CreateMmbillaffect-Migrate") { |l|
      create_table :mmbillaffects do |t|
        #create an index over billid, member and then affect.
        #t.text :mm_primary #simply bill_id + 
        #t.index :mm_primary, unique: true
        t.string :affect, null: false
        t.string :mmmember_id, null: false
        t.string :bill_id, null: false
        t.index [:bill_id, :mmmember_id, :affect], unique: true
        t.index [:mmmember_id, :bill_id, :affect], unique: true
      end
      puts "done tih mmbilladdddddffects"
    #}
  end
end