class GradeSubject < ApplicationRecord
  include SchoolScoped
  llega_al_nivel_por :grade

  belongs_to :grade
  belongs_to :subject

  derives_school_from :grade
  validates_same_school :subject

  validates :subject_id, uniqueness: { scope: :grade_id }
end
