# Lo que la familia dice que pagó (spec: `docs/specs/pagos-de-la-familia.md`).
#
# Daniel: *«el representante reporta y el administrador, la parte financiera de
# la escuela, debe poder validar esos pagos»*.
#
#     en_revision  ──►  validado    los cobros quedan pagados
#                  └─►  rechazado   los cobros se sueltan y vuelven a deber
#
# ## ⚠️ Un reporte NO paga nada por sí solo
#
# Toma los cobros que dice pagar y los marca «reportados» —ni pendientes ni
# pagados— hasta que la oficina mire el voucher. Sin esa separación, quien
# escriba cualquier número de referencia se libera el acceso a las notas.
class PaymentReport < ApplicationRecord
  include SchoolScoped
  derives_school_from :enrollment

  belongs_to :representative
  belongs_to :enrollment
  belongs_to :revisado_por, class_name: "User", optional: true
  has_many :charges, dependent: :nullify

  # ⚠️ La imagen se ENCOGE al recibirla. Ver `EncogeElVoucher`: una foto de
  # teléfono son 3–4 MB y a 1600 px la referencia se lee igual.
  has_one_attached :voucher

  ESTADOS = %w[en_revision validado rechazado].freeze

  enum :estado, ESTADOS.index_by(&:itself), default: "en_revision", validate: true

  # ⚠️ La referencia: solo alfanumérico y guion, en mayúscula.
  #
  # Daniel: *«no debe incluir caracteres especiales, solo alfanuméricos y guion
  # puede ser si la persona está haciendo dos reportes»*. Los espacios y los
  # puntos que copia la gente del SMS del banco convierten «0012 3456» y
  # «00123456» en dos referencias distintas, y entonces el índice único no
  # impide el reporte repetido — que es para lo que existe.
  FORMATO_DE_REFERENCIA = /\A[A-Z0-9-]{4,30}\z/

  validates :referencia, presence: true, format: { with: FORMATO_DE_REFERENCIA,
            message: "son letras, números y guion, entre 4 y 30 caracteres" }
  validates :referencia, uniqueness: { scope: :school_id,
            message: "ya fue reportada en este colegio" }
  validates :banco, presence: true, inclusion: { in: Banco::CODIGOS,
            message: "no está en la lista" }
  validates :monto, numericality: { greater_than: 0 }
  validates :depositante_nombre, presence: true, length: { maximum: 120 }
  validates :pagado_el, presence: true
  validate  :la_fecha_del_pago_es_reciente
  validate  :el_voucher_es_una_imagen

  normalizes :referencia, with: ->(valor) { valor.to_s.upcase.gsub(/[^A-Z0-9-]/, "") }
  normalizes :depositante_nombre, with: ->(valor) { Normaliza.titulo(valor) }

  before_validation :encoger_el_voucher

  scope :recientes_primero, -> { order(created_at: :desc) }
  scope :esperando, -> { where(estado: "en_revision").order(:created_at) }

  # ⚠️ Hasta dónde atrás admite el calendario.
  #
  # Daniel: *«el calendario no debe incluir fechas del año pasado, cosas así:
  # fechas de los últimos 3 días hacia adelante, del último mes hacia adelante»*.
  #
  # Un mes: alcanza para el pago que se reporta tarde y corta el dedazo de año
  # —«03/09/2025» en vez de 2026— que después nadie encuentra en el banco.
  DESDE_HACE = 1.month

  def self.desde = DESDE_HACE.ago.to_date
  def self.hasta = Date.current

  # ── Lo que dijo pagar, aunque se haya rechazado ───────────────────────────

  # ⚠️ `charges` es el enlace VIVO y se suelta al rechazar; esto es la HISTORIA.
  #
  # Sin ella, un reporte rechazado no dice de qué era —la oficina lo abre y ve
  # un monto sin cuotas— y no se puede volver a validar. Se escribe al crearlo y
  # no se toca más.
  def declarar!(cobros)
    ids = Array(cobros).map { |c| c.respond_to?(:id) ? c.id : c.to_i }
    update!(cobros_declarados: ids)
    Charge.where(id: ids).update_all(payment_report_id: id, updated_at: Time.current)
  end

  # Los cobros que declaró y que HOY se pueden dar por pagados: los que siguen
  # sin pagar y sin estar en manos de otro reporte.
  #
  # ⚠️ Si la familia ya volvió a reportarlos —porque el rechazo fue correcto y
  # los pagó de nuevo— acá no salen, y revalidar el viejo no pisa el nuevo.
  # ⚠️ Cae en el enlace VIVO cuando no hay historia, y no es cortesía con los
  # datos viejos: un reporte creado por otra puerta —una tarea, una consola— que
  # enlace los cobros sin declararlos se validaría marcando NADA, en silencio, y
  # la familia quedaría bloqueada después de que le validaron el pago.
  def cobros_recuperables
    ids = cobros_declarados.presence || charges.pluck(:id)

    Charge.where(id: ids, pagado_el: nil).where(payment_report_id: [ nil, id ])
  end

  def se_puede_validar? = en_revision? || (rechazado? && cobros_recuperables.any?)

  # ── Lo que hace la oficina ────────────────────────────────────────────────

  # ⚠️ Todo junto o nada: marcar los cobros y cambiar el estado son un solo
  # hecho. A medias queda un reporte validado con cobros que siguen debiendo, y
  # la familia bloqueada después de haber pagado.
  #
  # ⚠️ Vale también sobre un RECHAZADO, y esa es la salida del callejón: la
  # referencia es única por colegio, así que una familia a la que le rechazaron
  # un pago bueno no puede volver a reportarlo con el mismo número. Quien se
  # equivocó fue la oficina, y es la oficina la que lo arregla.
  def validar!(por:, cuando: Time.current)
    transaction do
      recuperables = cobros_recuperables.to_a
      update!(estado: "validado", revisado_por: por, revisado_el: cuando, motivo: nil)
      Charge.where(id: recuperables.map(&:id))
            .update_all(payment_report_id: id, pagado_el: cuando, updated_at: cuando)
    end
  end

  # ⚠️ Al rechazar, los cobros se SUELTAN: vuelven a estar sin reportar, así la
  # familia puede reportarlos de nuevo con la referencia correcta. Dejarlos
  # colgando del reporte rechazado los deja en un limbo que nadie sabe sacar.
  # ⚠️ Y limpia `pagado_el`, que es lo que lo convierte en DESHACER.
  #
  # Rechazar un reporte que ya se había validado dejaba los cobros pagados y
  # sueltos: la familia seguía viendo todo, el dinero seguía contado, y no había
  # forma de darse cuenta. Sin eso, validar rápido desde la bandeja sería una
  # decisión sin vuelta atrás.
  def rechazar!(por:, motivo:, cuando: Time.current)
    transaction do
      update!(estado: "rechazado", revisado_por: por, revisado_el: cuando, motivo: motivo)
      # ⚠️ Se suelta el enlace VIVO; `cobros_declarados` no se toca, que es lo
      # que permite volver a validarlo si el rechazo fue el error.
      Charge.where(payment_report_id: id)
            .update_all(payment_report_id: nil, pagado_el: nil, updated_at: cuando)
    end
  end

  def esperando_revision? = en_revision?
  def banco_a_la_vista = Banco.nombre(banco)

  private

  def la_fecha_del_pago_es_reciente
    return if pagado_el.blank?

    errors.add(:pagado_el, "no puede ser en el futuro") if pagado_el > self.class.hasta
    errors.add(:pagado_el, "es de hace más de un mes; escríbale al colegio") if pagado_el < self.class.desde
  end

  # ⚠️ Se exige IMAGEN o PDF, y se dice cuál falta. Sin esto, la oficina abre el
  # reporte y encuentra un `.docx` que no puede comparar con nada.
  TIPOS_DE_VOUCHER = %w[image/jpeg image/png image/webp image/heic application/pdf].freeze

  def el_voucher_es_una_imagen
    return unless voucher.attached?
    return if TIPOS_DE_VOUCHER.include?(voucher.blob.content_type)

    errors.add(:voucher, "tiene que ser una foto o un PDF")
  end

  def encoger_el_voucher = EncogeElVoucher.new(voucher).encoger!
end
