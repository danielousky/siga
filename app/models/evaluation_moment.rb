class EvaluationMoment < ApplicationRecord
  has_many :evaluation_activities, dependent: :restrict_with_error
  has_many :moment_grades, dependent: :restrict_with_error

  validates :name, presence: true
  validates :weight, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
end
