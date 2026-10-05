require "test_helper"

# La tabla dibujada a mano (`TablaAMano`), que reemplazó a `prawn-table` en el
# boletín el 2 de octubre de 2026.
#
# Lo que se prueba es lo que `prawn-table` hacía mal SIN AVISAR —y por eso
# nadie lo había visto— más el contrato del que depende repartir las hojas:
#
#     que la celda mande sobre la tabla     (el tamaño de letra se pisaba)
#     que la sangría sea un número          (los espacios se recortaban)
#     que lo que dice que mide sea lo que ocupa
#
# Y lo que se le agregó el 5 de octubre para que la comparación con la sección
# se vea como un complemento: una celda rayada, el aire de una celda angosta y
# el hueco entre dos grupos de columnas.
class TablaAManoTest < ActiveSupport::TestCase
  setup do
    @pdf = Prawn::Document.new(page_size: "LETTER", margin: 36)
  end

  # ── El contrato con quien reparte las hojas ───────────────────────────────

  # ⚠️ `AcomodoEnHojas` decide dónde cae cada cosa SUMANDO lo que esta clase
  # dice que mide. Si al dibujar ocupara otra cosa —medio punto por fila— una
  # tabla de sesenta filas terminaría treinta puntos más abajo de lo planeado,
  # y el pie volvería a cortarse sin que nada falle.
  test "lo que dice que mide es exactamente lo que ocupa al dibujarse" do
    tabla = tabla_de([ [ "MATERIA", "NOTA" ], [ "Matemática", "17" ], [ largo, "PA" ], [ "PROMEDIO", "16" ] ])

    [ 2.5, 4, 7 ].each do |relleno|
      @pdf.start_new_page
      arriba = @pdf.cursor
      tabla.dibujar(relleno)

      assert_in_delta tabla.alto(relleno), arriba - @pdf.cursor, 0.001,
                      "con relleno #{relleno} la tabla dijo medir una cosa y ocupó otra"
    end
  end

  test "con más relleno cada fila crece el doble de lo que se le suma" do
    tabla = tabla_de([ [ "a", "1" ], [ "b", "2" ], [ "c", "3" ] ])

    assert_in_delta tabla.alto(4) + (3 * 2 * 1.5), tabla.alto(5.5), 0.001
  end

  # ── Lo que `prawn-table` pisaba ───────────────────────────────────────────

  # ⚠️ El error que motivó la clase. El boletín pedía 7,5 para las competencias
  # y 7 para los indicadores; `cell_style: { size: 9 }` se aplicaba DESPUÉS y
  # los dejaba todos en 9. Ocupaba una hoja más y nadie lo notó.
  test "la celda manda sobre la fila, y la fila sobre la tabla" do
    tabla_de([ [ "cabecera", "x" ],
               [ { content: "competencia", size: 7.5 }, "y" ],
               [ "materia", "z" ] ],
             estilos: { 0 => { size: 8, font_style: :bold } }).dibujar

    tamanos = textos_de(@pdf.render).to_h { |t| [ t.texto, [ t.size, t.negrita ] ] }

    assert_equal [ 8.0, true ],  tamanos["cabecera"],    "la fila manda sobre la tabla"
    assert_equal [ 7.5, false ], tamanos["competencia"], "la celda manda sobre las dos"
    assert_equal [ 9.0, false ], tamanos["materia"],     "y sin nada dicho, el tamaño de la tabla"
  end

  # ⚠️ La sangría estaba escrita con espacios al principio del texto, y Prawn
  # los recorta al acomodar un renglón: los tres niveles del boletín salían
  # alineados al mismo borde.
  test "la sangría es un número, y corre el texto esos puntos" do
    tabla_de([ [ "materia", "" ],
               [ { content: "competencia", sangria: 6 }, "" ],
               [ { content: "indicador", sangria: 16 }, "" ] ]).dibujar

    en_x = textos_de(@pdf.render).to_h { |t| [ t.texto, t.x ] }

    assert_in_delta en_x["materia"] + 6,  en_x["competencia"], 0.01
    assert_in_delta en_x["materia"] + 16, en_x["indicador"], 0.01
  end

  # ── Lo que no cabe ────────────────────────────────────────────────────────

  test "un texto que no cabe en un renglón se parte, y la fila crece con él" do
    corta = tabla_de([ [ "Una competencia", "PA" ] ])
    larga = tabla_de([ [ largo, "PA" ] ])

    assert_operator larga.altos.first, :>, corta.altos.first * 1.9, "la fila tenía que medir al menos dos renglones"

    larga.dibujar
    renglones = textos_de(@pdf.render).reject { |t| t.texto == "PA" }

    assert_operator renglones.size, :>=, 2, "el texto largo tenía que salir en varios renglones"
    assert renglones.all? { |t| t.x < 36 + 400 }, "y ninguno puede arrancar fuera de su columna"
  end

  # La red de seguridad: quien reparte las hojas ya decidió dónde saltar, pero
  # una fila no se dibuja a medias contra el borde por un cálculo ajeno.
  test "una fila que no cabe en lo que queda de hoja pasa entera a la siguiente" do
    tabla = tabla_de([ [ "arriba", "1" ], [ "abajo", "2" ] ])
    @pdf.move_cursor_to tabla.alto / 2 + 3   # cabe la primera, y no la segunda

    tabla.dibujar

    por_texto = textos_de(@pdf.render).to_h { |t| [ t.texto, t.pagina ] }
    assert_equal 1, por_texto["arriba"]
    assert_equal 2, por_texto["abajo"]
    assert_operator lo_mas_bajo_de(@pdf.render), :>=, 36, "nada se pintó por debajo del margen"
  end

  # ── Dónde cae el texto ────────────────────────────────────────────────────

  test "las columnas centradas quedan centradas, y la primera a la izquierda" do
    tabla_de([ [ "Matemática", "17" ] ]).dibujar

    materia, nota = textos_de(@pdf.render)
    ancho = @pdf.width_of("17", size: 9)

    assert_in_delta 36 + 6, materia.x, 0.01, "la primera columna arranca en el margen más su relleno"
    assert_in_delta 36 + 400 + ((140 - ancho) / 2), nota.x, 0.01, "y la segunda va al centro de la suya"
  end

  test "una celda vacía no escribe nada, pero sí lleva su fondo" do
    tabla_de([ [ "banda", { content: "", fondo: "1E4A7A" } ] ]).dibujar

    crudo = @pdf.render
    assert_equal [ "banda" ], textos_de(crudo).map(&:texto)
    assert_match(/0\.11765 0\.2902 0\.47843 scn/, crudo, "el fondo de la celda tenía que pintarse")
  end

  # ── La celda rayada ───────────────────────────────────────────────────────

  # Daniel: *«que el fondo, en vez de ser azul fuerte, sean solo líneas
  # diagonales en azul. Si se va a imprimir se gasta menos tinta»*.
  test "una celda con trama se raya en diagonal de borde a borde, y no se rellena" do
    arriba = @pdf.cursor
    tabla  = tabla_de([ [ "banda", { content: "", trama: "1E4A7A" } ] ])
    tabla.dibujar

    crudo  = @pdf.render
    tramas = tramas_de(crudo)

    assert_empty rellenos_de(crudo), "la celda rayada no lleva relleno"
    assert_equal 1, tramas.size, "y tenía que salir rayada"
    trama = tramas.first
    assert_match(/0\.11765 0\.2902 0\.47843 SCN/, crudo, "las rayas van del color pedido")
    # La celda es la segunda columna: de 400 a 540, y del alto de la fila.
    assert_in_delta 36 + 400, trama.x, 0.01
    assert_in_delta 140, trama.ancho, 0.01, "las rayas llegan de un borde al otro"
    assert_in_delta tabla.alto, trama.alto, 0.01, "y de arriba abajo"
    assert_in_delta 36 + arriba - tabla.alto, trama.y, 0.01, "sin salirse de la celda"
  end

  test "el trazo de las rayas no se le queda puesto a lo que se dibuja después" do
    tabla_de([ [ "banda", { content: "", trama: "1E4A7A" } ], [ "otra", "x" ] ]).dibujar

    assert_equal 1, @pdf.line_width, "el borde de la fila siguiente saldría de medio punto"
  end

  # ⚠️ Las rayas se cuentan desde el origen de la hoja. Contadas desde la
  # esquina de cada celda, dos celdas de anchos distintos no casan: la barra se
  # ve como retazos.
  test "dos celdas rayadas, vecinas y de anchos distintos, continúan el mismo dibujo" do
    TablaAMano.new(@pdf, [ [ "barra", { content: "", trama: "1E4A7A" }, { content: "", trama: "1E4A7A" } ] ],
                   anchos: [ 100, 37, 22 ]).dibujar

    izquierda, derecha = tramas_de(@pdf.render).sort_by(&:x)
    paso = TablaAMano::PASO_DE_LA_TRAMA

    assert_in_delta izquierda.derecha, derecha.x, 0.01, "una empieza donde termina la otra"
    (izquierda.cortes + derecha.cortes).each do |corte|
      assert_in_delta 0, (corte / paso) - (corte / paso).round, 0.001
    end
    assert_operator (izquierda.cortes & derecha.cortes).size, :>=, 2, "y comparten las rectas que cruzan el borde"
  end

  # ── El aire de una celda angosta ──────────────────────────────────────────

  # ⚠️ Con los seis puntos de aire de la tabla, a una columna de 22 le quedan
  # diez para el texto y «MEDIO» mide dieciocho: Prawn lo parte por la mitad de
  # la palabra, sin avisar.
  test "con su propio aire, una celda angosta deja entrar la palabra entera" do
    celda = { content: "MEDIO BAJO", size: 5.5 }

    TablaAMano.new(@pdf, [ [ celda ] ], anchos: [ 22 ]).dibujar
    apretada = textos_de(@pdf.render).map(&:texto)

    @pdf = Prawn::Document.new(page_size: "LETTER", margin: 36)
    TablaAMano.new(@pdf, [ [ celda.merge(aire: 1.5) ] ], anchos: [ 22 ], centradas: (0..)).dibujar
    holgada = textos_de(@pdf.render)

    assert_not_includes apretada, "MEDIO", "con el aire de la tabla la palabra se partía: #{apretada.inspect}"
    assert_equal %w[MEDIO BAJO], holgada.map(&:texto)
    assert_operator holgada.first.x, :>=, 36 + 1.5 - 0.01, "y respeta su aire: no se monta sobre el borde"
  end

  # ── El hueco entre dos grupos ─────────────────────────────────────────────

  test "un hueco no lleva borde, y el fondo de la fila se interrumpe en él" do
    TablaAMano.new(@pdf, [ [ "MATERIA", "NOTA", "", "BAJO", "ALTO" ], [ "Inglés", "16", "", "", "" ] ],
                   anchos: [ 300, 100, 8, 66, 66 ], huecos: [ 2 ], estilos: { 0 => { fondo: "F0EDE8" } }).dibujar

    crudo  = @pdf.render
    fondos = rellenos_de(crudo).sort_by(&:first)
    bordes = bordes_de(crudo)

    assert_equal [ [ 36.0, 400.0 ], [ 444.0, 132.0 ] ], fondos.map { |x, _, ancho, _| [ x, ancho ] },
                 "el fondo de la cabecera va en dos pedazos, uno por grupo"
    assert_equal 8, bordes.size, "cuatro celdas con borde por fila; la del hueco, no"
    assert bordes.none? { |x, _, ancho, _| x >= 436 - 0.01 && x + ancho <= 444 + 0.01 }, "el hueco salió con borde"
  end

  test "sin huecos, el fondo de la fila es uno solo y de lado a lado" do
    tabla_de([ [ "MATERIA", "NOTA" ] ], estilos: { 0 => { fondo: "F0EDE8" } }).dibujar

    assert_equal [ [ 36.0, 540.0 ] ], rellenos_de(@pdf.render).map { |x, _, ancho, _| [ x, ancho ] }
  end

  private

  def largo
    "Resuelve problemas de adición y sustracción con números naturales hasta de seis cifras, " \
      "estimando el resultado antes de calcular y comprobándolo después con otra estrategia"
  end

  # Dos columnas: 400 puntos para el texto, 140 para la nota.
  def tabla_de(filas, **opciones)
    TablaAMano.new(@pdf, filas, anchos: [ 400, 140 ], **opciones)
  end
end
