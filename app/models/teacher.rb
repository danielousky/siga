class Teacher < ApplicationRecord
  include SchoolScoped

  self.primary_key = :user_id

  belongs_to :user
  belongs_to :school
  accepts_nested_attributes_for :user

  has_many :led_grades, class_name: "Grade", foreign_key: :leader_teacher_id, primary_key: :user_id,
                        dependent: :nullify
  has_many :teacher_sections, primary_key: :user_id, dependent: :restrict_with_error
  has_many :sections, through: :teacher_sections
end
