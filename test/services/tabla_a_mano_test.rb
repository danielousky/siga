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
