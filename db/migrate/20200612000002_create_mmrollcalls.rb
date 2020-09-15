
class CreateMmrollcalls < ActiveRecord::Migration[6.0]
  def change
    #::Meritmoot::MootLogs.logWatch("CreateMmRollCalls-Migrate") {
      create_table :mmrollcalls do |t|
        t.text :mm_primary
        t.index :mm_primary, unique: true
        t.text :congress
        t.text :session
        t.text :chamber
        t.text :roll_call
        t.text :source
        t.text :url
        t.text :bill_id
        t.index :bill_id
        t.text :bill_number
        t.text :bill_title
        t.text :question
        t.text :description
        t.text :vote_type
        t.text :date
        t.text :time
        t.text :result
        t.text :document_number
        t.text :document_title
        t.text :democratic_yes
        t.text :democratic_no
        t.text :republican_yes
        t.text :republican_no
        t.text :total_yes
        t.text :total_no
        t.text :democratic_majority_position
        t.text :republican_majority_position
        t.integer :topic_id
        t.index :topic_id, unique: true
        t.integer :post_id
        t.index :post_id, unique: true
        t.datetime :last_vote_update, default: Date.new(1800)
        t.jsonb :moot_tagging, default: []
        t.timestamps
      end
      puts "Completed CreateMmrollcalls change"
    #}
  end
end
