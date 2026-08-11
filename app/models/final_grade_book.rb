class FinalGradeBook < ApplicationRecord
  belongs_to :enrollment
  belongs_to :subject

  derives_school_from :enrollment

  validates :subject_id, uniqueness: { scope: :enrollment_id }
  validates :annual_average, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }, allow_nil: true
  validates :remedial_exam_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }, allow_nil: true
  validates :final_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }, allow_nil: true
end
