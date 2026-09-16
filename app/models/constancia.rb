# Una constancia de estudio emitida, para poder comprobarla después.
#
# Daniel: *«la constancia debe poder ser validada como los boletines»*.
#
# ## ⚠️ Lo que se guarda y lo que NO
#
# El PDF que sale sigue diciendo la situación DE HOY —eso no cambió— y esto es
# el rastro de que se emitió:
#
#     NO contesta   «este alumno estudia aquí»    ← es de hoy, y cambia
#     SÍ contesta   «el colegio emitió este papel el 16 de septiembre,
#                    y decía esto»                ← no cambia nunca
#
# Que es lo que necesita una embajada con el papel en la mano: no saber si hoy
# sigue inscrito, sino que el papel no está adulterado.
class Constancia < ApplicationRecord
  include SchoolScoped
  derives_school_from :enrollment

  belongs_to :enrollment
  belongs_to :issued_by, class_name: "User"

  validates :code, presence: true, uniqueness: true

  before_validation :asignar_codigo, on: :create

  scope :recientes_primero, -> { order(created_at: :desc) }

  # Lo que dice el papel, congelado. El colegio puede renombrar una sección o
  # corregir un apellido, y el documento emitido tiene que seguir diciendo lo
  # que decía.
  def self.emitir!(enrollment, por:)
    create!(enrollment: enrollment, issued_by: por, snapshot: retrato_de(enrollment, por))
  end

  def self.retrato_de(enrollment, por)
    alumno = enrollment.student.user
    seccion = enrollment.section

    { "colegio" => { "nombre" => Current.school&.name, "dea" => Current.school&.dea_code },
      "alumno" => { "nombre" => alumno.apellidos_y_nombres,
                    "documento" => alumno.documento_a_la_vista,
                    "cedula_escolar" => alumno.cedula_escolar },
      "grado" => seccion.grade.name,
      "seccion" => seccion.name,
      "anio" => seccion.academic_period.name,
      "emitida" => Date.current.iso8601,
      "emitida_por" => por.nombre_completo }
  end

  private

  # ⚠️ El mismo alfabeto del boletín, y por la misma razón: sin 0/O ni 1/I/L.
  # El código se dicta por teléfono y se teclea a mano en la ruta pública.
  ALFABETO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".chars.freeze

  def asignar_codigo
    return if code.present?

    self.code = loop do
      candidato = "CON-" + 2.times.map { 4.times.map { ALFABETO.sample }.join }.join("-")
      # Sin aislamiento: la unicidad es de toda la plataforma, porque el código
      # se consulta sin sesión y sin colegio.
      break candidato unless Current.sin_aislamiento { Constancia.unscoped.exists?(code: candidato) }
    end
  end
end
