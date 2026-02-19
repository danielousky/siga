class Student < ApplicationRecord
  self.primary_key = :user_id

  belongs_to :user
  belongs_to :school
  accepts_nested_attributes_for :user

  has_many :enrollments, foreign_key: :student_id, primary_key: :user_id, dependent: :restrict_with_error
  has_many :sections, through: :enrollments
  has_many :activity_grades, foreign_key: :student_id, primary_key: :user_id, dependent: :restrict_with_error

  validates :school_card, presence: true, uniqueness: true
end
