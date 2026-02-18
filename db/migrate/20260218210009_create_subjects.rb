class CreateSubjects < ActiveRecord::Migration[7.0]
  def change
    create_table :subjects do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.references :department, null: false, foreign_key: true

      t.timestamps
    end

    add_index :subjects, :code, unique: true
  end
end
