class School < ApplicationRecord
  enum :school_type, { primary: 0, secondary: 1 }

  has_one_attached :logo

  has_many :departments, dependent: :restrict_with_error
  has_many :students, dependent: :restrict_with_error
  has_many :teachers, dependent: :restrict_with_error
  has_many :admins, dependent: :restrict_with_error
  has_many :academic_periods, dependent: :restrict_with_error

  validates :dea_code, presence: true, uniqueness: true
  validates :name, :location, :school_type, presence: true
end
