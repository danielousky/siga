class CreateDemoRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :demo_requests do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :institution, null: false
      t.string :phone
      t.text :message
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :demo_requests, :email
    add_index :demo_requests, :status
  end
end
