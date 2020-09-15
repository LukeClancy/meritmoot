class CreateMmmembers < ActiveRecord::Migration[6.0]
  def change
    #::Meritmoot::MootLogs.logWatch("CreateMmmembers-Migrate") {
      create_table :mmmembers, id: false do |t|
        #create an index over billid, member and then affect.
        #t.text :mm_primary #simply bill_id + 
        #t.index :mm_primary, unique: true
        t.string :mm_primary
        t.index :mm_primary, unique: true
        t.integer :mm_latest_congress
        t.string :mm_first_lower
        t.string :mm_last_lower
        t.string :mm_chamber
        t.integer :missed_votes
        t.integer :total_present
        t.integer :total_votes
        t.string :title
        t.string :short_title
        t.string :first_name
        t.string :middle_name
        t.string :suffix
        t.string :twitter_account
        t.string :facebook_account
        t.string :youtube_account
        t.string :district
        t.string :state
        t.string :mm_reference_str
        t.string :mm_reference_str_lower
        
        t.timestamps 
      end
    #}
  end
end