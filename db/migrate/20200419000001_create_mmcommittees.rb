class CreateMmcommittees < ActiveRecord::Migration[6.0]
  def change
    #::Meritmoot::MootLogs.logWatch("CreateMmcommittees-Migrate") {
      create_table :mmcommittees, id: false do |t|
        t.string :mm_primary
        t.index :mm_primary, unique: true
        t.string :chamber
        t.string :name
        t.string :chair
        t.string :chair_id
        t.string :chair_party
        t.string :chair_state
        t.string :ranking_member_id
        t.text :url
        t.timestamps
      end
    #}
  end
end