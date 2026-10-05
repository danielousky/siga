require "test_helper"

# Cómo queda repartido un boletín en sus hojas.
#
# Son tres reclamos de Daniel sobre el mismo PDF, en cinco días:
#
#     1 de octubre   «se está cortando el foot de algunos documentos»
#     2 de octubre   «no se ve bien solo en una sola hoja… ajustar el alto de
#                    las líneas de modo que se vea en una segunda hoja pero con
#                    parte del contenido, para que no quede vacío»
#     5 de octubre   «en Media lo que falta para que entre el cuadro comparativo
#                    es poco… eso ahorraría papel a la hora de imprimir»
#
# El segundo lo provoqué yo arreglando el primero: mandé el pie entero a la
# hoja siguiente cuando no cabía, y quedó solo — la firma y el código arriba de
# una hoja en blanco, en los boletines de primaria con plan y en TODOS los de
# bachillerato.
#
# ## ⚠️ Por qué se barre el largo, y no se prueba «un boletín»
#
# Las dos primeras fallas dependen de dónde termina la tabla. Con un boletín de
# ejemplo cualquiera, el test pasa en verde con el error adentro: es como
# estuvieron las dos hasta que alguien abrió el PDF de una sección concreta.
class BoletinEnSusHojasTest < ActiveSupport::TestCase
  INFORME = "Trabaja con constancia y termina lo que empieza. Le cuesta pedir ayuda cuando no entiende: hay que " \
            "animarla a preguntar en el momento y no al final de la clase.".freeze

  ASISTENCIA = { "dias" => 10, "presentes" => 8, "ausentes" => 2, "tardes" => 0, "desde" => "2025-09-15",
                 "hasta" => "2025-12-20", "del_lapso" => true }.freeze
  PUESTO     = { "puesto" => 2, "de" => 22, "empatado" => true }.freeze

  setup do
    @esc = escenario_academico(nivel: :primaria, alumnos: 1)
    @base = con_el_colegio(@esc.colegio) do
      @esc.colegio.restablecer_la_rubrica!
      ReportCardData.para(enrollment: @esc.inscripcion, evaluation_moment: @esc.lapso(1))
    end
    @boletin = con_el_colegio(@esc.colegio) do
      ReportCard.new(enrollment: @esc.inscripcion, evaluation_moment: @esc.lapso(1), code: "BOL-ABCD-1234")
    end
    # ⚠️ UNO solo para todo el test: el pie se mide dibujándolo una vez por
    # dibujante, y los barridos emiten cientos de boletines del mismo colegio.
    @dibujante = ReportCardPdf.new([ @boletin ])
  end

  # ── Los dos primeros reclamos, en todos los largos ────────────────────────

  test "en ningún largo se corta el pie, ni queda solo en su hoja" do
    con_un_qr_de_juguete do
      cortados, solos, vacias = [], [], []

      largos.each do |nombre, datos|
        hojas = hojas_de(boletin_con(datos))

        cortados << nombre if hojas.map(&:abajo).min < ReportCardPdf::MARGEN - 1
        solos    << nombre if hojas.any? { |hoja| hoja.empieza.start_with?("Escala del 1 al 20") }
        # Y que lo acompañe ALGO de verdad: la hoja del pie, llena al menos en
        # un tercio. Con el pie solo eran 173 puntos de 720.
        vacias   << "#{nombre} (#{hojas.last.ocupado.round} pt)" if hojas.size > 1 && hojas.last.ocupado < 240
      end

      assert_empty cortados, "algo se pintó por debajo del margen en: #{cortados.first(6).inspect}"
      assert_empty solos,    "el pie quedó solo arriba de una hoja en: #{solos.first(6).inspect}"
      assert_empty vacias,   "la hoja del pie quedó casi vacía en: #{vacias.first(6).inspect}"
    end
  end

  # ⚠️ Un indicador suelto arriba de una hoja —«– Trabaja en equipo con sus
  # compañeros»— no dice de qué competencia es ni de qué materia. Y una materia
  # al pie de una hoja con su competencia en la siguiente se lee como una
  # materia sin nada adentro.
  #
  # Una hoja empieza por una materia, o por la segunda competencia de una: las
  # dos se entienden solas.
  test "una hoja arranca por una materia o por una competencia, nunca por un indicador suelto" do
    con_un_qr_de_juguete do
      sueltos, partidas = [], []

      ((4..22).map { |n| [ n, 1 ] } + (4..12).map { |n| [ n, 2 ] }).each do |cuantas, competencias|
        siguientes = hojas_de(boletin_con("materias" => con_plan(cuantas, competencias: competencias))).drop(1)

        sueltos  << [ cuantas, competencias ] if siguientes.any? { |hoja| hoja.empieza.start_with?("–") }
        # Con UNA competencia por materia, arrancar por ella es haberla
        # separado de su materia.
        partidas << cuantas if competencias == 1 && siguientes.any? { |hoja| hoja.empieza.start_with?("•") }
      end

      assert_empty sueltos,  "una hoja arrancó por un indicador con [materias, competencias]: #{sueltos.inspect}"
      assert_empty partidas, "una hoja arrancó por la única competencia de una materia con: #{partidas.inspect}"
    end
  end

  # ── Lo que mide el pie ────────────────────────────────────────────────────

  # ⚠️ El 1 de octubre lo sumé a mano y me dio 180 cuando mide 173. Esos siete
  # puntos mandaron a una segunda hoja el pie de todos los boletines anuales de
  # bachillerato, que cabían en una. Corto, se corta; largo, salta sin motivo.
  test "el pie mide lo que ocupa: ni un punto menos, ni uno más" do
    crudo = boletin_con({})

    escala = textos_de(crudo).find { |t| t.texto.start_with?("Escala del 1 al 20") }
    # El pie arranca seis puntos más arriba del tope de su primer renglón, y el
    # tope de un renglón está un ascendente por encima de donde se escribe.
    dibujado = (escala.y + ascendente_de(escala.size) + 6) - lo_mas_bajo_de(crudo)

    assert_in_delta dibujado, @dibujante.send(:alto_del_pie, @base, @boletin), 0.5
  end

  # ── Lo que `prawn-table` pisaba ───────────────────────────────────────────

  # ⚠️ El boletín pedía letra 7,5 para las competencias y 7 para los
  # indicadores, y salían todos a 9: la librería aplicaba el tamaño de la tabla
  # DESPUÉS del de cada celda. Y la sangría, escrita con espacios, se recortaba.
  # Un boletín de primaria ocupaba una hoja más de las que se diseñaron.
  test "las competencias y los indicadores salen con su tamaño y su sangría" do
    textos = textos_de(boletin_con("materias" => con_plan(1)))

    materia     = textos.find { |t| t.texto == "Materia 1" }
    competencia = textos.find { |t| t.texto.start_with?("• Alcanza") }
    indicador   = textos.find { |t| t.texto.start_with?("– Indicador") }

    assert_equal [ 9.0, 7.5, 7.0 ], [ materia, competencia, indicador ].map(&:size)
    assert_operator competencia.x, :>, materia.x, "la competencia va sangrada bajo su materia"
    assert_operator indicador.x, :>, competencia.x, "y el indicador, bajo su competencia"
  end

  test "la cabecera y el promedio van en negrita; las materias, no" do
    textos = textos_de(boletin_con("materias" => sin_plan(3))).to_h { |t| [ t.texto, t.negrita ] }

    assert textos["MATERIA"], "la cabecera va en negrita"
    assert textos["PROMEDIO DEL LAPSO"], "el promedio también"
    assert_not textos["Materia 2"]
  end

  # ── Bachillerato: una tabla, una hoja ─────────────────────────────────────
  #
  # Daniel, 5 de octubre: *«en Media lo que falta para que entre el cuadro
  # comparativo es poco»*. No era poco —el boletín medía 840 puntos en una hoja
  # de 720— pero lo que sobraba era una tabla entera: «situación con respecto a
  # la sección» repetía cada materia con su nota para agregarle dos columnas.

  test "en bachillerato las notas y la comparación van en UNA tabla, y caben en una hoja" do
    [ 10, 12, 14 ].each do |cuantas|
      crudo  = boletin_con(de_bachillerato(cuantas))
      textos = textos_de(crudo).map(&:texto)

      assert_equal 1, hojas_de(crudo).size, "con #{cuantas} materias tenía que caber en una hoja"
      assert_equal 1, textos.count("Materia 3"), "cada materia sale UNA vez: antes salía en las dos tablas"
      assert_includes textos, "LA SECCIÓN", "el promedio de la sección es una columna más de la tabla de notas"
      assert_not_includes textos, "SITUACIÓN GENERAL", "y el promedio del lapso es la fila que cierra las dos cosas"
    end
  end

  # Daniel, 5 de octubre: *«la sección dice 14.2, 14.1. Eso es un promedio, no
  # es la sección»*. El número estaba bien; el rótulo, no — «SECCIÓN» en la
  # cabecera de un boletín es «A» o «B».
  test "la columna del promedio de la sección se llama así, no «SECCIÓN» a secas" do
    textos = textos_de(boletin_con(de_bachillerato(6)))
    rotulo = textos.select { |t| [ "PROMEDIO DE", "LA SECCIÓN" ].include?(t.texto) }

    assert_equal [ "PROMEDIO DE", "LA SECCIÓN" ], rotulo.map(&:texto), "el rótulo va entero, en dos renglones"
    assert rotulo.all?(&:negrita), "y en negrita, como el resto de la cabecera"
    assert_not_includes textos.map(&:texto), "SECCIÓN"
  end

  # ⚠️ Con el complemento angosto, a la materia le sobra sitio — hasta que
  # alguien vuelva a ensanchar las bandas. Con «Materia 3» no se nota; hay que
  # probarlo con el nombre más largo del pensum.
  test "el nombre de materia más largo del pensum cabe en un renglón, al lado de la comparación" do
    largo = "Grupo de Creación, Recreación y Producción"
    datos = de_bachillerato(10)
    datos["materias"][4]["materia"] = largo
    datos["comparacion"]["materias"][4]["materia"] = largo

    textos = textos_de(boletin_con(datos)).map(&:texto)

    assert_equal 1, textos.count(largo), "se partió en dos renglones: #{textos.grep(/Grupo|Producción/).inspect}"
  end

  # ── La comparación es un complemento ──────────────────────────────────────
  #
  # Daniel, 5 de octubre, con el boletín ya en una hoja: *«ese grupo, esa
  # parte, es un complemento; no es la calificación como tal»*. Pidió tres
  # cosas: las bandas lo más delgadas posible, rayadas en vez de rellenas —*«si
  # se va a imprimir se gasta menos tinta y me dice la misma información»*— y
  # separadas de las notas.

  # La barra son celdas rayadas: las bandas hasta el nivel del alumno,
  # INCLUSIVE. Un alumno en el nivel 0 —«muy bajo»— lleva una banda, no cero.
  test "la barra raya una banda por cada nivel, hasta el del alumno inclusive" do
    datos = de_bachillerato(6)   # niveles 0, 1, 2, 3, 4 y 5 → 1 + 2 + … + 6 bandas, más 4 del general

    assert_equal (1..6).sum + 4, bandas_rayadas_de(boletin_con(datos)).size
  end

  test "las bandas van rayadas, no rellenas: de tinta, menos de la cuarta parte" do
    crudo = boletin_con(de_bachillerato(6))

    macizas = rellenos_de(crudo).select { |_, _, ancho, _| (ancho - ReportCardPdf::ANCHO_DE_BANDA).abs < 0.01 }
    assert_empty macizas, "quedó una banda rellena"

    bandas_rayadas_de(crudo).each do |banda|
      tinta = banda.largo * TablaAMano::TRAZO_DE_LA_TRAMA / (banda.ancho * banda.alto)

      assert_operator tinta, :<, 0.25, "una banda rayada gasta #{(tinta * 100).round} % de lo que gastaba rellena"
      assert_operator tinta, :>, 0.10, "y tampoco tan poco que no se vea en el papel"
    end
  end

  # ⚠️ Las rayas se cuentan desde el origen de la hoja, no desde la esquina de
  # cada celda: así cuatro bandas seguidas son UNA barra y no cuatro dibujos
  # que no casan entre sí.
  test "las bandas vecinas continúan el mismo rayado" do
    paso = TablaAMano::PASO_DE_LA_TRAMA

    bandas_rayadas_de(boletin_con(de_bachillerato(6))).flat_map(&:cortes).each do |corte|
      assert_in_delta 0, (corte / paso) - (corte / paso).round, 0.001, "una raya arrancó fuera de la cuadrícula"
    end
  end

  test "la comparación va separada de las notas, y es la parte angosta" do
    crudo = boletin_con(de_bachillerato(6))

    # La cabecera es lo primero que se pinta de la tabla: un fondo por grupo.
    notas, complemento = rellenos_de(crudo).select { |_, y, _, _| y == rellenos_de(crudo).map { |r| r[1] }.max }
                                           .sort_by(&:first)

    assert complemento, "la cabecera tenía que salir en dos pedazos, y salió en uno"
    assert_in_delta ReportCardPdf::HUECO_DE_LA_COMPARACION, complemento[0] - (notas[0] + notas[2]), 0.01,
                    "entre las notas y su complemento va un hueco"
    assert_in_delta 6 * ReportCardPdf::ANCHO_DE_BANDA, complemento[2], 0.01
    assert_operator complemento[2], :<, 0.3 * (notas[2] + complemento[2]),
                    "el complemento ocupaba el 41 % del ancho; ahora, menos de la tercera parte"

    # Y por el hueco no pasa ningún borde: son dos grupos, no una celda vacía.
    desde = notas[0] + notas[2]
    en_el_hueco = bordes_de(crudo).select { |x, _, ancho, _| x >= desde - 0.01 && x + ancho <= complemento[0] + 0.01 }
    assert_empty en_el_hueco, "el hueco salió con borde"
  end

  # ⚠️ «MEDIO» es la palabra más ancha de los seis rótulos. Si la banda se
  # angosta más de la cuenta, Prawn la parte por la mitad —«MEDI / O»— y no
  # avisa.
  test "los rótulos de las bandas no se parten por la mitad de una palabra" do
    textos = textos_de(boletin_con(de_bachillerato(6))).map(&:texto)

    assert_equal 2, textos.count("MEDIO"), "«MEDIO BAJO» y «MEDIO ALTO», cada uno con su palabra entera"
    assert_equal 2, textos.count("MUY")
    assert_equal 3, textos.count("BAJO"), "«MUY BAJO», «BAJO» y «MEDIO BAJO»"
    assert_equal 3, textos.count("ALTO")
  end

  # ⚠️ Una materia sin nota, o con un solo alumno calificado en la sección, no
  # tiene contra qué compararse. Una barra vacía diría «muy bajo»; un cero en
  # el promedio, que la sección sacó cero.
  test "una materia sin con qué compararla lleva una raya y ninguna banda" do
    datos = de_bachillerato(6)
    datos["comparacion"]["materias"].delete_at(5)   # la del nivel más alto: 6 bandas menos

    crudo = boletin_con(datos)

    assert_equal (1..5).sum + 4, bandas_rayadas_de(crudo).size
    assert_equal 1, textos_de(crudo).count { |t| t.texto == "—" }
    assert_includes textos_de(crudo).map(&:texto), "Materia 6", "la materia sigue saliendo, con su nota"
  end

  # ── Los renglones que se juntaron ─────────────────────────────────────────

  # Daniel: *«si pasamos unos elementos a una sola línea ganaríamos 2 líneas»*.
  test "los datos del alumno van en un solo renglón" do
    rotulos = textos_de(boletin_con({})).select { |t| %w[Alumno Grado Sección Carnet].include?(t.texto) }

    assert_equal 4, rotulos.size
    assert_equal 1, rotulos.map(&:y).uniq.size, "los cuatro rótulos comparten renglón"
    assert rotulos.all?(&:negrita)
  end

  test "la asistencia y el puesto van en un solo renglón, cada rótulo delante de su dato" do
    textos = textos_de(boletin_con("asistencia" => ASISTENCIA, "puesto" => PUESTO))

    faltas  = textos.find { |t| t.texto.start_with?("INASISTENCIAS") }
    cuantas = textos.find { |t| t.texto == "2 de 10 días de clase" }
    lugar   = textos.find { |t| t.texto.start_with?("PUESTO EN LA SECCIÓN") }
    cual    = textos.find { |t| t.texto == "2º de 22 (empatado)" }

    assert_equal 1, [ faltas, cuantas, lugar, cual ].map(&:y).uniq.size, "los dos datos comparten renglón"
    assert_operator faltas.x, :<, cuantas.x
    assert_operator cuantas.x, :<, lugar.x
    assert_operator lugar.x, :<, cual.x
  end

  # ── El membrete ───────────────────────────────────────────────────────────

  # ⚠️ El nombre del colegio arrancaba DEBAJO del escudo y no a su lado: 42
  # puntos en blanco en cada boletín de un colegio con escudo. Era la tercera
  # parte de lo que le sobraba al de bachillerato para caber en una hoja.
  test "el escudo no empuja el membrete hacia abajo, ni lo corre de costado" do
    sin_escudo = textos_de(boletin_con({})).find { |t| t.texto == @base.dig("colegio", "nombre").upcase }

    con_el_colegio(@esc.colegio) do
      @esc.colegio.logo.attach(io: File.open(Rails.root.join("app/assets/images/escudo_vzla.png")),
                               filename: "escudo.png", content_type: "image/png")
    end
    crudo      = con_el_colegio(@esc.colegio) { ReportCardPdf.new([ @boletin ]).render }
    con_escudo = textos_de(crudo).find { |t| t.texto == @base.dig("colegio", "nombre").upcase }

    assert_operator crudo.bytesize, :>, 50_000, "el escudo no se dibujó: el test no está probando nada"
    assert_in_delta sin_escudo.y, con_escudo.y, 0.01, "con escudo el membrete arranca a la misma altura"
    assert_in_delta sin_escudo.x, con_escudo.x, 0.01, "y sigue centrado en la hoja, no en lo que queda al lado"
  end

  # ── El boletín del año ────────────────────────────────────────────────────

  # ⚠️ «Sin nota» necesita 45 puntos y su columna medía 44: se partía en dos
  # renglones en la reparación de todo alumno que no reparó —casi todos—, y
  # cada fila del boletín anual medía el doble.
  test "en el boletín anual «Sin nota» cabe en un renglón" do
    crudo = boletin_con("tipo" => "anual", "lapso" => nil, "lapsos" => [ "1er Lapso", "2do Lapso", "3er Lapso" ],
                        "materias" => Array.new(10) do |i|
                          { "materia" => "Materia #{i + 1}", "lapsos" => [ 18, 16, nil ], "anual" => 17,
                            "reparacion" => nil, "definitiva" => 17 }
                        end)
    textos = textos_de(crudo).map(&:texto)

    assert_includes textos, "Sin nota"
    assert_not_includes textos, "Sin", "«Sin nota» se partió en dos renglones"
    assert_includes textos, "2do Lapso", "y la cabecera más larga tampoco se parte"
    assert_equal 1, hojas_de(crudo).size, "diez materias del año caben en una hoja"
  end

  # ── Una sección entera ────────────────────────────────────────────────────

  test "en el PDF de una sección cada alumno arranca en hoja nueva, y con su propio reparto" do
    con_un_qr_de_juguete do
      # Tres alumnos con boletines de largos distintos: el reparto de uno no
      # puede arrastrarse al siguiente.
      boletines = [ con_plan(3), sin_plan(8), con_plan(12) ].each_with_index.map do |materias, i|
        ReportCard.new(enrollment: @esc.inscripcion, evaluation_moment: @esc.lapso(1), code: "BOL-AAAA-000#{i}",
                       snapshot: @base.merge("materias" => materias, "informe" => INFORME))
      end

      crudo  = con_el_colegio(@esc.colegio) { ReportCardPdf.new(boletines).render }
      hojas  = hojas_de(crudo)
      nombre = @base.dig("colegio", "nombre").upcase

      assert_equal 3, hojas.count { |hoja| hoja.empieza == nombre }, "cada boletín arranca por su membrete"
      assert hojas.none? { |hoja| hoja.empieza.start_with?("Escala del 1 al 20") }
      assert_operator hojas.map(&:abajo).min, :>=, ReportCardPdf::MARGEN - 1
    end
  end

  private

  # Las celdas rayadas que miden lo que una banda.
  def bandas_rayadas_de(crudo)
    tramas_de(crudo).select { |trama| (trama.ancho - ReportCardPdf::ANCHO_DE_BANDA).abs < 0.01 }
  end

  # ⚠️ El valor se saca de ADENTRO del bloque: `font_size` con bloque devuelve
  # el tamaño que había antes, no lo que el bloque calcula. Tomándolo de afuera,
  # el «ascendente» eran 12 puntos —el tamaño por defecto— y la cuenta daba 180.
  def ascendente_de(size)
    hoja = Prawn::Document.new
    ascendente = nil
    hoja.font_size(size) { ascendente = hoja.font.ascender }
    ascendente
  end

  def sin_plan(cuantas)
    Array.new(cuantas) { |i| { "materia" => "Materia #{i + 1}", "nota" => 15, "nivel_de_rubrica" => "PA" } }
  end

  # Cada materia con sus competencias, y cada una con tres indicadores: con
  # una sola competencia son cinco filas por materia.
  def con_plan(cuantas, competencias: 1)
    sin_plan(cuantas).each_with_index.map do |materia, i|
      materia.merge("competencias" => Array.new(competencias) do |c|
        { "texto" => "Alcanza el objetivo #{c + 1} de la materia #{i + 1}", "nivel_de_rubrica" => "PA",
          "indicadores" => Array.new(3) { |k| { "texto" => "Indicador #{k + 1}", "nivel_de_rubrica" => "PA" } } }
      end)
    end
  end

  # Un boletín de lapso de bachillerato: sin rúbrica, y con cada materia
  # comparada contra su sección. Los niveles van rotando de 0 a 5.
  def de_bachillerato(cuantas)
    materias = Array.new(cuantas) { |i| { "materia" => "Materia #{i + 1}", "nota" => 15 } }

    { "materias" => materias, "rubrica" => nil, "informe" => nil, "asistencia" => ASISTENCIA, "puesto" => PUESTO,
      "comparacion" => {
        "niveles"  => ReportCardData::ETIQUETAS_DE_NIVEL,
        "materias" => materias.each_with_index.map { |m, i| { "materia" => m["materia"], "nota" => 15, "seccion" => 14.1, "nivel" => i % 6 } },
        "general"  => { "nota" => 15, "seccion" => 14.1, "nivel" => 3 }
      } }
  end

  # De una fila a ciento veinte. Primaria con y sin plan, y bachillerato; con
  # el informe del docente y, cada tres largos, también sin él.
  def largos
    primaria = (1..60).map { |n| [ "#{n} materias", { "materias" => sin_plan(n) } ] } +
               (1..24).map { |n| [ "#{n} materias con plan", { "materias" => con_plan(n) } ] }

    primaria.map { |nombre, datos| [ "#{nombre}, con informe", datos.merge("informe" => INFORME) ] } +
      primaria.each_slice(3).map(&:first) +
      (4..30).map { |n| [ "bachillerato, #{n} materias", de_bachillerato(n) ] }
  end

  # El boletín de siempre con lo que se le cambie al snapshot.
  def boletin_con(cambios)
    @boletin.snapshot = @base.merge("informe" => nil).merge(cambios)

    con_el_colegio(@esc.colegio) { @dibujante.render }
  end

  # ⚠️ Generar un QR de verdad son quince milisegundos, y estos tests dibujan
  # cientos de boletines para mirar DÓNDE cae cada cosa, no qué dice el código.
  # Se usa uno chico y siempre el mismo: ocupa en la hoja lo que ocupa
  # cualquiera —el lado es fijo— y se dibuja con el código de verdad.
  def con_un_qr_de_juguete
    uno      = RQRCodeCore::QRCode.new("x", level: :m)
    original = RQRCodeCore::QRCode.method(:new)
    RQRCodeCore::QRCode.define_singleton_method(:new) { |*| uno }

    yield
  ensure
    RQRCodeCore::QRCode.define_singleton_method(:new, original)
  end
end
