class EvaluationActivity < ApplicationRecord
  belongs_to :subject
  belongs_to :section
  belongs_to :evaluation_moment

  has_many :activity_grades, dependent: :restrict_with_error

  validates :description, presence: true
  validates :weight_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :date_scheduled, presence: true
end
