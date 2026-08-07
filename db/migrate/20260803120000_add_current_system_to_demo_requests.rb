class AddCurrentSystemToDemoRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :demo_requests, :current_system, :integer
    add_index :demo_requests, :current_system
  end
end
