class AddFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :id_card, :string
    add_column :users, :name, :string
    add_column :users, :last_name, :string

    add_index :users, :id_card, unique: true
  end
end
