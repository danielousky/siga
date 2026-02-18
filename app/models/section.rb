class Section < ApplicationRecord
  belongs_to :grade
  belongs_to :academic_period

  has_many :enrollments, dependent: :restrict_with_error
  has_many :students, through: :enrollments
  has_many :evaluation_activities, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: [:grade_id, :academic_period_id] }
  validates :capacity, presence: true, numericality: { greater_than: 0 }
end
