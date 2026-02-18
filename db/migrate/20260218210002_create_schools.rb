class CreateSchools < ActiveRecord::Migration[7.0]
  def change
    create_table :schools do |t|
      t.string :dea_code, null: false
      t.string :name, null: false
      t.string :location, null: false
      t.integer :school_type, null: false

      t.timestamps
    end

    add_index :schools, :dea_code, unique: true
  end
end
