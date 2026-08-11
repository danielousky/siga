class Grade < ApplicationRecord
  enum :level, { primaria: 0, secundaria: 1 }

  belongs_to :school
  belongs_to :leader_teacher, class_name: "Teacher", primary_key: :user_id, optional: true

  # El profesor guía tiene que ser del mismo colegio que el grado.
  validates_same_school :leader_teacher

  has_many :grade_subjects, dependent: :destroy
  has_many :subjects, through: :grade_subjects
  has_many :sections, dependent: :restrict_with_error

  # El nombre es único dentro del colegio, no en toda la plataforma: dos colegios
  # tienen cada uno su "1er Año" sin saber que el otro existe.
  validates :name, presence: true, uniqueness: { scope: :school_id }
  validates :level, presence: true
end
