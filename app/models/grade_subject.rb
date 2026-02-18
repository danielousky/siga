class GradeSubject < ApplicationRecord
  belongs_to :grade
  belongs_to :subject

  validates :subject_id, uniqueness: { scope: :grade_id }
end
