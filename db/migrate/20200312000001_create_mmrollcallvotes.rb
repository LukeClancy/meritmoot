class CreateMmrollcallvotes < ActiveRecord::Migration[6.0]
  def change
    #::Meritmoot::MootLogs.logWatch("CreateMmRollCallVotes-Migrate") { |l|
      create_table :mmrollcallvotes do |t|
        t.string :mmrollcall_id, null: false
        t.string :mmmember_id, null: false
        t.index [:mmrollcall_id, :mmmember_id], unique: true
        t.string :vote_position
      end
      puts "Completed CreateMmrollcallvotes change"
    #}
  end
end
