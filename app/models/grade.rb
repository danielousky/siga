class Grade < ApplicationRecord
  enum level: { primaria: 0, secundaria: 1 }

  belongs_to :leader_teacher, class_name: "Teacher", primary_key: :user_id, optional: true

  has_many :grade_subjects, dependent: :destroy
  has_many :subjects, through: :grade_subjects
  has_many :sections, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :level, presence: true
end
