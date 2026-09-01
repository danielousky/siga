class FinalGradeBook < ApplicationRecord
  include SchoolScoped

  belongs_to :enrollment
  belongs_to :subject
  llega_al_anio_por enrollment: :section

  derives_school_from :enrollment
  validates_same_school :subject

  validates :subject_id, uniqueness: { scope: :enrollment_id }
  # Art. 108: la calificación va del 1 al 20, ambos inclusive. `nil` sí es válido
  # —es "todavía sin nota", que no es lo mismo que una nota baja.
  validates :annual_average, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }, allow_nil: true
  validates :remedial_exam_score, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }, allow_nil: true
  validates :final_score, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }, allow_nil: true

  # Ver `MomentGrade#origen`. Acá además decide si el ANUAL se recalcula a partir
  # de los lapsos: un colegio que trae su definitiva certificada manda sobre lo
  # que dé el promedio, porque es lo que está impreso en el boletín que entregó.
  enum :origen, { calculada: 0, importada: 1 }

  # Cuál es la nota definitiva, según el Artículo 112 (MOR-168).
  #
  # ⚠️ Vive acá y no en `GradeCalculator` porque hay DOS escritores: el cálculo
  # de los lapsos y la planilla de reparación. Con la regla adentro del
  # calculador, la planilla tenía que repetirla — y peor, un libro **importado**
  # no pasa por el calculador (`return libro if libro&.importada?`), así que su
  # definitiva no se habría actualizado nunca al cargarle una reparación.
  # Es el caso normal de un colegio que trae su historial y después repara.
  #
  # `max` y «la nota de la segunda oportunidad es la definitiva» dan el mismo
  # resultado porque la reparación solo se presenta estando aplazado: si la
  # aprobó es la mayor, y si no, las dos están por debajo de 10. Y `max` además
  # no puede BAJAR una nota ya obtenida.
  def calcular_definitiva
    anual = GradeCalculator.redondear(annual_average)
    reparacion = GradeCalculator.redondear(remedial_exam_score)

    self.final_score = reparacion ? [ anual, reparacion ].compact.max : anual
  end

  # ¿Quedó aplazado? Es la pregunta que define quién aparece en la planilla de
  # reparación y qué materias arrastra un alumno.
  #
  # Diez es la mínima aprobatoria y sale impresa en el propio boletín. `nil` no
  # es aplazado: es «sin nota», que no es lo mismo (ver `GradeCalculator`).
  APROBATORIA = 10

  def aplazado? = final_score.present? && final_score < APROBATORIA

  # ⚠️ Quién tiene DERECHO a reparar lo decide el promedio ANUAL, y no la
  # definitiva — que es la que ya incluye la reparación.
  #
  # Con `aplazado?`, un alumno desaparecía de la planilla en el instante en que
  # se le cargaba una reparación aprobatoria: escribir 74 en vez de 14 dejaba un
  # error imposible de corregir, porque la fila ya no estaba. Lo agarró el test.
  #
  # El respaldo a `final_score` es para las notas importadas: un historial suele
  # traer la definitiva y no el promedio de los lapsos.
  def debe_reparar?
    base = annual_average || final_score
    base.present? && base < APROBATORIA
  end
end
