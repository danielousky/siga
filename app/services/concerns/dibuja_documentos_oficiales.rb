# Lo que comparten los documentos oficiales que emite un colegio (MOR-98, MOR-99).
#
# El boletín y la Certificación de Calificaciones son papeles distintos, pero se
# firman igual, se sellan igual y sufren el mismo problema de fuentes. Vive acá
# porque el razonamiento del sello y el del `rescue` costaron un bug cada uno, y
# copiados en dos archivos garantizan que el próximo arreglo toque uno solo.
module DibujaDocumentosOficiales
  extend ActiveSupport::Concern

  ANCHO_DE_FIRMA = 200
  ALTO_DE_FIRMA = 46
  LADO_DEL_SELLO = 62

  class_methods do
    # ⚠️ Limitación conocida de Prawn, y la razón de `texto`.
    #
    # Las fuentes que trae de fábrica cubren Windows-1252: todo el español —á é í
    # ó ú ü ñ y sus mayúsculas—, más portugués, italiano, francés y alemán. Lo
    # que NO cubren es cirílico, árabe, chino o el este de Europa (ș, ğ, ł).
    #
    # Con un nombre así, Prawn LEVANTA UNA EXCEPCIÓN al dibujar. En un documento
    # oficial eso es inaceptable: el papel de un alumno no se puede caer por cómo
    # se escribe su apellido. Lo que no se puede representar se translitera; lo
    # que sí —el 99,9 % de los casos— se imprime tal cual.
    def representable?(cadena)
      cadena.encode("Windows-1252")
      true
    rescue Encoding::UndefinedConversionError, Encoding::ConverterNotFoundError
      false
    end

    def texto(valor)
      cadena = valor.to_s
      representable?(cadena) ? cadena : ActiveSupport::Inflector.transliterate(cadena)
    end
  end

  private

  def texto(valor) = self.class.texto(valor)

  # La firma del director, con su sello encima.
  #
  # Si el colegio cargó su firma escaneada se dibuja sobre la línea. **No es una
  # firma digital** —es un facsímil, como el sello de goma— y no hay que
  # presentarla como otra cosa.
  def firma_del_director(pdf, colegio, rotulo: "Director(a)", nombre: nil, documento: nil)
    escaneada = colegio&.firma_para_pdf
    estampa   = colegio&.sello_para_pdf
    izquierda = (pdf.bounds.width - ANCHO_DE_FIRMA) / 2
    arriba    = pdf.cursor

    if escaneada
      # `fit` y no `width`: una firma escaneada viene con la proporción que
      # tenga, y estirarla la vuelve una caricatura de sí misma.
      pdf.bounding_box([ izquierda, arriba ], width: ANCHO_DE_FIRMA, height: ALTO_DE_FIRMA) do
        pdf.image escaneada, fit: [ ANCHO_DE_FIRMA, ALTO_DE_FIRMA - 2 ], position: :center
      end
    else
      pdf.move_down ALTO_DE_FIRMA
    end

    linea = pdf.cursor
    pdf.stroke_color "666666"
    pdf.stroke_line [ izquierda + 20, linea ], [ izquierda + ANCHO_DE_FIRMA - 20, linea ]
    pdf.move_down 4

    pdf.text rotulo, size: 8, align: :center
    if nombre.present?
      pdf.text texto(nombre), size: 8, align: :center
      pdf.text "C.I. #{texto(documento)}", size: 7, align: :center, color: "666666" if documento.present?
    end

    sello_encima(pdf, estampa, izquierda: izquierda, arriba: arriba, linea: linea) if estampa
  end

  # El sello, encima de todo lo demás.
  #
  # Queda montado sobre el último tercio de la firma y cruzando la línea, que es
  # donde cae en un papel real: un sello estampado al costado, sobre el aire, es
  # exactamente el que se puede recortar y pegar en otro documento.
  #
  # `float` deja el cursor donde estaba — el sello se dibuja ENCIMA de lo que ya
  # hay, no debajo. Sin eso el bloque empuja el resto del pie hacia abajo y lo
  # que sigue se queda sin página; así apareció este bug, como un
  # `Prawn::Errors::CannotFit` lanzado en OTRO método.
  #
  # `transparent` deja ver el trazo del bolígrafo debajo. Un sello opaco encima
  # de la firma la borraría, que es lo contrario de lo que se busca.
  def sello_encima(pdf, estampa, izquierda:, arriba:, linea:)
    x = izquierda + (ANCHO_DE_FIRMA * 0.58)
    y = ((arriba + linea) / 2.0) + (LADO_DEL_SELLO / 2.0) - 2

    pdf.float do
      # ⚠️ El `rescue` va DENTRO del `bounding_box`, no a nivel del método: si la
      # excepción escapa del bloque, Prawn nunca restaura los límites de la
      # página y el resto del documento se dibuja dentro de una caja de 62 pt.
      pdf.bounding_box([ x, y ], width: LADO_DEL_SELLO, height: LADO_DEL_SELLO) do
        pdf.transparent(0.62) { pdf.image estampa, fit: [ LADO_DEL_SELLO, LADO_DEL_SELLO ], position: :center }
      rescue StandardError
        nil
      end
    end
  end
end
