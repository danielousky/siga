# Un indicador de una competencia (MOR-136).
#
# ## ⚠️ Describe, NO se califica
#
# Es la decisión que más trabajo le ahorra a una maestra, y viene de la cuenta:
#
#     por COMPETENCIA   21 × 30       =    630 valores por lapso
#     por INDICADOR     21 × 3 × 30   =  1.890 valores por lapso
#
# Pero el argumento que decide no es el volumen: es que **agregar niveles de
# indicador a un nivel de competencia exigiría una regla —moda, promedio,
# mínimo— que ninguna norma define**. Una regla inventada es una regla que la
# maestra le tiene que defender a una mamá en la puerta del salón.
#
# El pedido de `MOR-216` —que los padres entiendan mejor el desempeño— se
# resuelve IMPRIMIÉNDOLOS. Imprimir no es calificar.
class Indicator < ApplicationRecord
  include SchoolScoped

  belongs_to :competency

  # Qué evaluación lo mide — UNA sola, o ninguna todavía.
  #
  # ⚠️ `optional: true` porque el plan se escribe en ese orden: la competencia,
  # sus indicadores, y después las evaluaciones. Nulo es «libre», y es el estado
  # normal de septiembre.
  #
  # ⚠️ `dependent` va del otro lado y es `:nullify`: borrar una evaluación
  # SUELTA sus indicadores, no se los lleva. El texto lo escribió la maestra.
  belongs_to :evaluation_activity, optional: true

  llega_al_nivel_por competency: { section: :grade }
  derives_school_from :competency

  validates :descripcion, presence: true

  # ⚠️ Un indicador NO se repite entre evaluaciones. Decisión de Daniel, y es lo
  # que le da sentido a la relación: si dos evaluaciones pudieran medir el mismo
  # indicador, marcar cuál mide qué no repartiría nada.
  #
  # La columna ya lo garantiza —un valor, una evaluación—, así que acá no hay
  # nada que validar: lo que sí hay que validar es que la evaluación que lo
  # reclama mida su competencia.
  validate :lo_mide_una_evaluacion_de_su_competencia

  # Los que todavía no mide nadie: lo que una evaluación nueva puede tomar.
  scope :libres, -> { where(evaluation_activity_id: nil) }

  def medido? = evaluation_activity_id.present?

  # ⚠️ La unicidad se valida ADEMÁS del índice único de la base.
  #
  # El índice estaba y la validación no, así que repetir un indicador reventaba
  # con `ActiveRecord::RecordNotUnique` —una pantalla roja de Rails— en vez de
  # decirlo. Daniel: *«está bien, pero no debería explotar sino decirme que está
  # duplicado»*.
  #
  # El índice se queda: es lo que lo hace imposible de verdad, también para lo
  # que entre por otra puerta. La validación es para poder CONTARLO.
  #
  # Va sobre la canónica y no sobre el texto: «Suma con reagrupación» y «suma
  # con reagrupacion» son el mismo indicador escrito dos veces, y el índice de
  # la base también los cuenta como uno.
  validates :descripcion_canonica, uniqueness: {
    scope: :competency_id, message: "ya está en esta competencia"
  }
  before_validation :calcular_la_canonica

  scope :en_orden, -> { order(:orden, :id) }

  private

  # ⚠️ El indicador de Matemática no lo puede medir una evaluación de
  # Castellano, ni uno de «Interpreta gráficos» una evaluación que solo mide
  # «Resuelve problemas de adición».
  #
  # Es el gemelo de `ActivityCompetency#la_competencia_es_del_mismo_plan`, un
  # escalón más adentro: allá se comprueba que la competencia sea del plan de
  # esta sección, materia y lapso; acá, que la evaluación declare medir la
  # competencia de la que este indicador cuelga. Sin esto la boleta imprimiría
  # un indicador bajo una competencia que esa evaluación nunca midió.
  #
  # ⚠️ Se pregunta por `competency_ids` y no por la tabla: en un alta, las
  # etiquetas todavía están en memoria y una consulta devolvería cero.
  def lo_mide_una_evaluacion_de_su_competencia
    return if evaluation_activity.nil? || competency_id.nil?
    return if evaluation_activity.competency_ids.include?(competency_id)

    errors.add(:base, "«#{descripcion.to_s.truncate(40)}» es de una competencia que esa evaluación no mide")
  end

  def calcular_la_canonica
    self.descripcion_canonica = Normaliza.para_comparar(descripcion)
  end
end
