class AddLastNameColMmmembers < ActiveRecord::Migration[6.0]
  def change
    change_table :mmmembers do |t|
      t.string :last_name
    end
  end
end