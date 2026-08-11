class ActivityGrade < ApplicationRecord
  include SchoolScoped

  belongs_to :evaluation_activity
  belongs_to :student, foreign_key: :student_id, primary_key: :user_id

  derives_school_from :evaluation_activity
  validates_same_school :student

  # Art. 108 del Reglamento General de la LOE: "escala del uno (1) al veinte (20),
  # ambos inclusive". No arranca en cero — al que no se presenta se le pone 01.
  validates :score, presence: true, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }
  validates :student_id, uniqueness: { scope: :evaluation_activity_id }
end
