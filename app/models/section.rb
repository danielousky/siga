class Section < ApplicationRecord
  include SchoolScoped

  belongs_to :grade
  belongs_to :academic_period

  # El profesor guía de esta sección (MOR-150).
  #
  # Es quien pasa lista y quien responde por estos alumnos. Va acá y no en el
  # grado porque en un colegio venezolano el guía es de la sección: «1er Año A»
  # tiene el suyo y «1er Año B» el suyo.
  #
  # Opcional por ahora: hay secciones cargadas antes de que esto existiera, y un
  # colegio que importa su matrícula todavía no asignó guías. Sin guía, la
  # dirección igual puede pasar lista — ver `AsistenciasController`.
  belongs_to :leader_teacher, class_name: "Teacher", optional: true

  derives_school_from :grade
  validates_same_school :academic_period, :leader_teacher

  has_many :enrollments, dependent: :restrict_with_error
  has_many :students, through: :enrollments
  has_many :evaluation_activities, dependent: :restrict_with_error
  has_many :teacher_sections, dependent: :destroy
  has_many :teachers, through: :teacher_sections

  validates :name, presence: true, uniqueness: { scope: [:grade_id, :academic_period_id] }
  validates :capacity, presence: true, numericality: { greater_than: 0 }
end
