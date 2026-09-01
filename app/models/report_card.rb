# Un boletín emitido.
#
# La fila NO es "el boletín del alumno": es **una emisión concreta**. Si la
# secretaria lo emite en diciembre y otra vez en marzo son dos filas, con dos
# códigos, y cada una dice lo que decía el papel que se entregó ese día.
#
# Ver MOR-98.
class ReportCard < ApplicationRecord
  include SchoolScoped

  belongs_to :enrollment
  belongs_to :evaluation_moment, optional: true   # nil = boletín anual
  belongs_to :issued_by, class_name: "User", optional: true
  llega_al_anio_por enrollment: :section

  derives_school_from :enrollment

  validates :code, presence: true, uniqueness: true

  before_validation :asignar_codigo, on: :create

  scope :recientes, -> { order(created_at: :desc) }

  def anual? = evaluation_moment_id.nil?

  def titulo
    anual? ? "Boletín Anual" : evaluation_moment.name
  end

  private

  # Sin 0/O ni 1/I/L: el código se dicta por teléfono y se teclea a mano en la
  # ruta pública. Un carácter ambiguo convierte una verificación en una llamada
  # al colegio, que es exactamente lo que esto viene a evitar.
  ALFABETO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".chars.freeze

  def asignar_codigo
    return if code.present?

    self.code = loop do
      candidato = "BOL-" + 2.times.map { 4.times.map { ALFABETO.sample }.join }.join("-")
      # `sin_aislamiento` porque la unicidad es de toda la plataforma: el código
      # se consulta sin sesión y sin colegio.
      break candidato unless Current.sin_aislamiento { ReportCard.unscoped.exists?(code: candidato) }
    end
  end
end
