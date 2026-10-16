# Cómo se contacta a una familia desde SIGA (MOR-181).
#
# Daniel: *«la comunicación con el representante es fundamental. Allí mismo
# debemos poder componerle un correo y enviárselo o whatsapearlo con el número
# telefónico»*.
#
# ## Los dos canales, y por qué se resuelven distinto
#
#     WhatsApp   un ENLACE. Abre la app del teléfono con el número y el texto
#                puestos; SIGA no manda nada ni se entera de si se envió.
#     Correo     lo manda SIGA, con su servidor, y queda en la auditoría.
#
# No son dos versiones de lo mismo: en el primero la secretaria termina de
# escribir afuera, en el segundo el colegio deja constancia.
class Contacto
  # Los prefijos móviles de Venezuela. Un fijo —0212, 0261— no tiene WhatsApp,
  # así que el botón no se ofrece: un enlace que no lleva a ningún lado es peor
  # que no tenerlo.
  MOVILES = %w[0412 0414 0416 0424 0426].freeze
  PAIS = "58".freeze

  # `0414-1112233` → `584141112233`, que es lo que espera `wa.me`.
  #
  # ⚠️ Se quita el CERO inicial antes de anteponer el país: «58» + «0414…» es un
  # número que no existe y WhatsApp abre igual, con un chat vacío hacia nadie.
  def self.whatsapp(telefono)
    digitos = telefono.to_s.gsub(/\D/, "")
    return nil unless movil?(digitos)

    "#{PAIS}#{digitos.sub(/\A0/, '')}"
  end

  def self.movil?(telefono)
    digitos = telefono.to_s.gsub(/\D/, "")

    digitos.length == 11 && MOVILES.include?(digitos[0, 4])
  end

  # La URL de wa.me, con el saludo ya escrito si se le pasa uno.
  #
  # ⚠️ `url_encode` y no `CGI.escape`: el segundo escribe los espacios como «+»,
  # que es la regla de los formularios y no la de una dirección. WhatsApp
  # documenta `%20`, y el mensaje del enlace de acceso lleva saltos de línea y
  # una dirección adentro: no se apuesta a que cada versión de la app lea igual.
  def self.whatsapp_url(telefono, texto = nil)
    numero = whatsapp(telefono)
    return nil if numero.nil?

    url = "https://wa.me/#{numero}"
    url += "?text=#{ERB::Util.url_encode(texto)}" if texto.present?
    url
  end
end
