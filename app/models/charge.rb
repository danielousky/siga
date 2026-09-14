# Lo que UN alumno debe (spec: `docs/specs/pagos-de-la-familia.md`).
#
# Nace de un `Fee` al inscribirse y muere cuando la oficina valida el pago.
class Charge < ApplicationRecord
  include SchoolScoped
  derives_school_from :enrollment

  belongs_to :enrollment
  belongs_to :fee
  # El reporte que lo pagó. Null mientras nadie lo haya reportado, y también
  # cuando un reporte se rechaza: se suelta y el cobro vuelve a deber.
  belongs_to :payment_report, optional: true

  validates :monto, numericality: { greater_than_or_equal_to: 0 }
  validates :vence_el, presence: true

  scope :pendientes, -> { where(pagado_el: nil) }
  scope :pagados,    -> { where.not(pagado_el: nil) }
  scope :en_orden,   -> { order(:vence_el, :id) }
  # ⚠️ En mora es VENCIDO y sin pagar. Lo que vence la semana que viene no es
  # deuda: cobrarle a alguien por algo que todavía no toca es la manera más
  # rápida de que un colegio deje de usar esto.
  scope :en_mora,    ->(hoy = Date.current) { pendientes.where(vence_el: ...hoy) }
  # Lo reportado y todavía sin revisar: ya no se le puede volver a reportar, pero
  # tampoco está pagado.
  scope :en_revision, -> { pendientes.where.not(payment_report_id: nil) }
  scope :sin_reportar, -> { pendientes.where(payment_report_id: nil) }

  def pagado? = pagado_el.present?
  def reportado? = !pagado? && payment_report_id.present?
  def vencido?(hoy = Date.current) = !pagado? && vence_el < hoy

  # Tres estados para la tarjeta de pago, en el orden en que se preguntan.
  def estado
    return :pagado if pagado?
    return :en_revision if reportado?

    vencido? ? :en_mora : :por_vencer
  end

  # Los cobros de un año, creados de los conceptos que falten.
  #
  # ⚠️ Idempotente, como `CopiarLaEstructura`: correrlo dos veces no duplica
  # nada. Un colegio que agrega un concepto a mitad de año lo corre otra vez y
  # solo nacen los que faltaban.
  #
  # ⚠️ Y el monto se COPIA del concepto. Si en marzo el colegio sube la
  # mensualidad, lo que este alumno debía en septiembre no cambia solo.
  def self.emitir_para(enrollment)
    conceptos = Fee.where(academic_period_id: enrollment.section.academic_period_id).en_orden
    ya_tiene = where(enrollment_id: enrollment.id).pluck(:fee_id).to_set

    conceptos.reject { |c| ya_tiene.include?(c.id) }.map do |concepto|
      create!(enrollment: enrollment, fee: concepto,
              monto: concepto.monto, vence_el: concepto.vence_el)
    end
  end
end
