require "test_helper"

# Cómo se reparte un documento entre sus hojas (`AcomodoEnHojas`).
#
# Daniel, 2 de octubre de 2026, sobre el pie del boletín: *«no se ve bien solo
# en una sola hoja; tendríamos que hacer un ajuste para que, cuando se vaya a
# sobrepasar el contenido, ajustar el alto de las líneas de modo que se vea en
# una segunda hoja pero con parte del contenido, para que no quede vacío»*.
#
# ## Por qué se prueba acá y no solo mirando PDFs
#
# Esta regla falla en LARGOS concretos. El pie se cortaba «en algunos»
# boletines porque dependía de dónde terminara la tabla, y mi primer arreglo lo
# dejó solo en una hoja en otros tantos. Un boletín de ejemplo cualquiera pasa
# en verde con el error adentro — así que acá se barren cientos de largos, que
# sin dibujar nada tardan milisegundos.
class AcomodoEnHojasTest < ActiveSupport::TestCase
  HOJA = 720.0   # una carta, con sus márgenes
  PIE  = 173.0   # lo que mide el del boletín

  # ── Lo de siempre ─────────────────────────────────────────────────────────

  test "lo que cabe en una hoja no se toca: relleno de siempre y ningún salto" do
    plan = acomodar(filas: 10)

    assert_equal 1, plan.hojas
    assert_equal AcomodoEnHojas::ESTANDAR, plan.relleno
    assert_empty plan.saltos
  end

  # ── Menos hojas ───────────────────────────────────────────────────────────

  # ⚠️ Es papel que el colegio no imprime: veintidós hojas por sección, en el
  # boletín anual de bachillerato, que es donde apareció.
  test "si apretando un poco cabe en una hoja menos, se aprieta" do
    justo = (1..80).find { |n| acomodar(filas: n).relleno < AcomodoEnHojas::ESTANDAR }
    assert justo, "en ningún largo apretó las filas: la regla no se está aplicando"
    plan = acomodar(filas: justo)

    assert_equal 1, plan.hojas, "con #{justo} filas tenía que entrar en una hoja, apretando"
    assert_equal 2, sin_ajustar(filas: justo), "y con el relleno de siempre se iba a dos"
  end

  # Entre los rellenos que ahorran la hoja, el MÁS CERCANO al de siempre: no se
  # aprieta al mínimo si con medio punto alcanza.
  test "aprieta lo justo, no todo lo que puede" do
    justo = (1..80).find { |n| acomodar(filas: n).relleno < AcomodoEnHojas::ESTANDAR }
    assert justo, "en ningún largo apretó las filas: la regla no se está aplicando"
    plan = acomodar(filas: justo)

    assert_operator plan.relleno, :>, AcomodoEnHojas::RELLENOS.min
    assert_operator acomodar_con(plan.relleno + 0.25, filas: justo).hojas, :>, plan.hojas,
                    "un cuarto de punto más de aire ya no cabía: ese era el más holgado posible"
  end

  # ── El pie no viaja solo ──────────────────────────────────────────────────

  # ⚠️ La que pidió Daniel, y la que no depende de ninguna otra: ni del relleno
  # ni de cuántas filas haya.
  #
  # ⚠️ El mínimo va ESCRITO —cien puntos— y no leído de la constante. Leyéndola,
  # quien la baje a cero ve el test pasar: estaría comparando contra sí mismo.
  # Lo comprobé rompiéndolo a propósito, y pasaba.
  test "en ningún largo el pie queda solo en su hoja" do
    solos = []
    mirados = 0

    (1..220).each do |filas|
      [ [], [ 18 ], [ 18, 45 ], [ 18, 45, 60 ], [ 45, 218 ], [ 300 ] ].each do |bloques|
        piezas = piezas_de(filas: filas, bloques: bloques)
        plan   = AcomodoEnHojas.new(piezas, libre: 560, hoja: HOJA).plan
        next if plan.hojas == 1

        mirados += 1
        con_el_pie = piezas[plan.saltos.last...-1].sum { |pieza| pieza.mide(plan.relleno) }
        solos << [ filas, bloques, con_el_pie.round ] if con_el_pie < 99
      end
    end

    assert_operator mirados, :>, 500, "casi ningún documento pasó de una hoja: el test no está probando nada"
    assert_empty solos, "el pie quedó con menos de 100 pt de compañía en: #{solos.first(5).inspect}"
  end

  # ── Las hojas llenas ──────────────────────────────────────────────────────

  # Cuando el pie se lleva parte del contenido, la hoja ANTERIOR queda con un
  # hueco. Si estirando las filas ese hueco se cierra, se estiran.
  test "si estirando las filas la hoja anterior se llena, se estiran" do
    estirados = (20..80).map { |n| [ n, acomodar(filas: n) ] }.select { |_, plan| plan.relleno > AcomodoEnHojas::ESTANDAR }

    assert estirados.any?, "en ningún largo estiró las filas: la regla no se está aplicando"
    estirados.each do |filas, plan|
      assert_operator plan.hueco, :<=, AcomodoEnHojas::HOLGURA,
                      "con #{filas} filas estiró a #{plan.relleno} y aun así dejó #{plan.hueco.round} pt en blanco"
    end
  end

  # ⚠️ Estirar una tabla de diez filas no cierra un hueco de media hoja: la deja
  # rara sin arreglar nada. Era el boletín de lapso de bachillerato mientras
  # tuvo un cuadro aparte de 218 puntos; hoy es cualquier documento corto con
  # un bloque grande al final.
  test "si no alcanza con estirar, las filas se quedan como siempre" do
    plan = AcomodoEnHojas.new(piezas_de(filas: 12, bloques: [ 45, 218 ]), libre: 560, hoja: HOJA).plan

    assert_equal 2, plan.hojas
    assert_equal AcomodoEnHojas::ESTANDAR, plan.relleno
    assert_operator plan.hueco, :>, AcomodoEnHojas::HOLGURA, "el hueco existe, y no se disimula"
  end

  # Una fila que no cabe y pasa a la hoja siguiente es lo normal de cualquier
  # tabla larga. Si contara como hueco, una tabla de doscientas filas movería el
  # relleno de todas para cerrar quince puntos al pie de cada hoja.
  #
  # ⚠️ Se mira el plan CON EL RELLENO DE SIEMPRE, no el elegido: en una tabla
  # larga, apretar suele ahorrar una hoja, y eso es otra regla. Acá lo que se
  # afirma es que hay documentos de tres hojas o más —o sea, con saltos de fila
  # seguro— cuyo hueco es cero. Si los saltos de fila contaran, no habría
  # ninguno: lo que sobra al pie de una hoja casi nunca es exactamente nada.
  test "una fila que pasa a la hoja siguiente no cuenta como hueco" do
    largos = (100..200).map { |filas| acomodar_con(AcomodoEnHojas::ESTANDAR, filas: filas) }
                       .select { |plan| plan.hojas >= 3 }

    assert largos.any?, "ninguno de estos documentos llegó a tres hojas: el test no está probando nada"
    assert largos.any? { |plan| plan.hueco.zero? },
           "todo documento de tres hojas quedó con hueco: los saltos de fila están contando"
  end

  # ── Nunca peor que antes ──────────────────────────────────────────────────

  test "en ningún largo usa más hojas que dibujando una cosa detrás de la otra" do
    peores = (1..220).select { |filas| acomodar(filas: filas).hojas > sin_ajustar(filas: filas) }

    assert_empty peores, "con estas filas el plan gasta más hojas que sin él: #{peores.first(8).inspect}"
  end

  # ── Lo que no se puede acomodar ───────────────────────────────────────────

  # Un informe de sesenta renglones mide más que una hoja. No hay dónde ponerlo
  # entero: se cuenta lo que ocupa y se sigue, sin colgarse.
  test "un bloque más alto que la hoja no lo cuelga" do
    plan = AcomodoEnHojas.new(piezas_de(filas: 20, bloques: [ 900 ]), libre: 560, hoja: HOJA).plan

    assert_operator plan.hojas, :>=, 2
  end

  test "el pie solo, sin nada más, también se acomoda" do
    plan = AcomodoEnHojas.new([ pieza(PIE) ], libre: 560, hoja: HOJA).plan

    assert_equal 1, plan.hojas
  end

  private

  def pieza(alto, **opciones) = AcomodoEnHojas::Pieza.new(alto: alto, **opciones)

  # Un documento con la forma del boletín: una tabla, sus bloques y el pie.
  # Las dos últimas filas van pegadas, como el promedio a la de arriba.
  def piezas_de(filas:, bloques: [ 18, 45, 60 ])
    tabla = Array.new(filas) do |i|
      pieza(i.zero? ? 9.5 : 8.5, fila: true, pegada: i.zero? || i == filas - 2, despues: (i == filas - 1 ? 14 : 0))
    end

    tabla + bloques.map { |alto| pieza(alto) } + [ pieza(PIE) ]
  end

  def acomodar(filas:) = AcomodoEnHojas.new(piezas_de(filas: filas), libre: 560, hoja: HOJA).plan

  def acomodar_con(relleno, filas:)
    AcomodoEnHojas.new(piezas_de(filas: filas), libre: 560, hoja: HOJA).send(:acomodar, relleno)
  end

  # Cuántas hojas saldrían SIN plan: con el relleno de siempre, una pieza detrás
  # de la otra, y cada una saltando de hoja cuando no cabe. Es lo que había.
  def sin_ajustar(filas:)
    libre = 560.0
    hojas = 1

    piezas_de(filas: filas).each do |pieza|
      alto = pieza.mide(AcomodoEnHojas::ESTANDAR)
      if alto > libre
        hojas += 1
        libre = HOJA
      end
      libre -= alto
    end

    hojas
  end
end
