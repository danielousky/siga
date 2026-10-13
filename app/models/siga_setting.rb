# Los datos para pagarle a SIGA (spec `docs/specs/del-registro-al-cobro.md`,
# decisiones 21 y 22).
#
#     /siga/ajustes  ──►  el fundador los cambia
#                    ──►  «Suscripción» los usa en la petición siguiente,
#                         sin reiniciar nada
#
# ## Por qué una tabla y no variables de entorno
#
# Cambiar de cuenta no puede exigir un despliegue ni entrar al servidor.
#
# ⚠️ El WhatsApp vivía aquí, y desde el 12 de octubre de 2026 vive en `Setup`
# —nombre y valor—, junto con la dirección de la muestra (decisión 35). Binance
# se mudó allá esa misma noche, y PayPal nació allá (decisión 36): un medio de
# UN dato es una variable. Lo que queda es lo que va JUNTO: Pago Móvil y
# transferencia comparten titular y cédula, y se validan entre sí.
#
# Esta clase sigue siendo la que contesta «cómo se le paga a SIGA»: lee sus
# columnas y, de `Setup`, los medios de un solo dato.
#
# ## ⚠️ Es de la PLATAFORMA, no de un colegio
#
# Sin `school_id` y sin RLS, igual que `SigaStaff`: no hay colegio que filtrar.
# Por eso se edita solo desde `/siga`.
#
# ## ⚠️ Un medio sin sus datos completos NO se ofrece
#
# Un Pago Móvil sin cédula o un Binance sin ID no se pueden pagar, y ofrecerlos
# deja al colegio con el teléfono en la mano y sin a dónde mandar el dinero. Lo
# mismo que el botón de WhatsApp sin número (`ContactoHelper`): mejor no tenerlo.
class SigaSetting < ApplicationRecord
  belongs_to :actualizado_por, class_name: "User", optional: true

  FORMATO_DE_DOCUMENTO = /\A[VEJGP]-\d{5,9}(-\d)?\z/
  FORMATO_DE_CUENTA    = /\A\d{20}\z/

  normalizes :pago_movil_telefono, with: ->(valor) { Setup.telefono(valor) }
  # «V-12.345.678» y «v 12345678» son la misma cédula: se guarda una sola forma.
  normalizes :documento, with: ->(valor) { valor.to_s.upcase.gsub(/[\s.]/, "").sub(/\A([VEJGP])(\d)/, '\1-\2').presence }
  normalizes :cuenta, with: ->(valor) { valor.to_s.gsub(/\D/, "").presence }
  normalizes :titular, with: ->(valor) { valor.to_s.squish.presence }

  validate  :el_telefono_es_movil
  validates :pago_movil_banco, inclusion: { in: Banco::CODIGOS, message: "no está en la lista" }, allow_blank: true
  validates :documento, format: { with: FORMATO_DE_DOCUMENTO,
                                  message: "es una cédula o un RIF: V-12345678, J-12345678-9" }, allow_blank: true
  validates :cuenta, format: { with: FORMATO_DE_CUENTA, message: "son veinte dígitos" }, allow_blank: true
  validates :titular, length: { maximum: 120 }

  # Los ajustes de hoy. Si nadie los guardó todavía, unos en blanco, sin
  # escribir nada en la base.
  def self.actuales
    first || new
  end

  # ── Qué se ofrece ─────────────────────────────────────────────────────────

  # Pago Móvil y transferencia son el mismo medio para el colegio —en
  # bolívares, a la tasa BCV del día—, pero cada uno pide sus datos.
  def pago_movil?    = [ pago_movil_banco, pago_movil_telefono, documento ].all?(&:present?)
  def transferencia? = [ cuenta, titular, documento ].all?(&:present?)

  # Los medios de un solo dato viven en `Setup` (decisión 36).
  def binance  = Setup.binance
  def paypal   = Setup.paypal
  def binance? = binance.present?
  def paypal?  = paypal.present?

  # El efectivo no tiene datos: se coordina por WhatsApp. Sin WhatsApp no hay
  # con quién coordinarlo —y el número vive en `Setup`—.
  def efectivo? = Setup.whatsapp?

  # Los medios que «Suscripción» ofrece, en el orden de `SubscriptionPayment::MEDIOS`.
  def medios
    SubscriptionPayment::MEDIOS.keys.select do |medio|
      case medio
      when "pago_movil" then pago_movil? || transferencia?
      when "binance"    then binance?
      when "paypal"     then paypal?
      when "efectivo"   then efectivo?
      end
    end
  end

  # La cuenta dice su banco en los primeros cuatro dígitos.
  def banco_de_la_cuenta = cuenta.present? ? Banco.nombre(cuenta[0, 4]) : nil

  private

  def el_telefono_es_movil
    return if pago_movil_telefono.blank? || Contacto.movil?(pago_movil_telefono)

    errors.add(:pago_movil_telefono, "tiene que ser un celular: 0412, 0414, 0416, 0424 o 0426")
  end
end
