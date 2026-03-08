class CreateActivityLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :activity_logs do |t|
      t.references :user,     null: false, foreign_key: true
      t.string     :action,   null: false
      t.string     :message,  null: false
      t.references :subject,  polymorphic: true, index: true
      t.jsonb      :metadata, default: {}
      t.string     :ip_address

      t.timestamps
    end

    add_index :activity_logs, :action
    add_index :activity_logs, :created_at
  end
end
