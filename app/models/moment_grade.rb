class MomentGrade < ApplicationRecord
  include SchoolScoped

  belongs_to :enrollment
  belongs_to :subject
  belongs_to :evaluation_moment

  derives_school_from :enrollment
  validates_same_school :subject

  # Art. 108: la calificación va del 1 al 20, ambos inclusive.
  validates :final_moment_score, presence: true, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }
  validates :evaluation_moment_id, uniqueness: { scope: [:enrollment_id, :subject_id] }
end
