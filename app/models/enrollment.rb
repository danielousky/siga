class Enrollment < ApplicationRecord
  enum status: { regular: 0, retirado: 1 }

  belongs_to :section
  belongs_to :student, foreign_key: :student_id, primary_key: :user_id

  has_many :moment_grades, dependent: :restrict_with_error
  has_many :final_grade_books, dependent: :restrict_with_error

  validates :enrollment_date, presence: true
  validates :student_id, uniqueness: { scope: :section_id }
end
