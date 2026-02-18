class CreateEnrollments < ActiveRecord::Migration[7.0]
  def change
    create_table :enrollments do |t|
      t.references :section, null: false, foreign_key: true
      t.bigint :student_id, null: false
      t.date :enrollment_date, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_foreign_key :enrollments, :students, column: :student_id, primary_key: :user_id
    add_index :enrollments, :student_id
    add_index :enrollments, [:section_id, :student_id], unique: true
  end
end
