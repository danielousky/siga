class Subject < ApplicationRecord
  belongs_to :department

  has_many :grade_subjects, dependent: :destroy
  has_many :grades, through: :grade_subjects
  has_many :evaluation_activities, dependent: :restrict_with_error
  has_many :moment_grades, dependent: :restrict_with_error
  has_many :final_grade_books, dependent: :restrict_with_error
  has_many :teacher_sections, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
