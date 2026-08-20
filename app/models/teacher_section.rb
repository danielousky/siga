class TeacherSection < ApplicationRecord
  include SchoolScoped

  belongs_to :teacher
  belongs_to :section
  belongs_to :subject

  derives_school_from :section
  validates_same_school :teacher, :subject

  validates :subject_id, uniqueness: { scope: :section_id, message: "ya está asignada en esta sección" }
end
