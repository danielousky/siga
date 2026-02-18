class CreateAdmins < ActiveRecord::Migration[7.0]
  def change
    create_table :admins, id: false do |t|
      t.bigint :user_id, null: false, primary_key: true
      t.references :school, null: false, foreign_key: true
      t.integer :role, null: false

      t.timestamps
    end

    add_foreign_key :admins, :users, column: :user_id
  end
end
