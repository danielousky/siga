# Lo que un colegio dice que le pagó a SIGA (spec `docs/specs/del-registro-al-cobro.md`,
# § 5.5 a 5.7).
#
#     en_revision  ──►  validado    la suscripción queda activa un mes, y se abre todo
#                  └─►  rechazado   con su motivo; el colegio puede volver a reportar
#
# ## ⚠️ Reportar NO abre nada
#
# Lo abre la validación del fundador (decisión 4). Sin esa separación, quien
# escriba cualquier número de referencia se activa el sistema: es la misma
# razón por la que un reporte de la familia no paga ninguna cuota por sí solo.
#
# ## ⚠️ Y no es un `PaymentReport`
#
# Aquel es la familia pagándole al COLEGIO, con sus cuotas y su oficina. Este es
# el colegio pagándole a SIGA. Comparten la forma de la referencia y el
# calendario del pago, que se reutilizan de allá; no comparten quién valida ni
# qué pasa al validar.
class SubscriptionPayment < ApplicationRecord
  include SchoolScoped

  belongs_to :school
  belongs_to :reportado_por, class_name: "User"
  belongs_to :revisado_por, class_name: "User", optional: true

  # Una foto de la pantalla del banco o el PDF que bajó. Se encoge al recibirla,
  # como el voucher de la familia (`EncogeElVoucher`).
  has_one_attached :comprobante

  # Los tres medios de la decisión 9. Zelle no.
  #
  # ⚠️ La UNIDAD del monto la da el medio: Pago Móvil y transferencia se pagan
  # en bolívares, a la tasa BCV del día; Binance y el efectivo, en dólares. SIGA
  # no guarda tasas: la cuenta la hace quien paga, y el fundador la revisa al
  # validar (§ 4.4).
  MEDIOS = {
    "pago_movil" => { nombre: "Pago Móvil o transferencia", unidad: "Bs" },
    "binance"    => { nombre: "Binance (USDT)",             unidad: "$" },
    "efectivo"   => { nombre: "Efectivo en dólares",        unidad: "$" }
  }.freeze

  ESTADOS = %w[en_revision validado rechazado].freeze

  enum :medio,  MEDIOS.keys.index_by(&:itself), validate: true
  enum :estado, ESTADOS.index_by(&:itself), default: "en_revision", validate: true

  # ⚠️ La referencia, con la regla de la familia: letras, números y guion, en
  # mayúscula. «0012 3456» y «00123456» son el mismo pago, y sin normalizar el
  # índice único no impide reportarlo dos veces.
  normalizes :referencia, with: ->(valor) { valor.to_s.upcase.gsub(/[^A-Z0-9-]/, "").presence }

  validates :monto, numericality: { greater_than: 0 }
  validates :pagado_el, presence: true
  validates :referencia, presence: { message: "hace falta: es lo que buscamos en el banco" }, unless: :efectivo?
  validates :referencia, format: { with: PaymentReport::FORMATO_DE_REFERENCIA,
                                   message: "son letras, números y guion, entre 4 y 30 caracteres" },
                         allow_blank: true
  validate  :la_referencia_no_se_repite
  validate  :la_fecha_del_pago_es_reciente
  validate  :el_comprobante_va_salvo_en_efectivo
  validate  :uno_en_revision_a_la_vez, on: :create

  before_validation :encoger_el_comprobante

  scope :esperando,         -> { where(estado: "en_revision").order(:created_at) }
  scope :recientes_primero, -> { order(created_at: :desc) }
  scope :revisados,         -> { where.not(estado: "en_revision") }

  # ── Reportar ──────────────────────────────────────────────────────────────

  # Un reporte nuevo, con la cotización de hoy ya escrita.
  #
  # ⚠️ El precio se CONGELA al reportar: es lo que el colegio vio en su pantalla
  # y lo que pagó. Si inscribe diez alumnos más antes de que se valide, el pago
  # sigue siendo por lo que se le dijo.
  def self.nuevo_para(suscripcion, por:, **datos)
    cotizacion = suscripcion.cotizacion

    new(school: suscripcion.school, reportado_por: por,
        alumnos: cotizacion.alumnos, precio_por_alumno: cotizacion.por_alumno,
        minimo_mensual: cotizacion.minimo, precio_mensual: cotizacion.monto,
        iva: cotizacion.iva, **datos)
  end

  # La cuenta con que se reportó, en la misma forma que la de la suscripción.
  def cotizacion
    Subscription::Cotizacion.new(alumnos: alumnos, por_alumno: precio_por_alumno,
                                 minimo: minimo_mensual, monto: precio_mensual, iva: iva)
  end

  def nombre_del_medio = MEDIOS.dig(medio, :nombre)
  def unidad           = MEDIOS.dig(medio, :unidad)

  # El medio decide qué se pide: en efectivo no hay referencia ni, a veces, papel.
  def pide_referencia? = !efectivo?

  # ── Lo que hace el fundador ───────────────────────────────────────────────

  # Lo que ya se revisó no se vuelve a decidir: validar dos veces sumaría dos
  # meses por un solo pago, y rechazar uno validado dejaría al colegio activo
  # con un pago «rechazado».
  class YaRevisado < StandardError; end

  # ⚠️ Todo junto o nada: el reporte validado y la suscripción activa son un
  # solo hecho. A medias queda un colegio que pagó, con su pago «validado», y
  # sin poder calificar.
  #
  # ⚠️ El mes se calcula ANTES de tocar la suscripción —depende de cuándo vencía—
  # y el reporte se marca validado ANTES de activarla: mientras siguiera «en
  # revisión», la suscripción no podría bajar de estado aunque el mes pagado ya
  # hubiera pasado (`Subscription#actualizar_estado!`).
  #
  # ⚠️ Con la fila BLOQUEADA (`with_lock`): un doble clic en «Validar» son dos
  # peticiones que leen «en revisión» a la vez. Sin el candado pasan las dos, y
  # el colegio recibe dos meses por un pago.
  def validar!(por:, hoy: Date.current)
    with_lock do
      raise YaRevisado unless en_revision?

      suscripcion = Subscription.find_by!(school_id: school_id)
      desde = suscripcion.inicio_del_mes_pagado(reportado_el: created_at.to_date, hoy: hoy)

      update!(estado: "validado", revisado_por: por, revisado_el: Time.current, motivo: nil,
              cubre_desde: desde, cubre_hasta: desde + 1.month)
      suscripcion.activar_con!(self)
    end
  end

  # ⚠️ El motivo es obligatorio: un rechazo sin explicación deja al colegio
  # reportando lo mismo otra vez, y al fundador revisándolo otra vez.
  def rechazar!(por:, motivo:)
    if motivo.to_s.strip.blank?
      errors.add(:motivo, "tiene que decir por qué se rechaza")
      raise ActiveRecord::RecordInvalid, self
    end

    with_lock do
      raise YaRevisado unless en_revision?

      update!(estado: "rechazado", revisado_por: por, revisado_el: Time.current, motivo: motivo.to_s.strip)
    end
  end

  # El colegio puede retirar su reporte mientras nadie lo ha mirado: se
  # equivocó de monto o de referencia, y como solo cabe uno en revisión, sin
  # esto quedaría esperando a que se lo rechacen.
  def se_puede_retirar? = en_revision?

  # ── El calendario ─────────────────────────────────────────────────────────

  # El de la familia: del último mes hasta hoy. Corta el dedazo de año
  # —«03/09/2025» en vez de 2026— antes de que nadie lo busque en el banco.
  def self.desde = PaymentReport.desde
  def self.hasta = PaymentReport.hasta

  private

  def la_referencia_no_se_repite
    return if referencia.blank? || school_id.blank?

    repetida = self.class.where(school_id: school_id, referencia: referencia)
                         .where.not(estado: "rechazado").where.not(id: id).exists?
    errors.add(:referencia, "ya se reportó en otro pago") if repetida
  end

  def la_fecha_del_pago_es_reciente
    return if pagado_el.blank?

    errors.add(:pagado_el, "no puede ser en el futuro") if pagado_el > self.class.hasta
    errors.add(:pagado_el, "es de hace más de un mes; escríbanos por WhatsApp") if pagado_el < self.class.desde
  end

  # Imagen o PDF, como el voucher de la familia: un `.docx` no se puede
  # comparar con el banco.
  TIPOS_DE_COMPROBANTE = PaymentReport::TIPOS_DE_VOUCHER

  def el_comprobante_va_salvo_en_efectivo
    if comprobante.attached?
      return if TIPOS_DE_COMPROBANTE.include?(comprobante.blob.content_type)

      errors.add(:comprobante, "tiene que ser una foto o un PDF")
    elsif !efectivo?
      errors.add(:comprobante, "hace falta: es lo que se compara con el banco")
    end
  end

  # ⚠️ Uno a la vez (§ 5.5), y la base lo sostiene con un índice parcial. Esto
  # lo dice con palabras antes de que el índice lo diga con un error.
  def uno_en_revision_a_la_vez
    return if school_id.blank?
    return unless self.class.where(school_id: school_id, estado: "en_revision").exists?

    errors.add(:base, "Ya hay un pago esperando validación. Cuando se resuelva, puede reportar otro.")
  end

  def encoger_el_comprobante = EncogeElVoucher.new(comprobante).encoger!
end
