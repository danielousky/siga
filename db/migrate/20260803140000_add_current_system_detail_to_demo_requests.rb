class AddCurrentSystemDetailToDemoRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :demo_requests, :current_system_detail, :string
  end
end
