class CreateFinalGradeBooks < ActiveRecord::Migration[7.0]
  def change
    create_table :final_grade_books do |t|
      t.references :enrollment, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true
      t.decimal :annual_average, precision: 4, scale: 2
      t.decimal :remedial_exam_score, precision: 4, scale: 2
      t.decimal :final_score, precision: 4, scale: 2
      t.text :comments

      t.timestamps
    end

    add_index :final_grade_books, [:enrollment_id, :subject_id], unique: true
  end
end
