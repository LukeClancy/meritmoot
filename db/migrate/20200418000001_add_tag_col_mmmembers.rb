class AddTagColMmmembers < ActiveRecord::Migration[6.0]
  def change
    change_table :mmmembers do |t|
      t.string :mm_tag_str
      t.index :mm_tag_str, unique: true
    end
  end
end