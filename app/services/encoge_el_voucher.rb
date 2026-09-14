# La foto del voucher, guardada al tamaño en que se lee (spec:
# `docs/specs/pagos-de-la-familia.md`).
#
# Daniel: *«hoy en día la gente le toma foto al voucher… el peso a veces llega
# hasta unos cuantos MB, 3 MB, 4 MB»*.
#
#     entra      3–4 MB    la foto tal cual sale del teléfono
#     se guarda  ~250 KB   1600 px de lado mayor, JPEG al 78 %
#
# ## ⚠️ Se guarda la ENCOGIDA, no la original
#
# Una variante de Active Storage guarda las DOS —el original y la derivada— y
# acá el original no aporta nada: a 1600 px la referencia del voucher se lee sin
# esfuerzo, que es lo único que la oficina necesita comparar con el banco.
#
# En un colegio de 360 alumnos con once cuotas al año, la diferencia entre
# guardar los dos y guardar uno es de unos 12 GB a menos de 1 GB. Con el disco
# local de Dokku —un volumen en `/rails/storage`— eso es la diferencia entre
# tener que contratar S3 este año o no.
#
# ## ⚠️ Un PDF no se toca
#
# Quien adjunta el comprobante que descargó del banco manda un PDF, y ahí no hay
# nada que encoger: pesa poco y redibujarlo como imagen le quita el texto
# seleccionable, que es justo lo que hace fácil buscar la referencia.
class EncogeElVoucher
  LADO_MAYOR = 1600
  CALIDAD = 78
  # Por debajo de esto no vale la pena: una captura de pantalla ya viene chica y
  # volver a comprimirla solo le quita nitidez a los números.
  DESDE = 400.kilobytes

  def initialize(adjunto)
    @adjunto = adjunto
  end

  def encoger!
    return unless procede?

    original = @adjunto.blob
    encogida = redibujar(original)
    return if encogida.nil?

    @adjunto.attach(io: encogida, filename: nombre_de(original), content_type: "image/jpeg")
  rescue StandardError => e
    # ⚠️ Un fallo al encoger NO puede perder el reporte. La foto original queda
    # adjunta tal cual —pesa más y ya— y el pago se registra igual, que es lo
    # que le importa a la familia.
    Rails.logger.warn("[voucher] no se pudo encoger: #{e.class} #{e.message}")
    nil
  end

  private

  def procede?
    return false unless @adjunto.attached?
    return false unless @adjunto.blob.image?
    return false if @adjunto.blob.content_type == "application/pdf"

    @adjunto.blob.byte_size > DESDE
  end

  # ⚠️ `source` NO acepta un `StringIO`, y el `rescue` de arriba se lo tragaba.
  #
  # `ImageProcessing::Vips.source(StringIO.new(...))` levanta «invalid source» —
  # quiere un archivo de verdad: `File`, `Tempfile`, `Pathname` o `Vips::Image`.
  # Con el rescue puesto, eso era una línea en el log y un voucher que se
  # guardaba entero: la función no hacía NADA y nada fallaba.
  #
  # El rescue sigue estando y es correcto —perder el reporte por no poder
  # encoger una foto sería mucho peor— pero por eso existe el test que compara
  # los bytes de antes y los de después.
  def redibujar(blob)
    require "image_processing/vips"

    original = Tempfile.new([ "voucher", ".bin" ], binmode: true)
    original.write(blob.download)
    original.flush

    procesada = ImageProcessing::Vips
                .source(original)
                .resize_to_limit(LADO_MAYOR, LADO_MAYOR)
                .convert("jpeg")
                .saver(quality: CALIDAD, strip: true)   # `strip` se lleva el GPS
                .call

    File.open(procesada.path, "rb")
  ensure
    original&.close
  end

  # ⚠️ Se le cambia la extensión: quedó JPEG, y un `voucher.png` que por dentro
  # es JPEG confunde a quien lo descargue.
  def nombre_de(blob) = "#{File.basename(blob.filename.to_s, '.*')}.jpg"
end
