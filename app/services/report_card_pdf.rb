# El boletín en papel.
#
# Prawn dibuja el PDF en Ruby puro, sin ningún binario del sistema. Se eligió por
# eso: `wicked_pdf` y `pdfkit` dependen de `wkhtmltopdf`, que sus propios autores
# archivaron, y `grover` necesita Node y Chromium. Y sobre todo, **el entorno de
# despliegue todavía no está decidido** — atarlo a un binario sería tomar esa
# decisión de costado.
#
# Recibe `ReportCard` ya guardados y dibuja un boletín por cada uno —en las
# hojas que le hagan falta— desde su `snapshot`, nunca desde la base. Así el
# papel, el archivo y la verificación pública dicen exactamente lo mismo.
#
# ## Tres piezas, y qué hace cada una
#
#     ReportCardPdf     qué lleva el boletín y cómo se ve cada bloque
#     TablaAMano        dibuja una tabla fila por fila, con el alto que le pidan
#     AcomodoEnHojas    decide dónde cae cada cosa: ni el pie cortado, ni solo
#
# Ver MOR-98.
class ReportCardPdf
  MARGEN = 36

  # ⚠️ Limitación conocida, y la razón de `texto` más abajo.
  #
  # Las fuentes que Prawn trae de fábrica cubren Windows-1252: todo el español
  # —á é í ó ú ü ñ y sus mayúsculas—, más portugués, italiano, francés y alemán.
  # Lo que NO cubren es cirílico, árabe, chino o el este de Europa (ș, ğ, ł).
  #
  # Con un nombre así, Prawn LEVANTA UNA EXCEPCIÓN al dibujar. En un documento
  # oficial eso es inaceptable: el boletín de un alumno no se puede caer por cómo
  # se escribe su apellido. Así que lo que no se puede representar se translitera
  # a su equivalente más cercano, y lo que sí —el 99,9 % de los casos— se imprime
  # tal cual.
  #
  # La solución completa es embeber una TTF con cobertura Unicode (DejaVu Sans,
  # ~750 KB en el repo). Vale la pena el día que un colegio real lo necesite; no
  # antes, y no sin decidirlo a propósito.
  def self.representable?(cadena)
    cadena.encode("Windows-1252")
    true
  rescue Encoding::UndefinedConversionError, Encoding::ConverterNotFoundError
    false
  end

  def initialize(report_cards)
    @boletines = Array(report_cards)
  end

  def render
    # Lo que se midió para un PDF no sirve para el siguiente: ver `alto_en_borrador`.
    @borrador = nil

    documento = Prawn::Document.new(page_size: "LETTER", margin: MARGEN, info: {
      Title: "Boletín de calificaciones", Creator: "SIGA", CreationDate: Time.current
    })

    @boletines.each_with_index do |boletin, i|
      documento.start_new_page if i.positive?
      pagina(documento, boletin)
    end

    documento.render
  end

  # QUÉ va en la tabla del boletín anual, separado de CÓMO se dibuja.
  #
  # Es público para poder probarlo sin dibujar nada: qué dice cada celda es una
  # regla del dominio; dónde se dibuja es tipografía.
  #
  # ⚠️ Aquí decía que «el texto de un PDF de Prawn no se puede leer desde
  # afuera», y no era cierto: con las fuentes de fábrica va en hexadecimal y
  # sin comprimir, y `LeePdf` (en `test/support`) lo lee. Esta costura se queda
  # porque es la manera más barata de probar la regla — pero lo que SALE
  # IMPRESO se prueba leyendo el PDF, que es donde se partía «Sin nota».
  def self.filas_anuales(datos)
    escala = datos.dig("seccion", "escala")

    filas = [["MATERIA"] + datos["lapsos"].map { |l| abreviar(l) } + %w[ANUAL REPAR. DEFINIT.]]

    datos["materias"].each do |m|
      filas << [texto(m["materia"])] + m["lapsos"].map { |n| celda(n) } +
               [celda_del_ano(m["anual"], escala), celda(m["reparacion"]),
                celda_del_ano(m["definitiva"], escala)]
    end

    filas << ["PROMEDIO GENERAL"] + Array.new(datos["lapsos"].size + 2, "") +
             [celda_del_ano(datos["promedio"], escala)]
  end

  # ── Qué dice cada celda ──────────────────────────────────────────────────
  # Funciones puras: no dependen del estado de la instancia. Viven en la clase
  # para que `filas_anuales` se pueda probar sin construir un PDF.

  def self.celda(valor)
    valor.presence&.to_s || "Sin nota"
  end

  # La calificación del año, escrita como corresponda a la escala del grado:
  # "19" en media general, "A (19)" en primaria.
  #
  # La escala sale del SNAPSHOT, nunca de la base. Un boletín de diciembre sigue
  # diciendo lo de diciembre aunque el colegio cambie la escala en marzo.
  def self.celda_del_ano(valor, escala)
    return "Sin nota" if valor.blank?

    EscalaLiteral.mostrar(valor, escala: escala)
  end

  # Deja pasar tal cual lo que la fuente puede dibujar, y translitera solo lo que
  # no. Un "José" se imprime "José"; un "Ștefan" se imprime "Stefan" en vez de
  # tirar abajo el boletín. Ver el comentario de `representable?`.
  def self.texto(valor)
    cadena = valor.to_s
    representable?(cadena) ? cadena : ActiveSupport::Inflector.transliterate(cadena)
  end

  def self.abreviar(nombre)
    texto(nombre).sub(/^Primer/, "1er").sub(/^Segundo/, "2do").sub(/^Tercer/, "3er")
                 .sub(/ Lapso$/, " Lapso").sub(/ Semestre$/, " Sem.")
  end

  private

  # El escudo, la firma y el sello del colegio, una sola vez por PDF.
  #
  # Emitir la sección entera son treinta boletines del MISMO colegio: sin
  # guardarlas serían treinta descargas del mismo archivo desde Active Storage.
  #
  # ⚠️ Eran una descarga por alumno para la firma y otra para el sello: solo el
  # escudo estaba guardado. No se veía en los datos de demostración porque ese
  # colegio no tiene firma cargada — uno de verdad sí la tiene.
  #
  # Una imagen que no se puede leer no puede tumbar un boletín: da `nil`, y
  # quien la iba a dibujar deja el hueco.
  def imagen_del_colegio(boletin, cual)
    escuela = boletin.enrollment.section.grade.school

    (@imagenes ||= {}).fetch([ escuela.id, cual ]) do |clave|
      @imagenes[clave] = escuela.public_send("#{cual}_para_pdf")
    end
  rescue StandardError
    nil
  end

  def logo_del_colegio(boletin) = imagen_del_colegio(boletin, :logo)

  # ── Un boletín, en las hojas que hagan falta ─────────────────────────────
  #
  # El membrete y los datos del alumno van siempre arriba. Todo lo demás se
  # arma como PIEZAS —cada fila de la tabla, cada bloque de abajo, el pie— y
  # antes de dibujar la primera se decide dónde cae cada una y con qué alto de
  # fila (`AcomodoEnHojas`).
  #
  #     membrete · alumno          ← se dibujan, y ahí se sabe cuánto queda
  #     ─────────────────
  #     fila · fila · fila …       ← piezas que se estiran o se aprietan
  #     leyenda o nota             ┐
  #     asistencia y puesto        │ bloques: miden lo que miden
  #     informe descriptivo        ┘
  #     pie                        ← no se parte, y no viaja solo
  #
  # ⚠️ Hasta el 2 de octubre de 2026 esto era «dibujar una cosa detrás de la
  # otra y que Prawn salte de hoja cuando no quepa». Funcionaba hasta el pie,
  # que no se puede partir: o se cortaba contra el borde, o saltaba solo a una
  # hoja en blanco. Daniel: *«no se ve bien solo en una sola hoja»*.
  def pagina(pdf, boletin)
    datos = boletin.snapshot

    encabezado(pdf, datos, boletin)
    identificacion(pdf, datos)

    piezas = piezas_de(pdf, datos, boletin)
    plan   = AcomodoEnHojas.new(piezas, libre: pdf.cursor, hoja: pdf.bounds.height).plan

    piezas.each_with_index do |pieza, indice|
      pdf.start_new_page if plan.salta_antes?(indice)
      pieza.dibujar.call(pdf, plan.relleno)
    end
  end

  # El aire entre la tabla y lo que venga debajo.
  AIRE_TRAS_LA_TABLA = 14

  def piezas_de(pdf, datos, boletin)
    anual = datos["tipo"] == "anual"
    tabla, pegadas = anual ? tabla_anual(pdf, datos) : tabla_de_lapso(pdf, datos)

    # Lo que explica la tabla de lapso —los códigos de la rúbrica, o cómo se lee
    # la comparación con la sección—. El anual no lleva ninguna de las dos.
    al_pie  = anual ? nil : bloque { |lienzo| al_pie_de_la_tabla(lienzo, datos) }
    bloques = [
      al_pie,
      bloque { |lienzo| asistencia_y_puesto(lienzo, datos) },
      bloque { |lienzo| informe_descriptivo(lienzo, datos) }
    ].compact

    filas_de(tabla, pegadas, aire: aire_tras_la_tabla(datos), sigue_la_leyenda: al_pie.present?) +
      bloques + [ pieza_del_pie(datos, boletin) ]
  end

  # La nota de la comparación va pegada a su tabla: la explica renglón por
  # renglón, y con el aire de siempre parecía de otra cosa.
  def aire_tras_la_tabla(datos) = datos["comparacion"].present? ? 6 : AIRE_TRAS_LA_TABLA

  # Cada fila de la tabla, como una pieza que se puede dibujar con el relleno
  # que el plan decida.
  #
  # ⚠️ La última no se separa de la leyenda, si la hay: una leyenda sola al tope
  # de una hoja explica los códigos de una tabla que quedó en la anterior.
  def filas_de(tabla, pegadas, aire:, sigue_la_leyenda:)
    ultima = tabla.filas - 1

    tabla.altos.each_with_index.map do |alto, fila|
      AcomodoEnHojas::Pieza.new(
        alto: alto, fila: true,
        pegada: fila == ultima ? sigue_la_leyenda : pegadas[fila],
        despues: fila == ultima ? aire : 0,
        dibujar: lambda do |lienzo, relleno|
          tabla.dibujar_fila(fila, relleno)
          lienzo.move_down aire if fila == ultima
        end
      )
    end
  end

  # Un bloque de los de abajo, con su alto ya medido. `nil` si no dibuja nada:
  # un boletín sin informe no tiene una pieza de cero puntos, no la tiene.
  def bloque(&dibujo)
    alto = alto_en_borrador(&dibujo)
    return nil unless alto.positive?

    AcomodoEnHojas::Pieza.new(alto: alto, dibujar: ->(lienzo, _relleno) { dibujo.call(lienzo) })
  end

  def pieza_del_pie(datos, boletin)
    AcomodoEnHojas::Pieza.new(alto: alto_del_pie(datos, boletin),
                              dibujar: ->(lienzo, _relleno) { pie(lienzo, datos, boletin) })
  end

  # Cuánto mide un bloque, DIBUJÁNDOLO en un documento que no se entrega.
  #
  # ⚠️ Se dibuja y se mira, en vez de calcularlo aparte. La otra manera es
  # escribir al lado de cada bloque un gemelo que sume sus alturas —«10 de aire,
  # más el título, más 3, más el párrafo»— y son dos cuentas del mismo número:
  # el día que alguien le cambie un margen al bloque, el gemelo sigue diciendo
  # el alto viejo y el plan reparte las hojas con un dato que ya no es cierto.
  # Nada falla; el pie vuelve a quedar solo.
  #
  # Cuesta dibujar cada bloque dos veces, y son los livianos: un renglón, un
  # párrafo, un cuadro de diez filas.
  #
  # Si el bloque se derrama a otra hoja —un informe de sesenta renglones— mide
  # más que una entera. La cuenta deja de ser exacta y no importa: el plan lo
  # trata como algo que no se puede acomodar, y lo deja correr.
  def alto_en_borrador
    lienzo = borrador
    lienzo.move_cursor_to lienzo.bounds.top
    hojas = lienzo.page_count

    yield lienzo

    ((lienzo.page_count - hojas) * lienzo.bounds.height) + (lienzo.bounds.top - lienzo.cursor)
  end

  # Mismo papel y mismo margen que el de verdad: un bloque mide distinto en una
  # hoja más angosta.
  def borrador = @borrador ||= Prawn::Document.new(page_size: "LETTER", margin: MARGEN)

  # El escudo del colegio, a la izquierda, con el membrete centrado AL LADO.
  #
  # ⚠️ El logo se lee de la BASE, no del snapshot, y es la única cosa del boletín
  # que no se congela. Todo lo demás —las notas, el grado, la escala— es lo que
  # el papel dijo el día que se emitió, y no puede cambiar. El escudo es
  # IDENTIDAD: si el colegio lo rediseña, un boletín reemitido lleva el nuevo, y
  # eso es lo correcto. Congelarlo dejaría el escudo viejo en un documento que el
  # colegio está entregando hoy.
  #
  # ⚠️ El membrete arranca en `arriba` —la altura de ANTES de dibujar el
  # escudo—, y el escudo va en un `float` para no mover el cursor. Hasta el 5
  # de octubre de 2026 el nombre del colegio arrancaba DEBAJO del escudo y no a
  # su lado: una caja de Prawn deja el cursor en su borde inferior, así que
  # cada boletín de un colegio con escudo llevaba 42 puntos en blanco a la
  # derecha del logo. Apareció midiendo por qué el boletín de bachillerato no
  # cabía en una hoja — era la tercera parte de lo que sobraba.
  #
  # ⚠️ Y el texto va en una columna que deja libre el ancho del escudo A LOS DOS
  # LADOS: así sigue centrado en la hoja —no «en lo que queda a la derecha del
  # logo», que es como se ve un membrete torcido— y un nombre largo se parte en
  # dos renglones en vez de escribirse encima del escudo.
  ANCHO_DEL_ESCUDO = 60
  ALTO_DEL_ESCUDO  = 46

  def encabezado(pdf, datos, boletin = nil)
    colegio = datos["colegio"]
    escudo  = boletin && logo_del_colegio(boletin)
    arriba  = pdf.cursor

    if escudo
      pdf.float do
        pdf.bounding_box([ 0, arriba + 4 ], width: ANCHO_DEL_ESCUDO, height: ALTO_DEL_ESCUDO) do
          pdf.image escudo, fit: [ ANCHO_DEL_ESCUDO - 4, ALTO_DEL_ESCUDO - 2 ], position: :left, vposition: :top
        rescue StandardError
          nil   # Un escudo que no se puede dibujar no puede tirar abajo el boletín.
        end
      end
    end

    margen = escudo ? ANCHO_DEL_ESCUDO + 10 : 0
    pdf.bounding_box([ margen, arriba ], width: pdf.bounds.width - (2 * margen)) do
      pdf.text texto(colegio["nombre"]).upcase, size: 15, style: :bold, align: :center
      pdf.text "#{texto(colegio['ubicacion'])}  ·  Código DEA #{texto(colegio['dea'])}",
               size: 8, align: :center, color: "666666"
      pdf.move_down 12

      titulo = datos["tipo"] == "anual" ? "BOLETÍN ANUAL DE CALIFICACIONES" : "BOLETÍN DE CALIFICACIONES"
      pdf.text titulo, size: 12, style: :bold, align: :center
      subtitulo = [ texto(datos["lapso"]), "Año escolar #{texto(datos['seccion']['periodo'])}" ].compact_blank.join("  ·  ")
      pdf.text subtitulo, size: 9, align: :center, color: "666666"
    end
    pdf.move_down 14
  end

  # Los datos del alumno, en UN renglón.
  #
  # Daniel, 5 de octubre de 2026, con el boletín de bachillerato en dos hojas:
  # *«si pasamos unos elementos a una sola línea ganaríamos 2 líneas»*. Eran
  # dos renglones —Alumno y Carnet arriba, Grado y Sección abajo— para cuatro
  # datos que caben de sobra en el ancho de la hoja.
  #
  # ⚠️ Anchos FIJOS, y el nombre se queda con lo que sobre. `prawn-table` los
  # repartía según el largo de cada nombre, así que «Carnet» caía en un sitio
  # distinto en el boletín de cada alumno.
  def identificacion(pdf, datos)
    alumno  = datos["alumno"]
    seccion = datos["seccion"]
    rotulo  = ->(nombre) { { content: nombre, font_style: :bold } }

    TablaAMano.new(pdf,
                   [ [ rotulo["Alumno"], texto(alumno["nombre"]), rotulo["Grado"], texto(seccion["grado"]),
                       rotulo["Sección"], texto(seccion["seccion"]), rotulo["Carnet"], texto(alumno["carnet"]) ] ],
                   # rótulo y dato de: alumno · grado · sección · carnet. La sección
                   # admite hasta ocho caracteres («MAÑANA»), no solo «A».
                   anchos: repartir_sobrante([ 42, nil, 36, 56, 44, 40, 38, 64 ], pdf.bounds.width),
                   relleno: [ 2, 4 ], borde: nil, centradas: nil).dibujar

    pdf.move_down 10
  end

  # ⚠️ La columna de la derecha lleva el NIVEL cuando el colegio definió su
  # rúbrica, y el número cuando no (MOR-136).
  #
  # Los dos, no uno: *«la niña sacó 19, por eso tiene PC»* —Cyndi—. La familia
  # lee el nivel; el número queda al lado porque es lo que el docente cargó y lo
  # que el colegio tiene que poder verificar. Esconderlo obligaría a pedir el
  # boletín para saber de dónde salió la letra.
  #
  # Devuelve la tabla SIN dibujar y, al lado, qué filas no se separan de la que
  # les sigue. Quien reparte las hojas necesita las dos cosas.
  #
  # ## Y la comparación con la sección va EN ESTA TABLA, no en otra
  #
  # Daniel, 5 de octubre de 2026: *«en Media lo que falta para que entre el
  # cuadro comparativo es poco… eso ahorraría papel a la hora de imprimir las
  # boletas, además que se vería mejor»*. No era poco: el boletín de lapso de
  # bachillerato medía 840 puntos en una hoja de 720, y con doce materias, 898.
  #
  # Lo que sobraba era una tabla entera. «Situación con respecto a la sección»
  # repetía cada materia con su nota —las dos primeras columnas de la tabla de
  # arriba— para agregarle el promedio de la sección y la barra:
  #
  #     DOS TABLAS                           UNA
  #     ──────────                           ───
  #     MATERIA            CALIFICACIÓN      MATERIA     CALIF.  PROMEDIO DE   ▓▓▓▓▓░
  #     Matemática              13                               LA SECCIÓN
  #     …                                    Matemática    13       13,7       ▓▓▓░░░
  #                                          …
  #     SITUACIÓN CON RESPECTO A LA SECCIÓN  PROMEDIO      16       14,1       ▓▓▓▓░░
  #     MATERIA     ALUMNO  SECCIÓN  ▓▓▓▓▓░
  #     Matemática    13     13,7    ▓▓▓░░░   ← la misma materia, la misma nota
  #     …
  #
  # Es la pieza que Daniel señaló del boletín de la U.E. Centro Educativo APUCV,
  # y contesta la pregunta que una familia hace de verdad: no *«¿cuánto sacó?»*
  # sino *«¿cómo le fue comparado con sus compañeros?»*. Sigue contestándola, en
  # el mismo renglón donde está la nota.
  #
  # ## La comparación es un COMPLEMENTO, y se tiene que ver como tal
  #
  # Daniel, el mismo día, con el boletín ya en una hoja: *«ese grupo, esa parte,
  # es un complemento; no es la calificación como tal»*. Las seis bandas
  # ocupaban el 41 % del ancho, pintadas de azul macizo: eran lo primero que
  # veía el ojo, por encima de la nota.
  #
  #     NOTAS                                          ┆  COMPLEMENTO
  #     MATERIA       CALIFICACIÓN   PROMEDIO DE       ┆  MUY  BAJO MEDIO MEDIO ALTO MUY
  #                                  LA SECCIÓN        ┆  BAJO      BAJO  ALTO       ALTO
  #     Matemática         13           13,7           ┆  //// //// ////
  #
  # Tres cosas, las tres pedidas por él:
  #
  # 1. **Las bandas, lo más angostas que da su rótulo.** «MEDIO» a letra 5,5
  #    mide 18 puntos: la banda mide 22 y no los 37 que tenía.
  # 2. **Rayadas, no rellenas** (`trama:`): *«si se va a imprimir se gasta menos
  #    tinta y me dice la misma información»*. Menos de la quinta parte.
  # 3. **Separadas de las notas** por un hueco: la tabla sigue siendo una —las
  #    filas coinciden— pero se lee como dos, y la de la derecha es la chica.
  #
  # ## «SECCIÓN» no: «PROMEDIO DE LA SECCIÓN»
  #
  # Daniel: *«la sección dice 14.2, 14.1. Eso es un promedio, no es la
  # sección»*. El número estaba bien —310 puntos entre 22 alumnos— y el rótulo
  # no: «SECCIÓN» en la cabecera de un boletín es «A» o «B».
  #
  # ## La barra se dibuja con CELDAS, no con coordenadas
  #
  # Una barra «de verdad» —un rectángulo sobre la tabla— obliga a calcular la
  # posición de cada fila después de dibujarla, y eso se rompe en cuanto una
  # materia de nombre largo ocupa dos renglones. Seis celdas por fila, rayadas
  # hasta el nivel que corresponde, dan el mismo resultado y coinciden con el
  # original impreso, que lleva las líneas de las bandas cruzando la barra.
  #
  # ## Sin color semántico
  #
  # Un solo tono de marca. Estar por debajo del promedio de la clase **no es
  # reprobar** —se puede estar debajo del promedio con 17— y pintarlo de rojo
  # sería un juicio que el colegio no emitió. Lo que informa es la POSICIÓN.
  COLOR_DE_LA_BARRA = "1E4A7A".freeze

  # ⚠️ 22 puntos: lo que ocupa «MEDIO» a letra 5,5 —18— más punto y medio de
  # aire a cada lado y uno de holgura. Más angosta, la palabra se parte por la
  # mitad; más chica la letra, ya no se lee en un papel impreso.
  ANCHO_DE_BANDA  = 22
  LETRA_DE_BANDA  = 5.5
  AIRE_DE_BANDA   = 1.5

  # Lo que separa las notas de su complemento, y dónde cae: detrás de la
  # materia, la calificación y el promedio de la sección.
  HUECO_DE_LA_COMPARACION = 8
  COLUMNA_DEL_HUECO       = 3

  # «PROMEDIO DE» a letra 8 en negrita mide 57 puntos, y lleva 6 de aire a
  # cada lado.
  ANCHO_DEL_PROMEDIO_DE_LA_SECCION = 70

  def tabla_de_lapso(pdf, datos)
    con_rubrica = datos["rubrica"].present?
    comparacion = datos["comparacion"]
    niveles     = comparacion ? comparacion["niveles"] : []
    # Por NOMBRE, que es como el snapshot enlaza las dos listas: la comparación
    # deja afuera a la materia sin nota o sin promedio de la sección.
    comparadas  = comparacion ? comparacion["materias"].index_by { |fila| fila["materia"] } : {}

    filas   = [ [ "MATERIA", con_rubrica ? "NIVEL" : "CALIFICACIÓN" ] + cabecera_de_la_comparacion(comparacion) ]
    # La cabecera no se queda sola al pie de una hoja.
    pegadas = [ true ]

    datos["materias"].each do |materia|
      del_plan = filas_de_competencias(materia, con_rubrica)

      filas   << [ texto(materia["materia"]), celda_de_lapso(materia, con_rubrica) ] +
                 celdas_de_la_comparacion(comparacion, comparadas[materia["materia"]])
      # Ni una materia al pie de una hoja con sus competencias en la siguiente.
      pegadas << del_plan.any?

      del_plan.each do |fila, pegada|
        # Una competencia no se compara con la sección: sus columnas van vacías
        # —el promedio, el hueco y las bandas—.
        filas   << fila + Array.new(comparacion ? niveles.size + 2 : 0, "")
        pegadas << pegada
      end
    end

    # Ni el promedio solo al tope de una hoja: se lleva la fila de arriba.
    pegadas[-1] = true
    filas   << [ "PROMEDIO DEL LAPSO", celda(datos["promedio"]) ] +
               celdas_de_la_comparacion(comparacion, comparacion&.dig("general"))
    pegadas << false

    return [ tabla_de_notas(pdf, filas, [ nil, 110 ]), pegadas ] if comparacion.nil?

    anchos = [ nil, 70, ANCHO_DEL_PROMEDIO_DE_LA_SECCION, HUECO_DE_LA_COMPARACION ] +
             Array.new(niveles.size, ANCHO_DE_BANDA)

    [ tabla_de_notas(pdf, filas, anchos, huecos: [ COLUMNA_DEL_HUECO ]), pegadas ]
  end

  # El promedio de la sección, el hueco y los nombres de las seis bandas — o
  # nada, si no hay con qué comparar.
  def cabecera_de_la_comparacion(comparacion)
    return [] if comparacion.nil?

    [ "PROMEDIO DE LA SECCIÓN", "" ] + comparacion["niveles"].map do |nivel|
      { content: texto(nivel).upcase, size: LETRA_DE_BANDA, aire: AIRE_DE_BANDA }
    end
  end

  # El promedio de la sección, el hueco y la barra de UNA fila: las bandas
  # rayadas hasta el nivel del alumno, inclusive.
  #
  # ⚠️ Una materia que la comparación dejó afuera —sin nota, o con un solo
  # alumno calificado en la sección— lleva una raya y ninguna banda. No un cero
  # ni una barra vacía «muy baja»: no hay con qué compararla, y eso se dice.
  def celdas_de_la_comparacion(comparacion, fila)
    return [] if comparacion.nil?

    cuantas = comparacion["niveles"].size
    return [ coma(nil), "" ] + Array.new(cuantas, "") if fila.nil?

    [ coma(fila["seccion"]), "" ] +
      Array.new(cuantas) { |banda| fila["nivel"] && banda <= fila["nivel"] ? { content: "", trama: COLOR_DE_LA_BARRA } : "" }
  end

  def celda_de_lapso(materia, con_rubrica)
    return celda(materia["nota"]) unless con_rubrica && materia["nivel_de_rubrica"].present?

    # El nivel manda y el número lo respalda: «PC (19)».
    "#{materia['nivel_de_rubrica']} (#{materia['nota']})"
  end

  # Cuánto entra cada nivel respecto del borde de la celda, en puntos.
  SANGRIA_DE_COMPETENCIA = 6
  SANGRIA_DE_INDICADOR   = 16

  # Las competencias e indicadores, sangrados bajo su materia (MOR-136).
  #
  # ⚠️ Es para lo ÚNICO que existen las competencias. Daniel: *«las competencias
  # terminan siendo solo para mostrarlas en la boleta junto con los indicadores
  # y la rúbrica»*.
  #
  # ⚠️ Una competencia sin nivel dice «Sin evaluar», en letras. Nunca «NP» y
  # nunca cero: `NP` es reprobado —*«el docente está obligado a evaluar»*— y
  # esto es que todavía no le tomaron nada.
  #
  # ⚠️ Y cada INDICADOR lleva el suyo (`MOR-136`, segunda mitad). Un indicador
  # lo mide una sola evaluación, así que su nivel es el de esa nota: una
  # lectura, no un promedio inventado. Salen solo los que se midieron.
  #
  # ⚠️ `PlanEvaluado.indicadores_de` y no `competencia["indicadores"]` a secas:
  # los boletines emitidos ANTES de esto los guardaron como una lista de textos,
  # y leerlos como hashes dejaría en blanco la boleta de diciembre.
  #
  # ⚠️ La sangría es un NÚMERO, no espacios al principio del texto. Con espacios
  # —como estuvo— Prawn los recorta al acomodar el renglón y los tres niveles
  # salían alineados al mismo borde: la jerarquía se leía solo por el color.
  #
  # Devuelve pares `[fila, pegada]`: una competencia no se separa de NINGUNO de
  # sus indicadores.
  #
  # ⚠️ De ninguno, y no solo del primero. Pegando solo el primero, una hoja
  # podía arrancar por «– Trabaja en equipo con sus compañeros»: un indicador
  # suelto, sin la competencia a la que pertenece ni la materia. Así una hoja
  # empieza por una materia o por una competencia, que se entienden solas.
  def filas_de_competencias(materia, con_rubrica)
    Array(materia["competencias"]).flat_map do |competencia|
      nivel       = con_rubrica ? (competencia["nivel_de_rubrica"] || "Sin evaluar") : ""
      indicadores = PlanEvaluado.indicadores_de(competencia)

      fila = [ { content: "• #{texto(competencia['texto'])}", size: 7.5, text_color: "555555",
                 sangria: SANGRIA_DE_COMPETENCIA },
               { content: nivel.to_s, size: 7.5, text_color: "555555" } ]

      [ [ fila, indicadores.any? ] ] + indicadores.each_with_index.map do |indicador, indice|
        suyo = con_rubrica ? indicador["nivel_de_rubrica"].to_s : ""

        [ [ { content: "– #{texto(indicador['texto'])}", size: 7, text_color: "888888",
              sangria: SANGRIA_DE_INDICADOR },
            { content: suyo, size: 7, text_color: "888888" } ], indice < indicadores.size - 1 ]
      end
    end
  end

  # La leyenda de la rúbrica, al pie de la tabla.
  #
  # ⚠️ Sale del SNAPSHOT y no de la base: si el colegio cambia la rúbrica en
  # marzo, el boletín de diciembre tiene que seguir explicando la de entonces.
  def leyenda_de_la_rubrica(pdf, rubrica)
    return if rubrica.blank?

    pdf.move_down 4
    pdf.text rubrica.map { |r| "#{r['codigo']} #{r['nombre'].downcase}" }.join("  ·  "),
             size: 7, color: "666666"
    # Lo que sigue es el renglón de asistencia y puesto, que ya no trae su
    # propio aire arriba: sin esto quedaba pegado a la leyenda, como si fuera
    # su continuación.
    pdf.move_down 8
  end

  # Cómo se lee la comparación con la sección, al pie de la tabla que la trae.
  #
  # ⚠️ Arranca por el NOMBRE de lo que explica. Mientras fue un cuadro aparte
  # tenía su título; fundido con las notas, el nombre vive acá — sin él, las
  # seis columnas de bandas no dicen de qué son.
  def nota_de_la_comparacion(pdf, comparacion)
    return if comparacion.nil?

    pdf.font_size(6.5) do
      pdf.fill_color "666666"
      pdf.text "<b>Situación con respecto a la sección.</b> El promedio de la sección es el de cada materia, " \
               "con las notas cargadas al emitir este boletín. La barra indica cuánto se aparta el alumno de " \
               "ese promedio: cada banda son dos puntos, y el corte entre MEDIO BAJO y MEDIO ALTO es el " \
               "promedio mismo. Estar por debajo del promedio de la clase no significa aplazar.",
               align: :justify, inline_format: true
      pdf.fill_color "000000"
    end
    pdf.move_down 10
  end

  # Lo que explica la tabla de lapso, pegado debajo de ella.
  def al_pie_de_la_tabla(pdf, datos)
    leyenda_de_la_rubrica(pdf, datos["rubrica"])
    nota_de_la_comparacion(pdf, datos["comparacion"])
  end

  # Las notas de LAPSO van en número o en NIVEL; las del AÑO llevan el literal
  # cuando el grado se califica así (MOR-129).
  #
  # No es una inconsistencia: *"los literales son la nota final del año escolar"*
  # —Cyndi—. El lapso lleva la rúbrica del colegio (`MOR-136`), que es otro
  # vocabulario sobre la misma escala; el año lleva el literal A–E.
  #
  # La reparación también queda en número: es el resultado de UN examen, no la
  # calificación del año. La definitiva —que es `max(anual, reparación)`— sí.
  def tabla_anual(pdf, datos)
    escala = datos.dig("seccion", "escala")

    # Las columnas del año necesitan más aire: "A (19)" no entra donde entraba
    # "19".
    #
    # ⚠️ Las de lapso miden 54 y la de reparación 46, y no los 44 que tenían:
    # «Sin nota» necesita 45 y «2do Lapso», 52 justos. Por UN punto, «Sin nota»
    # se partía en dos renglones —«Sin / nota»— en la columna de reparación de
    # todo alumno que no reparó, que son casi todos: cada fila del boletín
    # anual medía el doble de lo necesario, y un boletín de doce materias se
    # iba a una segunda hoja por eso.
    ancho_del_ano = escala.to_s == "literal" ? 60 : 52
    anchos = [ nil ] + Array.new(datos["lapsos"].size, 54) + [ ancho_del_ano, 46, ancho_del_ano ]
    filas  = self.class.filas_anuales(datos)

    # La cabecera no se queda sola al pie de una hoja, ni el promedio al tope de
    # la siguiente.
    pegadas = Array.new(filas.size, false)
    pegadas[0] = true
    pegadas[-2] = true

    [ tabla_de_notas(pdf, filas, anchos), pegadas ]
  end

  # El informe descriptivo del docente, al final (MOR-216).
  #
  # ⚠️ Va DESPUÉS de las notas y antes del pie, que es donde lo trae la boleta
  # real del Teresiano: primero cuánto sacó, después cómo le fue. Al revés, la
  # familia lee la opinión antes que el dato que la sostiene.
  def informe_descriptivo(pdf, datos)
    cuerpo = datos["informe"]
    return if cuerpo.blank?

    pdf.move_down 10
    pdf.text "INFORME DESCRIPTIVO", size: 8, style: :bold, color: "444444"
    pdf.move_down 3
    # `text` respeta los saltos de línea del original: la maestra escribió
    # párrafos y el papel tiene que mostrarlos como párrafos.
    pdf.text texto(cuerpo), size: 9, leading: 2, align: :justify
  end

  # Inasistencias del lapso y puesto en la sección (MOR-135), en UN renglón.
  #
  # Daniel, 5 de octubre de 2026: *«si pasamos unos elementos a una sola línea
  # ganaríamos 2 líneas»*. Iba el rótulo arriba y el dato abajo, como una cifra
  # de tablero; en un papel que tiene que caber en una hoja, el rótulo va
  # delante del dato y listo.
  #
  # El empate comparte puesto y **se dice**: "10º de 20 (empatado)". Dos alumnos
  # con el mismo promedio están los dos décimos; darle el 10 a uno y el 11 al
  # otro por el orden alfabético inventa una diferencia que no existe — y se
  # imprime en un papel que la familia guarda.
  def asistencia_y_puesto(pdf, datos)
    asistencia = datos["asistencia"]
    puesto     = datos["puesto"]
    return if asistencia.nil? && puesto.nil?

    pares = []

    if asistencia
      pares << [ "INASISTENCIAS",
                 "#{asistencia['ausentes']} de #{asistencia['dias']} #{pluralizar(asistencia['dias'], 'día', 'días')} de clase" ]
      pares << [ "LLEGADAS TARDE", asistencia["tardes"].to_s ] if asistencia["tardes"].to_i.positive?
    end

    if puesto
      pares << [ "PUESTO EN LA SECCIÓN",
                 "#{puesto['puesto']}º de #{puesto['de']}#{' (empatado)' if puesto['empatado']}" ]
    end

    # El rótulo chico y gris, el dato en negro a su lado: se lee de corrido y
    # el ojo igual encuentra primero el número.
    renglon = pares.each_with_index.flat_map do |(rotulo, valor), indice|
      [ ({ text: "     ·     ", size: 10, color: "BBBBBB" } if indice.positive?),
        { text: "#{rotulo}   ", size: 6, styles: [ :bold ], color: "878787" },
        { text: valor, size: 10 } ]
    end.compact

    pdf.formatted_text renglon, align: :center
    pdf.move_down 3

    # De qué período habla ese número. Sin esto, "3 inasistencias" en el boletín
    # del segundo lapso podría querer decir tres en el lapso o tres en el año.
    if asistencia
      pdf.font_size(6.5) do
        pdf.fill_color "878787"
        pdf.text(if asistencia["del_lapso"]
                   "Contadas entre el #{fecha(asistencia['desde'])} y el #{fecha(asistencia['hasta'])}, " \
                   "que es el período de este lapso."
                 else
                   "Contadas en el año escolar completo: este lapso todavía no tiene sus fechas cargadas."
                 end, align: :center)
        pdf.fill_color "000000"
      end
    end
    pdf.move_down 12
  end

  def fecha(iso)
    I18n.l(Date.parse(iso), format: :long)
  rescue StandardError
    iso
  end

  def pluralizar(cantidad, singular, plural) = cantidad == 1 ? singular : plural

  # Coma decimal: acá 13.5 se escribe 13,5.
  def coma(valor)
    return "—" if valor.nil?

    format("%.1f", valor).tr(".", ",")
  end

  # Cómo se ven las dos tablas de notas —la del lapso y la del año—: la
  # cabecera y el total en negrita, con su fondo.
  #
  # Devuelve la tabla sin dibujar: quien reparte las hojas decide con qué alto
  # de fila va, y eso se sabe después de medirla.
  def tabla_de_notas(pdf, filas, anchos, huecos: [])
    TablaAMano.new(pdf, filas, anchos: repartir_sobrante(anchos, pdf.bounds.width), huecos: huecos,
                   estilos: { 0 => { font_style: :bold, fondo: "F0EDE8", size: 8, al_medio: true },
                              -1 => { font_style: :bold, fondo: "F5F3F0" } })
  end

  # Las columnas en `nil` se reparten lo que queda. Si no hay ninguna, se
  # devuelve la lista tal cual: quien fijó todos los anchos sabe lo que hace.
  def repartir_sobrante(anchos, total)
    libres = anchos.count(&:nil?)
    return anchos if libres.zero?

    sobrante = total - anchos.compact.sum
    return anchos if sobrante <= 0

    cada = sobrante / libres.to_f
    anchos.map { |a| a || cada }
  end

  # "Sin nota" en letras, nunca un cero. Es la misma regla del cálculo y de la
  # pantalla del alumno, y en un papel oficial importa todavía más: un cero
  # impreso donde el profesor no corrigió es una reclamación en la dirección.
  # Delegan a las versiones de clase. Ver el comentario de `filas_anuales`:
  # decidir qué dice una celda no necesita una instancia, y separarlo es lo que
  # permite probarlo sin generar un PDF.
  def celda(valor) = self.class.celda(valor)
  def celda_del_ano(valor, escala) = self.class.celda_del_ano(valor, escala)
  def texto(valor) = self.class.texto(valor)
  def abreviar(nombre) = self.class.abreviar(nombre)

  # ⚠️ El pie va ENTERO en una hoja, o va entero en la siguiente.
  #
  # Daniel, 1 de octubre de 2026: *«se está cortando el foot de algunos
  # documentos»*. El código de verificación quedaba a media línea contra el
  # borde del papel y el QR, partido por la mitad.
  #
  # Pasaba en «algunos» porque depende de dónde termina la tabla. El texto salta
  # solo a la hoja siguiente cuando no cabe; el bloque del código NO: es una
  # caja de alto fijo, y el QR son cuadros con coordenadas. Prawn los pinta
  # donde se le dice — también fuera del papel, y sin avisar.
  #
  # ⚠️ Dónde cae lo decide `AcomodoEnHojas`, que además no lo deja viajar solo.
  # El salto de acá es la red de seguridad: si algo midió distinto de lo
  # planeado, el pie igual no se corta.
  def pie(pdf, datos, boletin)
    pdf.start_new_page if pdf.cursor < alto_del_pie(datos, boletin) - 0.01

    dibujar_el_pie(pdf, datos, boletin)
  end

  def dibujar_el_pie(pdf, datos, boletin)
    pdf.move_down 6
    pdf.text "Escala del 1 al 20. Calificación mínima aprobatoria: 10 " \
             "(Art. 108 del Reglamento General de la Ley Orgánica de Educación).",
             size: 7, color: "666666"

    firma(pdf, boletin)

    pdf.move_down 18
    pdf.stroke_color "DDDDDD"
    pdf.stroke_horizontal_rule
    pdf.move_down 8

    verificacion(pdf, datos, boletin)
  end

  # Lo que mide el pie, de la nota de la escala al borde de abajo del QR.
  #
  # ⚠️ Se MIDE dibujándolo una vez, no se suma a mano. El 1 de octubre lo sumé
  # —«6 + 9 + 30 + 40 + 14 + 26 + 50, más 5 de holgura»— y me dio 180 cuando
  # mide 173. Esos siete puntos mandaron a una segunda hoja el pie de TODOS los
  # boletines anuales de bachillerato, que cabían en una: veintidós hojas en
  # blanco por sección, con la firma sola arriba.
  #
  # No depende del alumno —la firma, el sello y el alto de la caja del código
  # son los mismos para todo el colegio—, así que se mide una vez por PDF.
  def alto_del_pie(datos, boletin)
    (@altos_del_pie ||= {})[datos.dig("colegio", "dea")] ||=
      alto_en_borrador { |lienzo| dibujar_el_pie(lienzo, datos, boletin) }
  end

  # La firma del colegio.
  #
  # ## Por qué ya no hay línea para el representante
  #
  # Un boletín es un documento que el colegio EMITE. La firma del representante
  # no certifica nada de lo que dice adentro: lo único que probaría es que lo
  # recibió, y para eso el original venezolano tiene un **talón desprendible**
  # aparte, que se devuelve al colegio. Una línea suelta al pie no cumple esa
  # función y pide una firma que nadie va a recoger.
  #
  # ## Y la del director puede ir escaneada
  #
  # Si el colegio cargó su firma, se dibuja sobre la línea. **No es una firma
  # digital** —es un facsímil, como el sello de goma— y no hay que presentarla
  # como si lo fuera. Lo que hace comprobable este boletín es el código de
  # verificación y su QR, que van abajo.
  # Firma y sello del colegio, como quedan en el papel.
  #
  # ## El sello va ENCIMA de la firma, no al lado
  #
  # Así se estampa en el papel, y no es costumbre: un sello junto a una firma en
  # blanco se puede recortar y pegar en otro documento. Solapados, cada uno
  # respalda al otro.
  #
  # Se dibuja **después** —en un PDF lo último tapa lo anterior— corrido a la
  # derecha y hacia arriba, que es como cae la mano de quien sella, y con
  # transparencia: la tinta del sello deja ver el trazo del bolígrafo debajo. Un
  # sello opaco encima de la firma la borraría, que es justo lo contrario de lo
  # que se busca.
  #
  # ⚠️ Los dos son **facsímiles**, no firmas digitales. Lo que hace comprobable
  # este boletín es el código de verificación y su QR.
  ANCHO_DE_FIRMA = 200
  ALTO_DE_FIRMA  = 40
  LADO_DEL_SELLO = 62
  LADO_DEL_QR    = 54

  def firma(pdf, boletin)
    pdf.move_down 30

    escaneada = imagen_del_colegio(boletin, :firma)
    estampa   = imagen_del_colegio(boletin, :sello)
    izquierda = (pdf.bounds.width - ANCHO_DE_FIRMA) / 2
    arriba    = pdf.cursor

    if escaneada
      # `fit` y no `width`: una firma escaneada viene con la proporción que
      # tenga, y estirarla la vuelve una caricatura de sí misma.
      pdf.bounding_box([izquierda, arriba], width: ANCHO_DE_FIRMA, height: ALTO_DE_FIRMA) do
        pdf.image escaneada, fit: [ANCHO_DE_FIRMA, ALTO_DE_FIRMA - 2], position: :center
      end
    else
      pdf.move_down ALTO_DE_FIRMA
    end

    linea = pdf.cursor
    pdf.stroke_color "666666"
    pdf.stroke_line [izquierda + 20, linea], [izquierda + ANCHO_DE_FIRMA - 20, linea]
    pdf.move_down 4
    pdf.text "Director(a)", size: 8, align: :center

    sello(pdf, estampa, izquierda: izquierda, arriba: arriba, linea: linea) if estampa
  end

  # El sello, encima de todo lo demás.
  #
  # Queda montado sobre el último tercio de la firma y cruzando la línea, que es
  # donde cae en un papel real: un sello estampado al costado, sobre el aire, es
  # exactamente el que se puede recortar y pegar en otro documento.
  #
  # `float` deja el cursor donde estaba — el sello se dibuja ENCIMA de lo que ya
  # hay, no debajo. Sin eso el bloque empuja el resto del pie hacia abajo y el
  # párrafo de verificación se queda sin página; así apareció este bug, como un
  # `Prawn::Errors::CannotFit` lanzado en OTRO método.
  #
  # `transparent` deja ver el trazo del bolígrafo debajo. Un sello opaco encima
  # de la firma la borraría, que es lo contrario de lo que se busca.
  def sello(pdf, estampa, izquierda:, arriba:, linea:)
    x = izquierda + (ANCHO_DE_FIRMA * 0.58)
    y = ((arriba + linea) / 2.0) + (LADO_DEL_SELLO / 2.0) - 2

    # ⚠️ El `rescue` va DENTRO del `bounding_box`, no a nivel del método.
    #
    # Si la excepción escapa del bloque, Prawn nunca restaura los límites de la
    # página: el resto del documento sigue dibujándose dentro de una caja de
    # 62 pt de alto, y el párrafo de verificación —que está bien— revienta con
    # `CannotFit`. El error aparecía en otro método, tres pasos más adelante.
    #
    # Pasa con un archivo que DICE ser PNG y no lo es: `content_type` es lo que
    # declaró quien lo subió, no lo que hay adentro.
    pdf.float do
      pdf.transparent(0.62) do
        pdf.bounding_box([ x, y ], width: LADO_DEL_SELLO, height: LADO_DEL_SELLO) do
          begin
            pdf.image estampa, fit: [ LADO_DEL_SELLO, LADO_DEL_SELLO ],
                               position: :center, vposition: :center
          rescue StandardError => e
            Rails.logger.warn("[ReportCardPdf] sello no dibujado: #{e.message}")
          end
        end
      end
    end
  rescue StandardError => e
    # Un sello que no se puede dibujar no puede tumbar un boletín: sale sin él,
    # como sale sin escudo si el logo está roto. Pasa con un archivo que DICE ser
    # PNG y no lo es — `content_type` es lo que declaró quien lo subió, no lo que
    # hay adentro.
    Rails.logger.warn("[ReportCardPdf] sello no dibujado: #{e.message}")
  end

  # El código de verificación, con su QR al lado.
  #
  # El QR lleva la URL COMPLETA: un papel impreso no tiene contexto, y
  # "/verificar/BOL-822A" no le sirve a nadie que lo escanee. El host sale de
  # `SIGA_HOST`, la misma variable con la que se arman los enlaces del correo.
  def verificacion(pdf, datos, boletin)
    url  = url_de_verificacion(boletin)
    alto = pdf.cursor

    # `height:` explícito: sin él el bloque hereda "lo que quede de página", y si
    # algo de arriba se corrió, Prawn levanta `CannotFit` en vez de pasar a la
    # hoja siguiente. Un boletín no se puede caer por eso.
    pdf.bounding_box([0, alto], width: pdf.bounds.width - 70, height: 42) do
      pdf.text "Código de verificación: <b>#{boletin.code}</b>", size: 8, inline_format: true
      pdf.move_down 2
      pdf.text "Cualquiera puede comprobar este boletín escaneando el código o entrando a " \
               "#{url} — emitido el #{I18n.l(Date.parse(datos['emitido']), format: :long)}.",
               size: 7, color: "666666"
    end

    dibujar_qr(pdf, url, en: [pdf.bounds.width - 58, alto + 4], lado: LADO_DEL_QR)

    # ⚠️ El cursor baja hasta el borde de abajo del QR, que es lo último que se
    # pinta: la caja del texto mide 42 y el QR llega ocho puntos más abajo. Sin
    # esto el pie «terminaba» antes de donde termina de verdad, y quien pregunta
    # cuánto mide —para saber si cabe— recibía un número corto.
    pdf.move_cursor_to alto + 4 - LADO_DEL_QR
  end

  # El QR, dibujado como VECTORES y no como imagen.
  #
  # `rqrcode_core` devuelve la matriz de módulos y acá se pintan cuadrados. Sale
  # nítido a cualquier tamaño de impresión —un PNG rasterizado se ve dentado en
  # papel— y evita arrastrar una gema de imágenes al PDF.
  #
  # La zona de silencio (el margen blanco) **no es decorativa**: sin ella muchos
  # lectores no enganchan el código. El estándar pide cuatro módulos.
  def dibujar_qr(pdf, texto, en:, lado:)
    qr = RQRCodeCore::QRCode.new(texto, level: :m)
    modulos = qr.modules

    silencio = 4
    total    = modulos.size + silencio * 2
    paso     = lado.to_f / total
    x0, y0   = en

    pdf.fill_color "FFFFFF"
    pdf.fill_rectangle [x0, y0], lado, lado

    pdf.fill_color "000000"
    modulos.each_with_index do |fila, f|
      fila.each_with_index do |encendido, c|
        next unless encendido

        pdf.fill_rectangle [x0 + (c + silencio) * paso, y0 - (f + silencio) * paso], paso, paso
      end
    end
    pdf.fill_color "000000"
  rescue StandardError => e
    # Un QR que no se puede generar no puede tumbar un boletín. Queda el código
    # escrito al lado, que es lo que de verdad verifica.
    Rails.logger.warn("[ReportCardPdf] QR no generado: #{e.message}")
  end

  # `SIGA_HOST` es la misma variable con la que `production.rb` arma los enlaces
  # del correo: un solo lugar donde decir cómo se llama este sistema afuera.
  def url_de_verificacion(boletin)
    host = ENV.fetch("SIGA_HOST", "localhost:3000")

    # `https` salvo en local. Sin esto, un boletín generado en desarrollo lleva
    # un QR que apunta a `https://localhost:3000` — o sea, a ninguna parte— y el
    # error aparece recién cuando alguien lo escanea.
    local     = host.start_with?("localhost", "127.0.0.1")
    protocolo = local ? "http" : ENV.fetch("SIGA_PROTOCOLO", "https")

    "#{protocolo}://#{host}#{ruta_de_verificacion(boletin)}"
  end

  def ruta_de_verificacion(boletin)
    "/verificar/#{boletin.code}"
  end
end
