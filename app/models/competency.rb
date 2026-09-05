# Una competencia del plan de evaluación de una sección (MOR-136).
#
# ## Qué es, y qué NO es
#
# En Educación Primaria no se evalúa con notas sueltas: se evalúa competencias.
# Pero **la competencia no produce la nota** — Daniel: *«en realidad las
# competencias terminan siendo solo para mostrarlas en la boleta junto con los
# indicadores y la rúbrica»*.
#
#     LA NOTA      evaluation_activities (peso) → activity_grades → moment_grades
#     LA BOLETA    materia → competencia → indicadores → nivel de rúbrica
#
# O sea que esto es un PLAN descriptivo, y por eso agregarlo no toca
# `GradeCalculator` ni una sola validación de las que ya existen.
#
# ## ⚠️ Cuelga de la SECCIÓN, no del grado
#
# Corroborado con Cyndi Montoya, y revierte lo que habían recomendado las dos
# revisiones de diseño. La razón manda: **cada profesor es autónomo en su
# gestión**. Dos secciones del mismo grado pueden tener planes distintos, aunque
# lo normal sea copiarlos — y copiar es un ATAJO, no un vínculo: después de
# copiar, cada sección es independiente.
class Competency < ApplicationRecord
  include SchoolScoped

  belongs_to :section
  belongs_to :subject
  belongs_to :evaluation_moment
  llega_al_anio_por :section
  llega_al_nivel_por section: :grade

  derives_school_from :section
  validates_same_school :subject, :evaluation_moment

  # ⚠️ `restrict_with_error` y no `destroy`: borrar una competencia que ya
  # etiqueta evaluaciones cambia lo que dice una boleta hacia atrás.
  has_many :activity_competencies, dependent: :restrict_with_error
  has_many :evaluation_activities, through: :activity_competencies

  # Los indicadores sí se van con ella: no existen sin su competencia.
  has_many :indicators, -> { order(:orden, :id) }, dependent: :destroy, inverse_of: :competency
  accepts_nested_attributes_for :indicators, allow_destroy: true,
                                reject_if: ->(a) { a[:descripcion].blank? }

  validates :descripcion, presence: true
  validate :el_lapso_pertenece_al_periodo_de_la_seccion

  # ⚠️ La validación Y el índice único, y no sobra ninguna de las dos.
  #
  # El índice es lo que garantiza que no haya duplicados; la validación es lo
  # que hace que el profesor lea «esta competencia ya está en el plan» en vez de
  # un 500. Sin el índice, dos pestañas abiertas escriben las dos; sin la
  # validación, el caso normal —pegar dos veces— revienta la pantalla.
  validates :descripcion_canonica,
            uniqueness: { scope: [ :section_id, :subject_id, :evaluation_moment_id ],
                          message: "ya está en el plan de este lapso" }

  # ⚠️ La canónica es lo que impide la competencia duplicada en el mismo plan.
  #
  # «Resuelve problemas de adición» y «resuelve problemas de adicion» pasan las
  # dos cualquier validación de presencia, y para el índice único son dos filas.
  # El plan de la sección termina con la misma competencia dos veces — que es
  # justo lo que este issue viene a evitar.
  before_validation :calcular_la_canonica

  scope :del_plan, ->(section_id, subject_id, evaluation_moment_id) {
    where(section_id:, subject_id:, evaluation_moment_id:).order(:orden, :id)
  }

  # El plan del año anterior que se le puede SUGERIR a este profesor.
  #
  # ⚠️ Se busca por GRADO y materia, no por sección: la sección de 2025-2026 no
  # es la misma fila que la de 2026-2027, pero «5to Grado · Matemática · 1er
  # Lapso» sí es la misma pregunta. Y se busca el lapso por NOMBRE normalizado,
  # no por posición: `evaluation_moments` no tiene orden, y ordenar por `id`
  # funciona por casualidad hasta que alguien borra y recrea un lapso.
  #
  # ⚠️ `Current.sin_aislamiento` NO entra acá: el `default_scope` de
  # `SchoolScoped` ya acota al colegio, que es lo correcto — el plan de otro
  # colegio no se sugiere ni por equivocación.
  def self.para_sugerir(section:, subject:, evaluation_moment:)
    nombre = GradoOficial.normalizar(evaluation_moment.name)

    joins(section: :grade, evaluation_moment: {})
      .where(subject_id: subject.id)
      .where(grades: { name: section.grade.name })
      .where.not(sections: { academic_period_id: section.academic_period_id })
      .where("LOWER(evaluation_moments.name) LIKE ?", "%#{nombre}%")
      .order("sections.academic_period_id DESC")
  end

  # Las evaluaciones que etiquetan esta competencia, con su peso.
  #
  # Es lo que hace falta para calcular su nivel en la boleta: el promedio
  # ponderado de las actividades que la evalúan — la regla del Art. 111
  # aplicada a un subconjunto, no una regla inventada.
  def evaluation_activities_con_peso
    EvaluationActivity.where(id: activity_competencies.select(:evaluation_activity_id))
                      .pluck(:id, :weight_percentage).to_h
  end

  private

  def calcular_la_canonica
    self.descripcion_canonica = Normaliza.para_comparar(descripcion)
  end

  # El gemelo exacto de la validación de `EvaluationActivity`, y por la misma
  # razón: sin esto la competencia queda colgada de un lapso de otro año, no se
  # ve en ninguna pantalla y nadie entiende por qué.
  def el_lapso_pertenece_al_periodo_de_la_seccion
    return if evaluation_moment.nil? || section.nil?
    return if evaluation_moment.academic_period_id == section.academic_period_id

    errors.add(:evaluation_moment, "es de otro año escolar que el de la sección")
  end
end
