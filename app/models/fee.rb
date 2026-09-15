# Lo que el colegio cobra en un año escolar (spec: `docs/specs/pagos-de-la-familia.md`).
#
#     Inscripción   120,00 $   vence el 15/08
#     Septiembre     45,00 $   vence el 05/09
#     …
#     Agosto         45,00 $   vence el 05/07   ← sí, en julio
#
# Se define al crear el año escolar y de acá nacen los `Charge`: uno por
# inscripción y por concepto.
class Fee < ApplicationRecord
  include SchoolScoped
  derives_school_from :academic_period

  belongs_to :academic_period
  has_many :charges, dependent: :restrict_with_error

  validates :nombre, presence: true, length: { maximum: 60 }
  validates :monto, numericality: { greater_than: 0 }
  validates :vence_el, presence: true
  validates :nombre, uniqueness: { scope: :academic_period_id,
                                   message: "ya está cargado en este año escolar" }

  scope :en_orden, -> { order(:orden, :vence_el, :id) }

  # ⚠️ La inscripción NO es una mensualidad, y por eso se distingue.
  #
  # Daniel: *«la persona debe pagar también una inscripción… esa debe pagarse
  # aparte de la mensualidad»*. En la tarjeta de pago van separadas, y en el
  # calendario que se propone la inscripción vence antes que el primer mes.
  INSCRIPCION = "Inscripción".freeze

  def inscripcion? = nombre == INSCRIPCION

  # El calendario habitual de un colegio venezolano, para proponerlo al crear el
  # año escolar.
  #
  # ⚠️ AGOSTO VENCE EN JULIO, y solo agosto. Daniel, corrigiendo: *«ese mes en
  # particular, ¿ok? Ese mes en particular, no todos»*. El año escolar va de
  # septiembre a julio y agosto se cobra antes de que termine, porque es el mes
  # en que se inscribe para el año siguiente.
  #
  # ⚠️ Y esto PROPONE, no impone: cada fecha y cada monto se corrigen. Un
  # colegio que cobre diez cuotas en vez de once borra la que le sobre.
  MESES = %w[Septiembre Octubre Noviembre Diciembre Enero Febrero
             Marzo Abril Mayo Junio Julio Agosto].freeze

  def self.calendario_propuesto(periodo, mensualidad:, inscripcion:)
    arranca = periodo.start_date || Date.new(Date.current.year, 9, 1)

    propuestas = [ { nombre: INSCRIPCION, monto: inscripcion, orden: 0,
                     vence_el: arranca - 15.days } ]

    MESES.each_with_index do |mes, i|
      # Septiembre es el mes 0 del año escolar; agosto, el 11.
      vence = arranca.beginning_of_month + i.months + 4.days
      # ⚠️ El de agosto se corre un mes ATRÁS, y es el único: cae en JULIO,
      # junto con el de julio. Se propone al 25 y no al 5 para que no venzan el
      # mismo día — son dos cuotas y la familia las paga en dos momentos, no dos
      # veces lo mismo.
      vence = vence - 1.month + 20.days if mes == "Agosto"

      propuestas << { nombre: mes, monto: mensualidad, orden: i + 1, vence_el: vence }
    end

    propuestas
  end
end
