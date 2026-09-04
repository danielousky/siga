# La rúbrica con que un colegio traduce una nota a un nivel (MOR-136).
#
# ## Es una MÁSCARA de presentación, no una escala
#
# Daniel: *«sencillamente se califica con número en primera instancia, y los
# profesores califican con números»*. Lo que se guarda en `activity_grades` es
# el entero del 1 al 20 del Art. 108; esta tabla solo decide **cómo se lee**.
#
#     DOCENTE  ──17──►  BASE (1-20)  ──17──►  REPRESENTANTE ve «PA»
#
# ⚠️ Y por eso puede ser configurable sin riesgo. Cambiar una rúbrica **no
# reescribe ninguna nota**: cambia cómo se muestran las que ya hay. Si el nivel
# fuera lo que se guarda, esta tabla sería una bomba.
#
# ## Por qué es tabla y no constante, al revés que GradoOficial
#
# Porque **cambia de colegio en colegio**. Daniel, contando lo que le dijo
# Cyndi: *«había colegios que solo tenían tres, lo que lo hacía muy complicado
# porque metías en el mismo saco a estudiantes con 13 que a estudiantes con
# 17»*.
#
# Esa queja es justamente el argumento del número como sustrato: con tres
# niveles la máscara es más gruesa, pero **por dentro el 13 y el 17 siguen
# siendo distintos**. Lo que se pierde es al mostrar, no al guardar.
class Rubric < ApplicationRecord
  include SchoolScoped

  belongs_to :school

  validates :code, presence: true, uniqueness: { scope: :school_id }
  validates :name, presence: true
  validates :valor, presence: true,
                    numericality: { only_integer: true, greater_than_or_equal_to: 1,
                                    less_than_or_equal_to: 20 },
                    uniqueness: { scope: :school_id }

  # De mayor a menor: el orden en que se busca el nivel de una nota.
  scope :en_orden, -> { order(valor: :desc) }

  # Lo que SIGA propone cuando un colegio arranca. El colegio lo cambia.
  #
  # ⚠️ Coincide banda por banda con `EscalaLiteral`, que existe desde `MOR-129`
  # y mapea el mismo 1–20 a A/B/C/D/E. No es casualidad: son la misma escala
  # con dos vocabularios, y por eso el corte de aprobación cae en 10 en las dos.
  POR_DEFECTO = [
    { code: "PC", name: "Proceso consolidado",    valor: 19 },
    { code: "PA", name: "Proceso avanzado",       valor: 17 },
    { code: "PI", name: "Proceso intermedio",     valor: 14 },
    { code: "PD", name: "Proceso con dificultad", valor: 10 },
    { code: "NP", name: "No cumplió el proceso",  valor: 1 }
  ].freeze

  # El nivel que le toca a una nota, o `nil` si no hay nota.
  #
  # ⚠️ Sin nota **no es NP y no es cero**: es que todavía no hay nada que
  # calificar. Confundirlos reprueba a un niño que nadie evaluó, y `NP` SÍ
  # reprueba — Daniel: *«el docente está obligado a evaluar»*.
  #
  # ⚠️ `valor` es el PISO de la banda, así que el nivel es «el más alto cuyo
  # valor no supera la nota». Con eso las bandas quedan contiguas por
  # construcción: no puede haber un 16 sin nivel.
  def self.para(nota, rubricas = en_orden)
    return nil if nota.blank?

    rubricas.find { |r| r.valor <= nota }
  end

  # ¿Este colegio definió su rúbrica? Si no, la boleta muestra el número, que
  # es exactamente lo que hace hoy. No tener rúbrica no rompe nada.
  def self.definida? = exists?

  def to_s = code
end
