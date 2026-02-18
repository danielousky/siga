class ActivityGrade < ApplicationRecord
  belongs_to :evaluation_activity
  belongs_to :student, foreign_key: :student_id, primary_key: :user_id

  validates :score, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }
  validates :student_id, uniqueness: { scope: :evaluation_activity_id }
end
