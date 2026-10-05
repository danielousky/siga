# Cómo se reparte un documento entre sus hojas, y con qué alto de fila.
#
# ## El problema
#
# Un boletín termina con un PIE —la firma, el código de verificación y su QR—
# que no se puede partir. Cuando no cabe debajo de la tabla salta a la hoja
# siguiente, y hasta el 2 de octubre de 2026 saltaba SOLO:
#
#     hoja 2                          hoja 3
#     ┌──────────────────────┐        ┌──────────────────────┐
#     │ … filas de la tabla  │        │ ──────────           │
#     │ leyenda · puesto     │        │ Director(a)          │
#     │ informe descriptivo  │        │ Código: BOL-…   ▓▓   │
#     │                      │        │                      │
#     │      (120 pt libres) │        │      (todo en blanco)│
#     └──────────────────────┘        └──────────────────────┘
#
# Daniel: *«no se ve bien solo en una sola hoja; tendríamos que hacer un ajuste
# para que, cuando se vaya a sobrepasar el contenido, ajustar el alto de las
# líneas de modo que se vea en una segunda hoja pero con parte del contenido,
# para que no quede vacío»*.
#
# ## Lo que hace: prueba altos de fila, y se queda con el mejor
#
# Las filas de la tabla llevan un RELLENO —el aire arriba y abajo del texto—
# que de fábrica son 4 puntos. Acá se prueban desde 2,5 hasta 7, y para cada
# uno se calcula dónde caería cada cosa. No se dibuja nada: son sumas.
#
#     1 · MENOS HOJAS     si apretando un poco cabe todo en una hoja menos,
#                         se aprieta — es papel que el colegio no imprime
#     2 · HOJAS LLENAS    si no, y el pie se lleva parte del contenido a la
#                         hoja siguiente, se estiran las filas hasta que la
#                         hoja anterior quede completa en vez de con un hueco
#     3 · LO DE SIEMPRE   entre los que cumplen, el más cercano a 4
#
# ⚠️ Si ningún relleno llena la hoja, las filas se quedan en 4. Estirar una
# tabla de diez filas no cierra un hueco de media hoja: la deja rara sin
# arreglar nada. Cuando el documento no cabe por MUCHO, lo que hay que mirar no
# es el relleno sino qué sobra — el boletín de bachillerato no entraba en una
# hoja porque repetía una tabla entera, y eso se arregló quitándola
# (`ReportCardPdf#tabla_de_lapso`), no apretando.
#
# ## ⚠️ El pie nunca viaja solo, y eso NO depende del relleno
#
# Es una regla aparte, y es la que garantiza lo que pidió Daniel: el pie se
# lleva consigo lo que tiene inmediatamente arriba, hasta juntar unos
# `ACOMPANA` puntos de contenido: las últimas filas de la tabla con su leyenda,
# el renglón de asistencia y puesto, y el informe del docente.
#
# El relleno decide cómo queda la hoja ANTERIOR. Que el pie vaya acompañado lo
# decide el pegado, y se cumple aunque la tabla tenga tres filas.
#
# ## Por qué es una clase aparte y no parte del PDF
#
# Porque así se prueba sin dibujar. Recibe alturas y devuelve un plan; no sabe
# qué es un boletín ni qué es Prawn. El test le da cien documentos de largos
# distintos en lo que tarda en dibujarse uno.
class AcomodoEnHojas
  # El relleno de siempre: el que tenían las tablas antes de que esto existiera.
  ESTANDAR = 4.0

  # De cuánto a cuánto se puede mover. Con 2,5 una fila de letra 9 mide 15 pt
  # —apretada, pero se lee—; con 7, mide 24: aireada, sin llegar a parecer una
  # lista a doble espacio.
  RELLENOS = (2.5..7.0).step(0.25).to_a.freeze

  # Los puntos de contenido que el pie se lleva consigo. Con el pie son unos
  # 270 pt: más de un tercio de la hoja, que es donde deja de verse vacía.
  ACOMPANA = 100

  # Un hueco menor que esto al pie de una hoja no se ve: es menos que una fila.
  HOLGURA = 12

  # ⚠️ El plan es más prudente que el dibujo, a propósito. Las cuentas son con
  # decimales y el cursor de Prawn también: si el plan dijera «cabe justo» y el
  # dibujo «no cabe por una milésima», la fila saltaría de hoja por su cuenta y
  # todo lo que venía detrás quedaría corrido respecto de lo planeado.
  MARGEN_DE_ERROR = 0.5

  # Una cosa que se dibuja de una vez y no se parte.
  #
  #   alto      lo que mide. En una fila, el TEXTO solo: el relleno se suma acá
  #   fila      ¿es una fila de tabla? Son las únicas que cambian con el relleno
  #   pegada    no se separa de la que sigue: una cabecera de su primera fila,
  #             una materia de su primera competencia
  #   despues   aire que deja debajo
  #   dibujar   cómo se dibuja. Esta clase no lo mira: es de quien arma las piezas
  Pieza = Struct.new(:alto, :fila, :pegada, :despues, :dibujar, keyword_init: true) do
    def initialize(alto:, fila: false, pegada: false, despues: 0, dibujar: nil) = super

    def mide(relleno) = alto + (fila ? 2 * relleno : 0) + despues
  end

  #   relleno   el que hay que usar al dibujar las filas
  #   saltos    antes de qué piezas se cambia de hoja
  #   hojas     cuántas ocupa, contando la que ya estaba empezada
  #   hueco     lo más grande que quedó en blanco al pie de una hoja por haberse
  #             llevado un bloque entero a la siguiente
  Plan = Data.define(:relleno, :saltos, :hojas, :hueco) do
    def salta_antes?(indice) = saltos.include?(indice)
  end

  # `libre` es lo que queda de la hoja donde arranca la primera pieza; `hoja`,
  # lo que mide una hoja entera.
  def initialize(piezas, libre:, hoja:)
    @piezas = piezas
    @libre = libre
    @hoja = hoja
  end

  def plan
    candidatos = RELLENOS.map { |relleno| acomodar(relleno) }
    menos      = candidatos.map(&:hojas).min
    pocas      = candidatos.select { |c| c.hojas == menos }
    llenas     = pocas.select { |c| c.hueco <= HOLGURA }

    # Entre dos igual de cerca del estándar, el que deja más aire.
    (llenas.presence || pocas).min_by { |c| [ (c.relleno - ESTANDAR).abs, -c.relleno ] }
  end

  private

  def acomodar(relleno)
    altos   = @piezas.map { |pieza| pieza.mide(relleno) }
    pegadas = con_el_pie_acompanado(altos)
    libre   = @libre
    saltos  = []
    hojas   = 1
    hueco   = 0.0
    desde   = 0

    while desde < altos.size
      hasta = fin_del_grupo(desde, pegadas, altos)
      grupo = altos[desde..hasta].sum

      if grupo > libre - MARGEN_DE_ERROR && libre < @hoja
        hueco = [ hueco, libre ].max if forzado?(desde, hasta)
        saltos << desde
        hojas += 1
        libre = @hoja
      end

      libre -= grupo
      # Una pieza más alta que la hoja —un informe de sesenta renglones— se
      # derrama en las siguientes. No se puede planificar: se cuenta y se sigue.
      while libre.negative?
        libre += @hoja
        hojas += 1
      end

      desde = hasta + 1
    end

    Plan.new(relleno: relleno, saltos: saltos, hojas: hojas, hueco: hueco)
  end

  # ⚠️ La regla que hace que el pie no viaje solo.
  #
  # Se recorre de abajo hacia arriba desde el pie, pegando cada pieza a la que
  # le sigue, hasta juntar `ACOMPANA` puntos. Lo que quede pegado se mueve
  # junto: o cabe todo en la hoja, o se va todo a la siguiente.
  def con_el_pie_acompanado(altos)
    pegadas = @piezas.map(&:pegada)
    juntos  = 0.0

    (altos.size - 2).downto(0) do |indice|
      break if juntos >= ACOMPANA

      pegadas[indice] = true
      juntos += altos[indice]
    end

    pegadas
  end

  # Hasta dónde llega lo que no se separa de la pieza `desde`.
  #
  # ⚠️ Un grupo más alto que una hoja entera no se puede mantener junto: no hay
  # dónde ponerlo. Se suelta la primera pieza y el resto lo vuelve a intentar en
  # la vuelta siguiente — así el pie conserva toda la compañía que sí quepa.
  def fin_del_grupo(desde, pegadas, altos)
    hasta = desde
    hasta += 1 while pegadas[hasta] && hasta < altos.size - 1

    altos[desde..hasta].sum > @hoja - MARGEN_DE_ERROR ? desde : hasta
  end

  # ⚠️ Solo cuenta como hueco el que deja un BLOQUE al irse entero.
  #
  # Una fila que no cabe y pasa a la hoja siguiente es lo normal de cualquier
  # tabla larga, y lo mismo una materia que se lleva a su primera competencia.
  # Contándolos, el plan movería el relleno de todas las filas para cerrar
  # veinte puntos al pie de una hoja — cambiar el documento entero por algo que
  # nadie ve.
  def forzado?(desde, hasta) = (desde..hasta).any? { |indice| !@piezas[indice].fila }
end
