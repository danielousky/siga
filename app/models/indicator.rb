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
  llega_al_nivel_por competency: { section: :grade }
  derives_school_from :competency

  validates :descripcion, presence: true
  before_validation :calcular_la_canonica

  scope :en_orden, -> { order(:orden, :id) }

  private

  def calcular_la_canonica
    self.descripcion_canonica = Normaliza.para_comparar(descripcion)
  end
end
