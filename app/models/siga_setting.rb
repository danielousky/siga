# Los ajustes de la plataforma: el WhatsApp de SIGA y los datos para pagarle
# (spec `docs/specs/del-registro-al-cobro.md`, decisiones 20 a 22).
#
#     /siga/ajustes  ──►  el fundador los cambia
#                    ──►  «Suscripción» y los botones de WhatsApp los usan en la
#                         petición siguiente, sin reiniciar nada
#
# ## Por qué una tabla y no variables de entorno
#
# Cambiar de número o de cuenta no puede exigir un despliegue ni entrar al
# servidor. El número de WhatsApp era la variable `SIGA_WHATSAPP`, leída una vez
# al arrancar: cambiarlo era reiniciar la app.
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

  normalizes :whatsapp, :pago_movil_telefono, with: ->(valor) { telefono_con_guion(valor) }
  # «V-12.345.678» y «v 12345678» son la misma cédula: se guarda una sola forma.
  normalizes :documento, with: ->(valor) { valor.to_s.upcase.gsub(/[\s.]/, "").sub(/\A([VEJGP])(\d)/, '\1-\2').presence }
  normalizes :cuenta, with: ->(valor) { valor.to_s.gsub(/\D/, "").presence }
  normalizes :titular, :binance, with: ->(valor) { valor.to_s.squish.presence }

  validate  :los_telefonos_son_moviles
  validates :pago_movil_banco, inclusion: { in: Banco::CODIGOS, message: "no está en la lista" }, allow_blank: true
  validates :documento, format: { with: FORMATO_DE_DOCUMENTO,
                                  message: "es una cédula o un RIF: V-12345678, J-12345678-9" }, allow_blank: true
  validates :cuenta, format: { with: FORMATO_DE_CUENTA, message: "son veinte dígitos" }, allow_blank: true
  validates :titular, length: { maximum: 120 }
  validates :binance, length: { maximum: 120 }

  # Los ajustes de hoy. Si nadie los guardó todavía, unos en blanco —con el
  # WhatsApp de la variable, si está puesta—, sin escribir nada en la base.
  #
  # ⚠️ `SIGA_WHATSAPP` sirve de valor INICIAL, y nada más (§ 7 del spec): si
  # está puesta en producción, el botón no desaparece el día del cambio. Desde
  # que el fundador guarda los ajustes, manda la base.
  def self.actuales
    first || new(whatsapp: whatsapp_del_entorno)
  end

  # `584241234567` —el formato de `wa.me`, el de la variable— a `0424-1234567`.
  def self.whatsapp_del_entorno
    digitos = ENV["SIGA_WHATSAPP"].to_s.gsub(/\D/, "")
    digitos = "0#{digitos.delete_prefix(Contacto::PAIS)}" if digitos.length == 12 && digitos.start_with?(Contacto::PAIS)

    telefono_con_guion(digitos) if Contacto.movil?(digitos)
  end

  def self.telefono_con_guion(valor)
    digitos = valor.to_s.gsub(/\D/, "")
    return nil if digitos.blank?

    digitos.length == 11 ? "#{digitos[0, 4]}-#{digitos[4..]}" : digitos
  end

  # ── Qué se ofrece ─────────────────────────────────────────────────────────

  def whatsapp? = whatsapp.present?

  def whatsapp_url(texto = nil) = Contacto.whatsapp_url(whatsapp, texto)

  # Pago Móvil y transferencia son el mismo medio para el colegio —en
  # bolívares, a la tasa BCV del día—, pero cada uno pide sus datos.
  def pago_movil?    = [ pago_movil_banco, pago_movil_telefono, documento ].all?(&:present?)
  def transferencia? = [ cuenta, titular, documento ].all?(&:present?)
  def binance?       = binance.present?

  # El efectivo no tiene datos: se coordina por WhatsApp. Sin WhatsApp no hay
  # con quién coordinarlo.
  def efectivo? = whatsapp?

  # Los medios que «Suscripción» ofrece, en el orden de `SubscriptionPayment::MEDIOS`.
  def medios
    SubscriptionPayment::MEDIOS.keys.select do |medio|
      case medio
      when "pago_movil" then pago_movil? || transferencia?
      when "binance"    then binance?
      when "efectivo"   then efectivo?
      end
    end
  end

  # La cuenta dice su banco en los primeros cuatro dígitos.
  def banco_de_la_cuenta = cuenta.present? ? Banco.nombre(cuenta[0, 4]) : nil

  private

  def los_telefonos_son_moviles
    { whatsapp: whatsapp, pago_movil_telefono: pago_movil_telefono }.each do |campo, valor|
      next if valor.blank? || Contacto.movil?(valor)

      errors.add(campo, "tiene que ser un celular: 0412, 0414, 0416, 0424 o 0426")
    end
  end
end
