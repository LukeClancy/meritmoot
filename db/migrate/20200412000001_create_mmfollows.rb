class CreateMmfollows < ActiveRecord::Migration[6.0]
  def change
    #::Meritmoot::MootLogs.logWatch("CreateMmfollows-Migrate") { |l|
      create_table :mmfollows do |t|
        t.string :mmmember_id, null: false
        t.integer :user_id, null: false
        t.index [:user_id, :mmmember_id], unique: true
        t.timestamps
      end
    #}
  end
end