class CreateActivityGrades < ActiveRecord::Migration[7.0]
  def change
    create_table :activity_grades do |t|
      t.references :evaluation_activity, null: false, foreign_key: true
      t.bigint :student_id, null: false
      t.decimal :score, precision: 4, scale: 2, null: false

      t.timestamps
    end

    add_foreign_key :activity_grades, :students, column: :student_id, primary_key: :user_id
    add_index :activity_grades, :student_id
    add_index :activity_grades, [:evaluation_activity_id, :student_id], unique: true, name: "index_activity_grades_on_activity_and_student"
  end
end
