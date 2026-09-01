class Enrollment < ApplicationRecord
  include SchoolScoped

  enum :status, { regular: 0, retirado: 1 }

  belongs_to :section
  belongs_to :student, foreign_key: :student_id
  llega_al_anio_por :section

  # ⚠️ De la inscripción MÁS NUEVA a la más vieja, por el año escolar.
  #
  # El panel del alumno ordenaba por `grades.name`, y eso es correcto DENTRO de
  # un año y desastroso entre varios: un muchacho de 5to Año abría SIGA y veía
  # las notas de 1er Año de hace tres años, porque «1er» ordena antes que «5to».
  # Es la pantalla que ve una familia.
  #
  # Hoy no se nota porque cada colegio tiene un año escolar. Se rompe el día que
  # haya dos — o sea, en cuanto se pueda clonar el año.
  scope :recientes_primero, -> {
    joins(section: :academic_period).order("academic_periods.start_date DESC")
  }

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
