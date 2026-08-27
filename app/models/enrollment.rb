class Enrollment < ApplicationRecord
  include SchoolScoped

  enum :status, { regular: 0, retirado: 1 }

  belongs_to :section
  belongs_to :student, foreign_key: :student_id

  derives_school_from :student
  validates_same_school :section

  has_many :moment_grades, dependent: :restrict_with_error
  has_many :final_grade_books, dependent: :restrict_with_error

  validates :enrollment_date, presence: true
  validates :student_id, uniqueness: { scope: :section_id }

  # Las materias que van en el boletín de este alumno (MOR-152).
  #
  # ## ⚠️ Es una UNIÓN, y la segunda mitad NO es opcional
  #
  # Lo natural sería `section.materias_dictadas` y listo. Deja el boletín
  # histórico VACÍO: `CargaDeHistorial` escribe la persona, la inscripción y las
  # notas, y **no crea `TeacherSection`** — no sabe quién dictó Biología en 2019
  # y no tiene por qué inventarlo.
  #
  # Derivando solo de quién dicta, se perdería de vista exactamente lo que el
  # importador vino a cargar: diez años de historial se verían en blanco, sin un
  # solo error que lo avisara. Por eso también cuentan las materias que TIENEN
  # nota para este alumno: una nota es prueba de que esa materia se vio.
  def materias_del_boletin
    ids = section.materias_dictadas.ids |
          MomentGrade.where(enrollment_id: id).distinct.pluck(:subject_id) |
          FinalGradeBook.where(enrollment_id: id).distinct.pluck(:subject_id)

    Subject.where(id: ids).order(:name)
  end
end
