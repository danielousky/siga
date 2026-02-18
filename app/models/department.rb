class Department < ApplicationRecord
  belongs_to :school

  has_many :subjects, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :school_id }
end
