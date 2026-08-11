class Subject < ApplicationRecord
  belongs_to :school
  belongs_to :department

  has_many :grade_subjects, dependent: :destroy
  has_many :grades, through: :grade_subjects
  has_many :evaluation_activities, dependent: :restrict_with_error
  has_many :moment_grades, dependent: :restrict_with_error
  has_many :final_grade_books, dependent: :restrict_with_error
  has_many :teacher_sections, dependent: :restrict_with_error

  # El código es la nomenclatura interna del colegio: único dentro de él, no en
  # toda la plataforma. Un colegio que viene de otro sistema trae sus códigos ya
  # impresos en carnets y planillas.
  validates :code, presence: true, uniqueness: { scope: :school_id }
  validates :name, presence: true

  # El colegio se deriva del departamento en vez de pedirse aparte. Un selector
  # propio podría contradecir al departamento y dejar una materia cuyo colegio no
  # es el de su departamento — una inconsistencia que después nadie encuentra.
  before_validation :derive_school_from_department

  private

  def derive_school_from_department
    self.school_id = department.school_id if department
  end
end
