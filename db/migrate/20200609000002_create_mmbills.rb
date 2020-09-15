class CreateMmbills < ActiveRecord::Migration[6.0]
  def change
    create_table :mmbills do |t|
      t.text :bill_id
      t.index :bill_id, unique: true
      t.jsonb :bulk, null: false, default: '{}'
      t.integer :post_id
      t.index :post_id, unique: true
      t.integer :topic_id
      t.index :topic_id, unique: true
      t.timestamps
      t.string :do_reformat, default: 'no'
    end
  end
end

