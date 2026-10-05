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
#
# ## Una celda RAYADA en vez de rellena (`trama:`)
#
# Daniel, 5 de octubre de 2026, mirando la barra del boletín de bachillerato:
# *«que el fondo, en vez de ser azul fuerte, sean solo líneas diagonales en
# azul. Si se va a imprimir se gasta menos tinta y me dice la misma
# información»*. Una celda rellena es tinta en toda su superficie; rayada, en
# menos de la quinta parte.
#
# ## Y un HUECO entre dos grupos de columnas (`huecos:`)
#
# Una columna que no lleva borde ni fondo: la tabla sigue siendo una —las filas
# coinciden y se reparten juntas entre las hojas— pero se lee como dos, una al
# lado de la otra.
class TablaAMano
  NEGRO = "000000".freeze

  # Cada cuánto va una raya de la trama, y lo que mide. Se cuentan sobre el
  # borde de la celda: entre raya y raya quedan 2,8 puntos, y medio de tinta.
  PASO_DE_LA_TRAMA  = 4.0
  TRAZO_DE_LA_TRAMA = 0.5

  # Lo que se guarda de cada celda después de medirla. `corrida` dice si el
  # texto no cupo en un renglón: esas —las menos— sí pasan por una caja de
  # texto, que es la que sabe partir palabras. `espacio` es lo que le queda al
  # texto dentro de su columna.
  Celda = Struct.new(:texto, :size, :estilo, :color, :fondo, :trama, :centrada, :al_medio, :sangria, :aire,
                     :espacio, :ancho, :alto, :corrida, keyword_init: true)

  # El alto del TEXTO de cada fila, sin relleno: lo que `AcomodoEnHojas`
  # necesita para probar rellenos sin volver a medir nada.
  attr_reader :altos

  # `filas` es una lista de listas. Cada celda es un texto, o un Hash con
  # `content:` y lo que quiera cambiar: `size:`, `font_style:`, `text_color:`,
  # `fondo:`, `trama:`, `align:`, `sangria:`, `aire:`, `al_medio:`.
  #
  # `trama` es un color, como `fondo`, pero la celda sale rayada en diagonal y
  # no rellena. `aire` es el relleno a los LADOS de esa celda, cuando no es el
  # de la tabla: una columna angosta con el aire de siempre no deja sitio para
  # el texto.
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
  #
  # `huecos` son las columnas que separan un grupo de otro: no llevan borde, y
  # el fondo de una fila se interrumpe en ellas. Su celda va vacía.
  def initialize(pdf, filas, anchos:, size: 9, relleno: [ 4, 6 ], borde: "DDDDDD", centradas: (1..), estilos: {},
                 huecos: [])
    @pdf = pdf
    @anchos = anchos
    @relleno_v, @relleno_h = relleno
    @borde = borde
    @huecos = huecos
    @orillas = anchos.each_with_object([ 0.0 ]) { |ancho, xs| xs << xs.last + ancho }
    @tramos  = tramos_entre_huecos

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

    @tramos.each { |desde, hasta| pintar([ desde, arriba ], hasta - desde, alto, @fondos[f]) } if @fondos[f]
    celdas.each_with_index do |celda, c|
      pintar([ @orillas[c], arriba ], @anchos[c], alto, celda.fondo) if celda.fondo
      rayar([ @orillas[c], arriba ], @anchos[c], alto, celda.trama) if celda.trama
    end

    if @borde
      @pdf.stroke_color @borde
      celdas.each_index { |c| @pdf.stroke_rectangle [ @orillas[c], arriba ], @anchos[c], alto unless @huecos.include?(c) }
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
    aire     = (opciones[:aire] || @relleno_h).to_f
    espacio  = @anchos[columna] - (2 * aire) - sangria
    ancho    = texto.empty? ? 0.0 : @pdf.width_of(texto, size: size, style: estilo)
    corrida  = ancho > espacio

    Celda.new(texto: texto, size: size, estilo: estilo, color: opciones[:text_color] || NEGRO,
              fondo: opciones[:fondo], trama: opciones[:trama], centrada: opciones[:align] == :center,
              al_medio: opciones[:al_medio], sangria: sangria, aire: aire, espacio: espacio, ancho: ancho,
              alto: corrida ? alto_en_varios_renglones(texto, espacio, size, estilo) : renglon(estilo, size)[:alto],
              corrida: corrida)
  end

  # Los grupos de columnas seguidas, como `[desde, hasta]` en puntos. Sin
  # huecos es uno solo: la tabla entera.
  def tramos_entre_huecos
    (0...@anchos.size).chunk_while { |a, b| !@huecos.include?(a) && !@huecos.include?(b) }
                      .reject { |columnas| @huecos.include?(columnas.first) }
                      .map { |columnas| [ @orillas[columnas.first], @orillas[columnas.last + 1] ] }
  end

  # ⚠️ `height + line_gap`, que es la misma cuenta que hace un renglón solo: sin
  # el interlineado, una fila de dos renglones quedaba dos puntos más apretada
  # que sus vecinas de uno.
  #
  # Sin `at:`, la caja mide desde el tope de la hoja. Con el cursor de ese
  # momento, un texto largo medido cerca del pie se recortaría contra el borde
  # y devolvería menos alto del que tiene.
  def alto_en_varios_renglones(texto, espacio, size, estilo)
    caja = Prawn::Text::Box.new(texto, document: @pdf, width: espacio, size: size, style: estilo)
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

  # La celda rayada en diagonal, de abajo a la izquierda hacia arriba a la
  # derecha.
  #
  # Las rayas son las rectas `y = x + c`, con `c` en múltiplos del paso contados
  # desde el ORIGEN DE LA HOJA y no desde la esquina de la celda. Por eso dos
  # celdas vecinas —o dos filas— continúan el mismo dibujo en vez de arrancar
  # cada una el suyo: una barra de cuatro bandas se lee como una barra.
  #
  # ⚠️ De cada recta se dibuja solo el pedazo que cae DENTRO de la celda, y se
  # calcula: entra por el borde izquierdo o por el de abajo —el que encuentre
  # más tarde— y sale por el derecho o por el de arriba —el que encuentre
  # antes—. Recortar con `clip` daría lo mismo en pantalla, pero deja las
  # rectas enteras en el archivo: más peso, y nada que un test pueda medir.
  def rayar(esquina, ancho, alto, color)
    izquierda, tope = esquina
    derecha = izquierda + ancho
    fondo   = tope - alto
    grosor  = @pdf.line_width

    @pdf.stroke_color color
    @pdf.line_width = TRAZO_DE_LA_TRAMA
    @pdf.stroke do
      primera = ((fondo - derecha) / PASO_DE_LA_TRAMA).floor + 1
      ultima  = ((tope - izquierda) / PASO_DE_LA_TRAMA).ceil - 1

      (primera..ultima).each do |n|
        c     = n * PASO_DE_LA_TRAMA
        desde = [ izquierda, fondo - c ].max
        hasta = [ derecha, tope - c ].min
        next if hasta - desde < 0.5   # un punto en la esquina no es una raya

        @pdf.line [ desde, desde + c ], [ hasta, hasta + c ]
      end
    end
    @pdf.line_width = grosor
  end

  # `tope` es donde empieza el texto: el borde de arriba de la fila, menos el
  # relleno.
  def escribir(celda, columna, tope)
    return if celda.texto.empty?

    izquierda = @orillas[columna] + celda.aire + celda.sangria
    @pdf.fill_color celda.color

    if celda.corrida
      @pdf.text_box celda.texto, at: [ izquierda, tope ], width: celda.espacio,
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
