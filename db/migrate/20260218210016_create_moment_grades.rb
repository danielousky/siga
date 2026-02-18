class CreateMomentGrades < ActiveRecord::Migration[7.0]
  def change
    create_table :moment_grades do |t|
      t.references :enrollment, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true
      t.references :evaluation_moment, null: false, foreign_key: true
      t.decimal :final_moment_score, precision: 4, scale: 2, null: false

      t.timestamps
    end

    add_index :moment_grades, [:enrollment_id, :subject_id, :evaluation_moment_id], unique: true, name: "index_moment_grades_on_enrollment_subject_moment"
  end
end
