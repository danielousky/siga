class MomentGrade < ApplicationRecord
  belongs_to :enrollment
  belongs_to :subject
  belongs_to :evaluation_moment

  validates :final_moment_score, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }
  validates :evaluation_moment_id, uniqueness: { scope: [:enrollment_id, :subject_id] }
end
