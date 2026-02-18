class CreateGrades < ActiveRecord::Migration[7.0]
  def change
    create_table :grades do |t|
      t.string :name, null: false
      t.integer :level, null: false
      t.bigint :leader_teacher_id

      t.timestamps
    end

    add_index :grades, :name, unique: true
    add_foreign_key :grades, :teachers, column: :leader_teacher_id, primary_key: :user_id
  end
end
