class CreateSections < ActiveRecord::Migration[7.0]
  def change
    create_table :sections do |t|
      t.references :grade, null: false, foreign_key: true
      t.references :academic_period, null: false, foreign_key: true
      t.integer :capacity, null: false
      t.string :name, null: false
      t.string :classroom

      t.timestamps
    end

    add_index :sections, [:grade_id, :academic_period_id, :name], unique: true, name: "index_sections_on_grade_period_name"
  end
end
