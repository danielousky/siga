class Teacher < ApplicationRecord
  include SchoolScoped

  belongs_to :user
  belongs_to :school
  accepts_nested_attributes_for :user

  has_many :led_grades, class_name: "Grade", foreign_key: :leader_teacher_id,
                        dependent: :nullify
  has_many :teacher_sections, dependent: :restrict_with_error
  has_many :sections, through: :teacher_sections
end
