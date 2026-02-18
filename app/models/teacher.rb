class Teacher < ApplicationRecord
  self.primary_key = :user_id

  belongs_to :user
  belongs_to :school

  has_many :led_grades, class_name: "Grade", foreign_key: :leader_teacher_id, primary_key: :user_id,
                        dependent: :nullify
end
