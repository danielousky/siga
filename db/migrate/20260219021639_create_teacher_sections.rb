class CreateTeacherSections < ActiveRecord::Migration[7.0]
  def change
    create_table :teacher_sections do |t|
      t.bigint :teacher_id, null: false
      t.references :section, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true

      t.timestamps
    end

    add_foreign_key :teacher_sections, :teachers, primary_key: :user_id
    add_index :teacher_sections, :teacher_id
    add_index :teacher_sections, [:section_id, :subject_id], unique: true, name: "index_teacher_sections_on_section_and_subject"
  end
end
