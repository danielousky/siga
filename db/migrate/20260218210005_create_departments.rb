class CreateDepartments < ActiveRecord::Migration[7.0]
  def change
    create_table :departments do |t|
      t.references :school, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :departments, [:school_id, :name], unique: true
  end
end
