class EvaluationActivity < ApplicationRecord
  include SchoolScoped

  belongs_to :subject
  belongs_to :section
  belongs_to :evaluation_moment
  llega_al_anio_por :section
  llega_al_nivel_por section: :grade
  derives_school_from :section
  validates_same_school :subject

  # `restrict_with_error`, no `destroy`: borrar una actividad con notas se lleva
  # por delante el trabajo de carga de un lapso entero, y en silencio.
  has_many :activity_grades, dependent: :restrict_with_error

  # Qué competencias del plan evalúa esta actividad (MOR-136).
  #
  # ⚠️ `dependent: :destroy` y no `restrict`: la etiqueta no es un dato de nadie
  # —es una relación—, así que borrar la evaluación se la lleva. Lo que NO se
  # puede borrar es la evaluación con notas, y de eso se encarga la línea de
  # arriba.
  has_many :activity_competencies, dependent: :destroy
  has_many :competencies, through: :activity_competencies

  # Qué INDICADORES de esas competencias mide (MOR-136, segunda mitad).
  #
  # ⚠️ `nullify` y no `destroy`: borrar la evaluación SUELTA sus indicadores,
  # no se los lleva. El texto —«Suma con reagrupación»— lo escribió la maestra
  # en el plan; la evaluación solo decía cuál de ellos medía. Con `destroy`,
  # borrar un examen para volver a armarlo le borraría media competencia.
  has_many :indicators, dependent: :nullify

  validates :description, presence: true
  validates :weight_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :date_scheduled, presence: true
  validate :total_weight_must_not_exceed_100
  validate :el_lapso_pertenece_al_periodo_de_la_seccion
  validate :mide_una_competencia_y_un_indicador, on: :create

  # Cambiar la ponderación no afecta a un alumno: afecta a los treinta. Si el
  # examen pasa de 40 % a 50 %, el promedio del lapso cambia para toda la sección.
  # Va por job porque es ~1 s — ver `RecalcularSeccionJob` y MOR-96.
  after_update_commit :recalcular_la_seccion, if: :saved_change_to_weight_percentage?

  # Lo que un profesor puede tocar: las materias que dicta, en las secciones que
  # tiene asignadas. No es "las actividades de su colegio" — dos profesores del
  # mismo colegio no se ven las evaluaciones.
  #
  # El JOIN va contra las dos columnas a la vez porque la unidad de trabajo es el
  # PAR sección–materia: el profesor de Matemática de 1er Año A no dicta
  # Castellano en esa misma sección.
  scope :dictadas_por, ->(teacher) {
    joins(<<~SQL.squish)
      INNER JOIN teacher_sections
              ON teacher_sections.section_id = evaluation_activities.section_id
             AND teacher_sections.subject_id = evaluation_activities.subject_id
    SQL
      .where(teacher_sections: { teacher_id: teacher.id })
  }

  # Todas las evaluaciones de un mismo lapso de una materia en una sección: el
  # grupo dentro del cual los pesos tienen que cerrar en 100 %.
  scope :del_grupo, ->(section_id, subject_id, evaluation_moment_id) {
    where(section_id: section_id, subject_id: subject_id, evaluation_moment_id: evaluation_moment_id)
  }

  # Cuánto del lapso ya está comprometido. `excepto` deja fuera la actividad que
  # se está editando, para que su propio peso no se cuente dos veces.
  def self.peso_usado(section_id:, subject_id:, evaluation_moment_id:, excepto: nil)
    grupo = del_grupo(section_id, subject_id, evaluation_moment_id)
    grupo = grupo.where.not(id: excepto) if excepto.present?
    grupo.sum(:weight_percentage)
  end

  # Si esta evaluación pertenece a un grado que se planifica por competencias.
  #
  # ⚠️ Es del GRADO, no del colegio: el mismo plantel dicta primaria y
  # bachillerato, y su profesor de Matemática da los dos. Ver `Grade`.
  def por_competencias? = section&.grade&.por_competencias?

  # Lo que queda libre en el lapso, contando esta actividad como si no existiera.
  def peso_disponible
    return nil if section_id.blank? || subject_id.blank? || evaluation_moment_id.blank?

    100 - self.class.peso_usado(
      section_id: section_id, subject_id: subject_id,
      evaluation_moment_id: evaluation_moment_id, excepto: id
    )
  end

  private

  # ⚠️ Una evaluación de primaria mide algo, o no es una evaluación.
  #
  # Regla de Daniel: *«la evaluación debe tener al menos un indicador y una
  # competencia»*. Sin competencia, la boleta la suma al promedio y no puede
  # explicar qué midió; sin indicador, la competencia sale con nivel pero sin
  # una sola línea que diga por qué.
  #
  # ⚠️ Solo `on: :create`, y no siempre. Siempre rompería la EDICIÓN EN LÍNEA de
  # todo lo que ya existe: corregirle una tilde al nombre de una evaluación
  # escrita antes de esta regla fallaría con un error sobre indicadores, el
  # campo volvería a su valor viejo y el profesor no entendería nada. Lo que ya
  # está se avisa en el plan —como `MOR-229` avisa la competencia sin
  # evaluaciones—; lo que nace, nace completo.
  #
  # ⚠️ Y solo donde el plan EXISTE. En bachillerato no hay competencias, así que
  # esta validación sin la guarda dejaría a todos sus profesores sin poder crear
  # una evaluación — la misma trampa que `Grade#por_competencias?` existe para
  # evitar.
  def mide_una_competencia_y_un_indicador
    return unless por_competencias?

    errors.add(:base, "Marca la competencia que mide: sin eso no puede salir en la boleta.") if competency_ids.empty?
    errors.add(:base, "Marca o escribe al menos un indicador: es lo que esta evaluación mide.") if indicators.empty?
  end

  def recalcular_la_seccion
    RecalcularSeccionJob.perform_later(section, subject)
  end

  def total_weight_must_not_exceed_100
    return if weight_percentage.blank? || section_id.blank? || subject_id.blank? || evaluation_moment_id.blank?

    disponible = peso_disponible
    return if weight_percentage <= disponible

    errors.add(
      :weight_percentage,
      "no puede exceder 100 % en este lapso: quedan #{number_with_precision(disponible)} % disponibles"
    )
  end

  # Una evaluación de 1er Año A no puede colgar del lapso de otro año escolar.
  #
  # Los momentos cuelgan del período académico (MOR-83) y la sección también, así
  # que sin esta validación se podía crear una actividad del "Primer Semestre" de
  # 2026-2027 en una sección de 2025-2026. El promedio anual la ignoraría —
  # `GradeCalculator` solo mira los lapsos del período de la inscripción— y la
  # nota cargada ahí quedaría flotando, invisible y sin explicación.
  def el_lapso_pertenece_al_periodo_de_la_seccion
    return if section.blank? || evaluation_moment.blank?
    return if evaluation_moment.academic_period_id == section.academic_period_id

    errors.add(:evaluation_moment, "no pertenece al año escolar de la sección")
  end

  # Sin decimales cuando el peso es entero: "30 %" y no "30,00 %".
  def number_with_precision(valor)
    valor.to_d.frac.zero? ? valor.to_i : valor.to_f
  end
end
