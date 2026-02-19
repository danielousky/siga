class TeacherSection < ApplicationRecord
  belongs_to :teacher, primary_key: :user_id
  belongs_to :section
  belongs_to :subject

  validates :subject_id, uniqueness: { scope: :section_id, message: "ya está asignada en esta sección" }
end
