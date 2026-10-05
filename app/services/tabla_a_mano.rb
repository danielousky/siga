# Una tabla dibujada a mano sobre Prawn: rectángulos y texto, fila por fila.
#
# ## Por qué existe, si `prawn-table` ya dibuja tablas
#
# Daniel, 1 de octubre de 2026, emitiendo los boletines de 4to Grado A: *«la
# generación de documentos tarda mucho»*. Sacadas las consultas de más, lo que
# quedaba era la tabla de competencias:
#
#     prawn-table     3 ms por fila   ·  una sección trae más de mil  ·  3,5 s
#     a mano          0,13 ms por fila                                 ·  0,15 s
#
# `prawn-table` es general —celdas que abarcan varias columnas, subtablas,
# imágenes, anchos que se negocian entre sí— y cada celda es un objeto que mide
# su texto armando una caja de texto completa. El boletín no usa nada de eso:
# son renglones de una línea con el ancho de columna ya decidido.
#
# ## Y por dos cosas que `prawn-table` hacía mal sin avisar
#
# 1. **Pisaba el tamaño de letra de cada celda.** `cell_style: { size: 9 }` se
#    aplica DESPUÉS de construir las celdas, así que las competencias pedían 7,5
#    y los indicadores 7, y salían todos a 9. El boletín ocupaba una hoja más de
#    las que se diseñaron, y nadie lo había notado porque «se veía bien».
# 2. **Se comía la sangría.** Estaba escrita con espacios al principio del
#    texto, y Prawn los recorta al acomodar un renglón. Acá la sangría es un
#    número (`sangria:`), no espacios: no depende de quién dibuje.
#
# ## ⚠️ El alto de la fila se decide AL DIBUJAR, no al construir
#
# Es lo que hace posible repartir un boletín entre sus hojas: se mide una vez
# —`altos`, el texto de cada fila sin aire— y después se puede dibujar con más
# o menos relleno según lo que convenga (`AcomodoEnHojas`). Con `prawn-table`
# probar un relleno distinto era volver a construir la tabla entera.
#
# ## Lo que NO hace, a propósito
#
# Ni celdas combinadas, ni cabecera repetida en cada hoja, ni alineación a la
# derecha. El día que haga falta, se agrega; hasta entonces cada cosa que no
# hace es una que no puede fallar.
class TablaAMano
  NEGRO = "000000".freeze

  # Lo que se guarda de cada celda después de medirla. `corrida` dice si el
  # texto no cupo en un renglón: esas —las menos— sí pasan por una caja de
  # texto, que es la que sabe partir palabras.
  Celda = Struct.new(:texto, :size, :estilo, :color, :fondo, :centrada, :al_medio, :sangria, :ancho, :alto,
                     :corrida, keyword_init: true)

  # El alto del TEXTO de cada fila, sin relleno: lo que `AcomodoEnHojas`
  # necesita para probar rellenos sin volver a medir nada.
  attr_reader :altos

  # `filas` es una lista de listas. Cada celda es un texto, o un Hash con
  # `content:` y lo que quiera cambiar: `size:`, `font_style:`, `text_color:`,
  # `fondo:`, `align:`, `sangria:`, `al_medio:`.
  #
  # `al_medio` centra el texto en el ALTO de la fila. Hace falta en una
  # cabecera donde unas celdas ocupan dos renglones —«MEDIO / BAJO»— y otras
  # uno: sin él, «MATERIA» queda colgada arriba, a destiempo de sus vecinas.
  #
  # `estilos` son los de una FILA entera, por su índice: `{ 0 => {…}, -1 => {…} }`
  # para la cabecera y el total. La celda manda sobre la fila, y la fila sobre
  # la tabla.
  #
  # `centradas` es el rango de columnas que van al centro. `nil` las deja todas
  # a la izquierda.
  def initialize(pdf, filas, anchos:, size: 9, relleno: [ 4, 6 ], borde: "DDDDDD", centradas: (1..), estilos: {})
    @pdf = pdf
    @anchos = anchos
    @relleno_v, @relleno_h = relleno
    @borde = borde
    @orillas = anchos.each_with_object([ 0.0 ]) { |ancho, xs| xs << xs.last + ancho }

    de_la_tabla = { size: size }
    @fondos = []
    @celdas = filas.each_with_index.map do |fila, f|
      de_la_fila = estilos[f] || estilos[f - filas.size] || {}
      @fondos << de_la_fila[:fondo]

      fila.each_with_index.map do |dato, c|
        medir(dato, c, de_la_tabla.merge(align: (centradas&.cover?(c) ? :center : :left)).merge(de_la_fila.except(:fondo)))
      end
    end
    @altos = @celdas.map { |fila| fila.map(&:alto).max || 0 }
  end

  def filas = @celdas.size

  # Lo que ocupa la tabla entera con ese relleno.
  def alto(relleno = @relleno_v) = @altos.sum + (2 * relleno * filas)

  # Todas las filas, una debajo de la otra.
  def dibujar(relleno = @relleno_v)
    filas.times { |f| dibujar_fila(f, relleno) }
  end

  # ⚠️ En tres pasadas —fondos, bordes, texto— y en ese orden. De a una celda
  # por vez, el fondo de la celda siguiente tapa el borde derecho de la
  # anterior: en un PDF lo último que se pinta queda arriba.
  def dibujar_fila(f, relleno = @relleno_v)
    alto = @altos[f] + (2 * relleno)
    # Red de seguridad: quien reparte las hojas ya decidió dónde saltar, pero
    # una fila no se dibuja a medias contra el borde por un cálculo ajeno.
    @pdf.start_new_page if @pdf.cursor - alto < -0.01
    arriba = @pdf.cursor
    celdas = @celdas[f]

    pintar([ 0, arriba ], @orillas.last, alto, @fondos[f]) if @fondos[f]
    celdas.each_with_index { |celda, c| pintar([ @orillas[c], arriba ], @anchos[c], alto, celda.fondo) if celda.fondo }

    if @borde
      @pdf.stroke_color @borde
      celdas.each_index { |c| @pdf.stroke_rectangle [ @orillas[c], arriba ], @anchos[c], alto }
    end

    celdas.each_with_index do |celda, c|
      bajada = celda.al_medio ? (@altos[f] - celda.alto) / 2.0 : 0

      escribir(celda, c, arriba - relleno - bajada)
    end

    @pdf.fill_color NEGRO
    @pdf.move_cursor_to arriba - alto
  end

  private

  def medir(dato, columna, base)
    opciones = base.merge(dato.is_a?(Hash) ? dato : { content: dato })
    texto    = opciones[:content].to_s
    estilo   = opciones[:font_style] || :normal
    size     = opciones[:size]
    sangria  = opciones[:sangria].to_f
    ancho    = texto.empty? ? 0.0 : @pdf.width_of(texto, size: size, style: estilo)
    corrida  = ancho > espacio_de(columna, sangria)

    Celda.new(texto: texto, size: size, estilo: estilo, color: opciones[:text_color] || NEGRO,
              fondo: opciones[:fondo], centrada: opciones[:align] == :center, al_medio: opciones[:al_medio],
              sangria: sangria, ancho: ancho,
              alto: corrida ? alto_en_varios_renglones(texto, columna, sangria, size, estilo) : renglon(estilo, size)[:alto],
              corrida: corrida)
  end

  # Lo que le queda al texto dentro de su columna.
  def espacio_de(columna, sangria) = @anchos[columna] - (2 * @relleno_h) - sangria

  # ⚠️ `height + line_gap`, que es la misma cuenta que hace un renglón solo: sin
  # el interlineado, una fila de dos renglones quedaba dos puntos más apretada
  # que sus vecinas de uno.
  #
  # Sin `at:`, la caja mide desde el tope de la hoja. Con el cursor de ese
  # momento, un texto largo medido cerca del pie se recortaría contra el borde
  # y devolvería menos alto del que tiene.
  def alto_en_varios_renglones(texto, columna, sangria, size, estilo)
    caja = Prawn::Text::Box.new(texto, document: @pdf, width: espacio_de(columna, sangria), size: size, style: estilo)
    caja.render(dry_run: true)
    caja.height + caja.line_gap
  end

  # El alto y el ascendente de un renglón, por estilo y tamaño. Se pregunta una
  # vez: una tabla de mil filas usa tres o cuatro combinaciones.
  #
  # ⚠️ `font` con bloque devuelve la FUENTE, no lo que devuelve el bloque: las
  # medidas hay que sacarlas de adentro.
  def renglon(estilo, size)
    (@renglones ||= {})[[ estilo, size ]] ||= begin
      medidas = nil
      @pdf.font(@pdf.font.family, style: estilo, size: size) do
        medidas = { alto: @pdf.font.height, ascender: @pdf.font.ascender }
      end
      medidas
    end
  end

  def pintar(esquina, ancho, alto, color)
    @pdf.fill_color color
    @pdf.fill_rectangle esquina, ancho, alto
  end

  # `tope` es donde empieza el texto: el borde de arriba de la fila, menos el
  # relleno.
  def escribir(celda, columna, tope)
    return if celda.texto.empty?

    izquierda = @orillas[columna] + @relleno_h + celda.sangria
    @pdf.fill_color celda.color

    if celda.corrida
      @pdf.text_box celda.texto, at: [ izquierda, tope ], width: espacio_de(columna, celda.sangria),
                                 size: celda.size, style: celda.estilo, align: (celda.centrada ? :center : :left)
    else
      # ⚠️ `draw_text` y no una caja: escribe en una coordenada y nada más. Es
      # donde está toda la diferencia de velocidad — la caja arma un acomodador
      # de renglones para un texto que ya se sabe que cabe en uno.
      x = celda.centrada ? @orillas[columna] + ((@anchos[columna] - celda.ancho) / 2.0) : izquierda
      @pdf.draw_text celda.texto, at: [ x, tope - renglon(celda.estilo, celda.size)[:ascender] ],
                                  size: celda.size, style: celda.estilo
    end
  end
end
