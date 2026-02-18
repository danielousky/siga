class CreateAddresses < ActiveRecord::Migration[7.0]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :estado, null: false
      t.string :municipio, null: false
      t.string :parroquia, null: false
      t.string :location, null: false
      t.string :additional

      t.timestamps
    end
  end
end
