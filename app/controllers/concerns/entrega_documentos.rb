# Cómo sale un documento de SIGA: en el visor del navegador, en otra pestaña.
#
# Daniel, 16 de octubre de 2026, con una constancia de prosecución abierta en
# el visor de Chrome: *«todos los documentos deberían tener una misma forma de
# salida… la previsualización (para que luego ellos decidan si la imprimen o la
# descargan) y en una pestaña aparte»*. Hasta ese día cada pantalla hacía lo
# que hizo quien la escribió:
#
#     ANTES                                        AHORA
#     Documentos (las tres pestañas)  se bajaba    todos: otra pestaña, en el
#     ficha: constancia y boletín     se bajaba    visor del navegador, que ya
#     ficha: primaria, inicial, 31059 se abría     trae imprimir y descargar
#                                     ENCIMA de SIGA
#     portal de la familia            se bajaba
#     el Excel                        se bajaba    se baja: ningún navegador
#                                                  previsualiza una planilla
#
# ## ⚠️ Lo que se EMITE abre la dirección de lo emitido, no la respuesta del POST
#
#     [Emitir] ──POST──► registra el papel ──303──► GET …/impresion.pdf?firma=…
#                        (código, auditoría)        el visor, en la pestaña nueva
#
# Con el PDF como respuesta del POST, recargar la pestaña emite OTRO papel, con
# otro código, y el botón de descargar del visor tiene que volver a pedir el
# documento: con un POST, Chrome solo lo intenta contra su caché, y hay
# reportes de que falla. La dirección firmada se recarga y se descarga sin
# emitir nada, y VENCE: no es una puerta para sacar papeles sin dejar rastro.
#
# ⚠️ Y lleva `.pdf`, que no es adorno: la pared de la suscripción reconoce un
# archivo por su FORMATO (`RespetaLaSuscripcion#pide_un_archivo?`), y en un
# controlador de `CON_SUSCRIPCION` un GET sin él pasa como una pantalla más.
#
# ## ⚠️ Un documento no se dibuja para una precarga
#
# Turbo 8 pide un enlace con solo pasar el mouse por encima, y los papeles de
# la ficha se auditan al dibujarse. El 16 de octubre, en la muestra, una
# constancia de prosecución quedó NUEVE veces en la auditoría en siete minutos,
# en pares separados por un segundo: Turbo la pedía, recibía un PDF que no sabe
# pintar, y la volvía a pedir como navegación normal. `target="_blank"` saca
# esos enlaces de Turbo —no los precarga ni los intercepta— y esto es la red
# para el día que alguien escriba uno sin él.
module EntregaDocumentos
  extend ActiveSupport::Concern

  # Lo que dura la dirección de un papel recién emitido: la jornada de quien lo
  # emitió, con la pestaña abierta y el botón de imprimir a mano.
  VIGENCIA_DE_LA_IMPRESION = 12.hours

  class ImpresionVencida < StandardError; end

  included do
    rescue_from ImpresionVencida do
      redirect_to url_for(action: :index),
                  alert: "Esa dirección ya no sirve: el documento se emite otra vez desde aquí."
    end
  end

  private

  # El PDF se ABRE. Imprimir y descargar los pone el visor del navegador.
  def entregar_pdf(documento, nombre)
    send_data documento.render, filename: nombre, type: "application/pdf", disposition: "inline"
  end

  # ⚠️ `type: :xlsx` y no el MIME escrito a mano: lo registra
  # `config/initializers/mime_types.rb`, y esa cadena de setenta caracteres
  # estuvo copiada en tres controllers — con una letra distinta, el navegador
  # ofrece «abrir con…» en vez de guardar, y nadie lo nota hasta que un colegio
  # lo reporta.
  def entregar_xlsx(documento)
    send_data documento.to_stream.read, filename: documento.nombre_de_archivo, type: :xlsx
  end

  # La pestaña que abrió el POST sigue hasta acá: un 303, para que el
  # navegador pida la dirección nueva con GET.
  def abrir_la_impresion(ruta)
    redirect_to ruta, status: :see_other
  end

  def firmar_la_impresion(datos)
    verificador_de_impresiones.generate(datos, expires_in: VIGENCIA_DE_LA_IMPRESION, purpose: :impresion)
  end

  # Lo que se firmó al emitir. Vencida o tocada a mano, no hay papel.
  def la_impresion
    @la_impresion ||= verificador_de_impresiones.verified(params[:firma].to_s, purpose: :impresion) ||
                      raise(ImpresionVencida)
  end

  # Los registros de la firma, en el orden en que se emitieron: un `where`
  # devuelve los suyos en el que quiera, y el PDF de una sección va por apellido.
  def en_el_orden_de_la_firma(relacion, ids)
    relacion.where(id: ids).index_by(&:id).values_at(*ids).compact.presence ||
      raise(ActiveRecord::RecordNotFound)
  end

  def verificador_de_impresiones = Rails.application.message_verifier("impresiones")

  def no_se_dibuja_en_una_precarga
    head :no_content if precarga?
  end

  # Turbo manda la suya; Chrome, cuando precarga por su cuenta, la estándar.
  def precarga?
    request.headers["X-Sec-Purpose"].to_s.include?("prefetch") ||
      request.headers["Sec-Purpose"].to_s.include?("prefetch")
  end
end
