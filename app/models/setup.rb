# Los ajustes sueltos de la plataforma: una fila por dato, con su nombre y su
# valor.
#
#     nombre               valor                           lo usa
#     whatsapp             0414-1234567                    los botones de WhatsApp y el efectivo
#     url_de_la_muestra    https://demo.sigaeducando.com   «Vea un colegio funcionando»
#
# Daniel, 12 de octubre de 2026: *«vamos a agregar una tabla que se llame setup
# que sea nombre del campo, valor»*. Se cambian en `/siga/ajustes`, y los ven
# los colegios en la petición siguiente: ni un despliegue ni entrar al servidor.
#
# ## ⚠️ Solo los nombres que el código conoce
#
# La tabla admite cualquier nombre, pero el modelo solo los de `CAMPOS`, cada
# uno con su forma de limpiarse y de validarse. Un dato nuevo es una entrada
# más ahí y su campo en `/siga/ajustes` —sin migración—, y una fila con un
# nombre que nadie lee no se puede crear por error.
#
# ## ⚠️ Es de la PLATAFORMA, no de un colegio
#
# Sin `school_id` y sin RLS, como `SigaStaff` y `SigaSetting`. Y fuera del
# borrado de `demo:limpiar` y del restablecido de la muestra
# (`OrdenDeBorrado::NO_SE_TOCAN`): es configuración, no datos.
#
# ⚠️ La tabla se llama `setup`, en singular, porque así la nombró Daniel; Rails
# la habría buscado como `setups`.
class Setup < ApplicationRecord
  self.table_name = "setup"

  belongs_to :actualizado_por, class_name: "User", optional: true

  # Cada dato: cómo se limpia y qué tiene que cumplir. Cómo se llama y qué
  # explica lo dice la pantalla (`siga/ajustes/show`), que es donde se lee.
  #
  # ⚠️ Vacío vale en los dos, y significa «no hay»: sin WhatsApp no se dibuja
  # el botón, y sin dirección la portada no ofrece la muestra.
  Campo = Data.define(:nombre, :limpiar, :problema)

  CAMPOS = [
    Campo.new(
      nombre: "whatsapp",
      limpiar: ->(valor) { Setup.telefono(valor) },
      problema: lambda do |valor|
        "El WhatsApp tiene que ser un celular: 0412, 0414, 0416, 0424 o 0426." unless Contacto.movil?(valor)
      end
    ),
    Campo.new(
      nombre: "url_de_la_muestra",
      limpiar: ->(valor) { valor.to_s.strip.delete_suffix("/").presence },
      problema: lambda do |valor|
        "La dirección de la muestra tiene que ser completa, así: https://demo.sigaeducando.com" \
          unless Setup.direccion_web?(valor)
      end
    )
  ].index_by(&:nombre).freeze

  validates :nombre, presence: true, uniqueness: true, inclusion: { in: CAMPOS.keys }
  validate :el_valor_cumple

  before_validation { self.valor = campo.limpiar.call(valor) if campo }

  def campo = CAMPOS[nombre]

  # ── Leer ──────────────────────────────────────────────────────────────────
  #
  # Una consulta por dato. Una página que pregunta tres veces por el WhatsApp
  # —la portada lo hace— no paga tres: dentro de una petición, Rails guarda el
  # resultado de una consulta repetida (el caché de consultas).

  def self.fila(nombre) = find_by(nombre: nombre.to_s)

  def self.valor(nombre) = fila(nombre)&.valor.presence

  # ⚠️ El WhatsApp tiene un valor INICIAL: la variable `SIGA_WHATSAPP`, si está
  # puesta. Vale mientras no exista la fila: desde que el fundador guarda los
  # ajustes —aunque sea vacío—, manda la base. Así el botón no desapareció el
  # día que el número pasó de la variable a la base, y así lo recibe la
  # muestra, donde nadie entra a `/siga`.
  def self.whatsapp
    fila = fila("whatsapp")
    fila ? fila.valor.presence : whatsapp_del_entorno
  end

  def self.whatsapp? = whatsapp.present?

  def self.whatsapp_url(texto = nil) = Contacto.whatsapp_url(whatsapp, texto)

  def self.url_de_la_muestra = valor("url_de_la_muestra")

  # `584241234567` —el formato de `wa.me`, el de la variable— a `0424-1234567`.
  def self.whatsapp_del_entorno
    numero = telefono(ENV["SIGA_WHATSAPP"])
    numero if Contacto.movil?(numero)
  end

  # Una dirección que un navegador abre: con su `https://` y su dominio.
  # «demo.sigaeducando.com» a secas no lo es —un enlace sin esquema es relativo,
  # y llevaría a `sigaeducando.com/demo.sigaeducando.com`—.
  def self.direccion_web?(valor)
    uri = URI.parse(valor.to_s)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  # Un celular venezolano escrito como sea —«04141234567», «0414 123 45 67»,
  # «+58 414 1234567»— queda «0414-1234567», que es como se lee y como lo
  # pide el campo.
  def self.telefono(valor)
    digitos = valor.to_s.gsub(/\D/, "")
    return nil if digitos.blank?

    digitos = "0#{digitos.delete_prefix(Contacto::PAIS)}" if digitos.length == 12 && digitos.start_with?(Contacto::PAIS)
    digitos.length == 11 ? "#{digitos[0, 4]}-#{digitos[4..]}" : digitos
  end

  # ── El formulario ─────────────────────────────────────────────────────────

  # Una fila por campo, para `/siga/ajustes`: las que trae `cambios` —con lo
  # que se escribió y sus errores— y, de las demás, la guardada o una nueva.
  #
  # ⚠️ Sin fila de WhatsApp, el campo muestra el de `SIGA_WHATSAPP`: es el que
  # hoy ven los colegios, y guardar el formulario por otra cosa no puede
  # borrarlo.
  def self.para_el_formulario(cambios = [])
    traidas = cambios.index_by(&:nombre)

    CAMPOS.keys.map do |nombre|
      traidas[nombre] || find_or_initialize_by(nombre: nombre).tap do |fila|
        fila.valor = whatsapp_del_entorno if fila.new_record? && nombre == "whatsapp"
      end
    end
  end

  # Las filas de los campos que trae el formulario, con su valor puesto, SIN
  # guardar: quien llama las valida junto con lo demás y las guarda en la misma
  # transacción, o no guarda ninguna.
  #
  # ⚠️ Solo las que TRAE. Una fila de WhatsApp vacía no es lo mismo que
  # ninguna —apaga la variable `SIGA_WHATSAPP`—, así que no se crea una que
  # nadie escribió.
  def self.para_guardar(valores, por:)
    valores.to_h.stringify_keys.slice(*CAMPOS.keys).map do |nombre, valor|
      fila = find_or_initialize_by(nombre: nombre)
      # Limpio ya al asignar, para que «cambió» compare lo que se va a guardar:
      # «04141234567» sobre «0414-1234567» no es un cambio, ni tiene autor.
      fila.valor = fila.campo.limpiar.call(valor)
      fila.actualizado_por = por if fila.new_record? || fila.will_save_change_to_valor?
      fila
    end
  end

  private

  def el_valor_cumple
    return if campo.nil? || valor.blank?

    problema = campo.problema.call(valor)
    errors.add(:base, problema) if problema
  end
end
