# El boletín en papel.
#
# Prawn dibuja el PDF en Ruby puro, sin ningún binario del sistema. Se eligió por
# eso: `wicked_pdf` y `pdfkit` dependen de `wkhtmltopdf`, que sus propios autores
# archivaron, y `grover` necesita Node y Chromium. Y sobre todo, **el entorno de
# despliegue todavía no está decidido** — atarlo a un binario sería tomar esa
# decisión de costado.
#
# Recibe `ReportCard` ya guardados y dibuja UNA PÁGINA POR CADA UNO desde su
# `snapshot`, nunca desde la base. Así el papel, el archivo y la verificación
# pública dicen exactamente lo mismo.
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
  # Es público para poder probarlo: **el texto de un PDF de Prawn no se puede
  # leer desde afuera** —la fuente va embebida como subconjunto y los caracteres
  # quedan mapeados a glifos, así que buscar "A (19)" en los bytes no encuentra
  # nada—. Sin esta costura, la única forma de verificar lo que sale impreso
  # sería sumar una gema solo para leer PDFs.
  #
  # Y la separación se sostiene sola: qué dice cada celda es una regla del
  # dominio; dónde se dibuja es tipografía.
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

  # El escudo del colegio, cacheado por colegio.
  #
  # Emitir la sección entera son treinta páginas del MISMO colegio: sin el caché
  # serían treinta descargas del mismo archivo desde Active Storage.
  def logo_del_colegio(boletin)
    @logos ||= {}
    escuela = boletin.enrollment.section.grade.school

    @logos.fetch(escuela.id) { @logos[escuela.id] = escuela.logo_para_pdf }
  end

  def pagina(pdf, boletin)
    datos = boletin.snapshot

    encabezado(pdf, datos, boletin)
    identificacion(pdf, datos)
    datos["tipo"] == "anual" ? tabla_anual(pdf, datos) : tabla_de_lapso(pdf, datos)
    asistencia_y_puesto(pdf, datos)
    situacion_en_la_seccion(pdf, datos)
    informe_descriptivo(pdf, datos)
    pie(pdf, datos, boletin)
  end

  # El escudo del colegio, a la izquierda, con el membrete centrado.
  #
  # ⚠️ El logo se lee de la BASE, no del snapshot, y es la única cosa del boletín
  # que no se congela. Todo lo demás —las notas, el grado, la escala— es lo que
  # el papel dijo el día que se emitió, y no puede cambiar. El escudo es
  # IDENTIDAD: si el colegio lo rediseña, un boletín reemitido lleva el nuevo, y
  # eso es lo correcto. Congelarlo dejaría el escudo viejo en un documento que el
  # colegio está entregando hoy.
  def encabezado(pdf, datos, boletin = nil)
    colegio = datos["colegio"]
    escudo  = boletin && logo_del_colegio(boletin)

    if escudo
      # Se dibuja en su propia caja, así que el membrete sigue centrado en la
      # página y no "al lado del logo" — que es como se ve un membrete torcido.
      pdf.bounding_box([0, pdf.cursor + 4], width: 60, height: 46) do
        pdf.image escudo, fit: [56, 44], position: :left, vposition: :top
      rescue StandardError
        nil   # Un escudo que no se puede dibujar no puede tirar abajo el boletín.
      end
    end

    pdf.text texto(colegio["nombre"]).upcase, size: 15, style: :bold, align: :center
    pdf.text "#{texto(colegio['ubicacion'])}  ·  Código DEA #{texto(colegio['dea'])}",
             size: 8, align: :center, color: "666666"
    pdf.move_down 12

    titulo = datos["tipo"] == "anual" ? "BOLETÍN ANUAL DE CALIFICACIONES" : "BOLETÍN DE CALIFICACIONES"
    pdf.text titulo, size: 12, style: :bold, align: :center
    subtitulo = [texto(datos["lapso"]), "Año escolar #{texto(datos['seccion']['periodo'])}"].compact_blank.join("  ·  ")
    pdf.text subtitulo, size: 9, align: :center, color: "666666"
    pdf.move_down 14
  end

  def identificacion(pdf, datos)
    alumno  = datos["alumno"]
    seccion = datos["seccion"]

    pdf.table(
      [
        ["Alumno",  texto(alumno["nombre"]),  "Carnet", texto(alumno["carnet"])],
        ["Grado",   texto(seccion["grado"]),  "Sección", texto(seccion["seccion"])]
      ],
      width: pdf.bounds.width, cell_style: { size: 9, borders: [], padding: [2, 4] }
    ) do
      columns(0).font_style = :bold
      columns(2).font_style = :bold
      columns(0).width = 55
      columns(2).width = 55
    end

    pdf.move_down 10
  end

  # ⚠️ La columna de la derecha lleva el NIVEL cuando el colegio definió su
  # rúbrica, y el número cuando no (MOR-136).
  #
  # Los dos, no uno: *«la niña sacó 19, por eso tiene PC»* —Cyndi—. La familia
  # lee el nivel; el número queda al lado porque es lo que el docente cargó y lo
  # que el colegio tiene que poder verificar. Esconderlo obligaría a pedir el
  # boletín para saber de dónde salió la letra.
  def tabla_de_lapso(pdf, datos)
    con_rubrica = datos["rubrica"].present?
    filas = [["MATERIA", con_rubrica ? "NIVEL" : "CALIFICACIÓN"]]

    datos["materias"].each do |materia|
      filas << [texto(materia["materia"]), celda_de_lapso(materia, con_rubrica)]
      # Las competencias van DEBAJO de su materia, en la misma tabla: son parte
      # de esa fila, no una lista aparte. Ver `filas_de_competencias`.
      filas.concat(filas_de_competencias(materia, con_rubrica))
    end

    filas << ["PROMEDIO DEL LAPSO", celda(datos["promedio"])]

    dibujar_tabla(pdf, filas, [nil, 110], ultima_en_negrita: true)
    leyenda_de_la_rubrica(pdf, datos["rubrica"])
  end

  def celda_de_lapso(materia, con_rubrica)
    return celda(materia["nota"]) unless con_rubrica && materia["nivel_de_rubrica"].present?

    # El nivel manda y el número lo respalda: «PC (19)».
    { content: "#{materia['nivel_de_rubrica']} (#{materia['nota']})", align: :center }
  end

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
  def filas_de_competencias(materia, con_rubrica)
    Array(materia["competencias"]).flat_map do |competencia|
      nivel = con_rubrica ? (competencia["nivel_de_rubrica"] || "Sin evaluar") : ""
      fila  = [ { content: "   • #{texto(competencia['texto'])}", size: 7.5, text_color: "555555" },
                { content: nivel.to_s, size: 7.5, align: :center, text_color: "555555" } ]

      indicadores = PlanEvaluado.indicadores_de(competencia).map do |indicador|
        suyo = con_rubrica ? indicador["nivel_de_rubrica"].to_s : ""
        [ { content: "        – #{texto(indicador['texto'])}", size: 7, text_color: "888888" },
          { content: suyo, size: 7, align: :center, text_color: "888888" } ]
      end

      [ fila ] + indicadores
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
    # "19". Las de lapso siguen igual.
    ancho_del_ano = escala.to_s == "literal" ? 60 : 52
    anchos = [nil] + Array.new(datos["lapsos"].size, 44) + [ancho_del_ano, 44, ancho_del_ano]

    dibujar_tabla(pdf, self.class.filas_anuales(datos), anchos, ultima_en_negrita: true)
  end

  # ## Los anchos van al CONSTRUIR, no después
  #
  # Antes se hacía `make_table(width: …)` y luego `tabla.column(i).width = x`.
  # Prawn acepta las dos cosas y el objeto reporta el ancho correcto —540 pt— pero
  # **dibuja mal**: los fondos de celda se pintan con los anchos que calculó al
  # construirse y los bordes con los nuevos. El resultado era una tabla de 428 pt
  # pegada a la izquierda, con una columna extra fantasma al final.
  #
  # Y no fallaba en ninguna parte: `tabla.width` decía 540. Solo se ve mirando el
  # papel.
  #
  # Con `column_widths:` en el constructor, los anchos entran en el mismo cálculo
  # que todo lo demás. `repartir_sobrante` reparte lo que queda entre las columnas
  # sin ancho fijo, así que la suma da exactamente el bloque útil.
  # Inasistencias del lapso y puesto en la sección (MOR-135).
  #
  # Van en una franja de tres datos y no en tablas separadas: son tres números
  # y darles una tabla a cada uno haría un boletín de dos páginas para decir lo
  # mismo.
  #
  # El empate comparte puesto y **se dice**: "10º de 20 (empatado)". Dos alumnos
  # con el mismo promedio están los dos décimos; darle el 10 a uno y el 11 al
  # otro por el orden alfabético inventa una diferencia que no existe — y se
  # imprime en un papel que la familia guarda.
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

  def asistencia_y_puesto(pdf, datos)
    asistencia = datos["asistencia"]
    puesto     = datos["puesto"]
    return if asistencia.nil? && puesto.nil?

    celdas = []

    if asistencia
      faltas = asistencia["ausentes"]
      celdas << [ "INASISTENCIAS",
                  "#{faltas} de #{asistencia['dias']} #{pluralizar(asistencia['dias'], 'día', 'días')} de clase" ]
      celdas << [ "LLEGADAS TARDE", asistencia["tardes"].to_s ] if asistencia["tardes"].to_i.positive?
    end

    if puesto
      celdas << [ "PUESTO EN LA SECCIÓN",
                  "#{puesto['puesto']}º de #{puesto['de']}#{' (empatado)' if puesto['empatado']}" ]
    end

    tabla = pdf.make_table([ celdas.map(&:first), celdas.map(&:last) ],
                           width: pdf.bounds.width,
                           cell_style: { size: 8, padding: [ 3, 6 ], borders: [], align: :center }) do
      row(0).size = 6
      row(0).font_style = :bold
      row(0).text_color = "878787"
      row(1).size = 11
    end
    tabla.draw
    pdf.move_down 4

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

  # Dónde queda el alumno respecto de su sección (MOR-135).
  #
  # Es la pieza que Daniel señaló del boletín de la U.E. Centro Educativo APUCV,
  # y contesta la pregunta que una familia hace de verdad: no *"¿cuánto sacó?"*
  # sino *"¿cómo le fue comparado con sus compañeros?"*.
  #
  # ## La barra se dibuja con CELDAS, no con coordenadas
  #
  # Una barra "de verdad" —un rectángulo sobre la tabla— obliga a calcular la
  # posición de cada fila después de dibujarla, y eso se rompe en cuanto una
  # materia de nombre largo ocupa dos renglones. Seis celdas por fila, pintadas
  # hasta el nivel que corresponde, dan el mismo resultado y las alinea Prawn.
  # Además coincide con el original impreso, que lleva las líneas verticales de
  # las bandas cruzando la barra.
  #
  # ## Sin color semántico
  #
  # Un solo tono de marca. Estar por debajo del promedio de la clase **no es
  # reprobar** —se puede estar debajo del promedio con 17— y pintarlo de rojo
  # sería un juicio que el colegio no emitió. Lo que informa es la POSICIÓN.
  def situacion_en_la_seccion(pdf, datos)
    comparacion = datos["comparacion"]
    return if comparacion.nil?

    niveles = comparacion["niveles"]

    pdf.font_size(9) { pdf.text "<b>SITUACIÓN CON RESPECTO A LA SECCIÓN</b>", inline_format: true }
    pdf.move_down 6

    encabezado = ["MATERIA", "ALUMNO", "SECCIÓN"] + niveles.map { |n| texto(n).upcase }
    filas = [encabezado]

    comparacion["materias"].each do |f|
      filas << [texto(f["materia"]), celda(f["nota"]), coma(f["seccion"])] + Array.new(niveles.size, "")
    end

    general = comparacion["general"]
    filas << ["SITUACIÓN GENERAL", celda(general["nota"]), coma(general["seccion"])] +
             Array.new(niveles.size, "")

    ancho_banda = 46
    anchos = [nil, 46, 50] + Array.new(niveles.size, ancho_banda)

    tabla = pdf.make_table(filas,
                           width: pdf.bounds.width,
                           column_widths: repartir_sobrante(anchos, pdf.bounds.width),
                           cell_style: { size: 7, padding: [3, 4], border_color: "DDDDDD" }) do
      row(0).font_style = :bold
      row(0).background_color = "F0EDE8"
      row(0).size = 6
      columns(1..-1).align = :center
      row(-1).font_style = :bold
      row(-1).background_color = "F5F3F0"
    end

    # Pintar la barra: las bandas hasta el nivel del alumno, inclusive.
    ([ comparacion["materias"], [ general ] ].flatten).each_with_index do |f, i|
      next if f["nivel"].nil?

      (0..f["nivel"]).each { |b| tabla.row(i + 1).column(3 + b).background_color = "1E4A7A" }
    end

    tabla.draw
    pdf.move_down 8

    pdf.font_size(6.5) do
      pdf.fill_color "666666"
      pdf.text "SECCIÓN es el promedio de esa materia en la sección, con las notas cargadas al " \
               "emitir este boletín. La barra indica cuánto se aparta el alumno de ese promedio: " \
               "cada banda son dos puntos, y el corte entre MEDIO BAJO y MEDIO ALTO es el promedio " \
               "mismo. Estar por debajo del promedio de la clase no significa aplazar.",
               align: :justify
      pdf.fill_color "000000"
    end
    pdf.move_down 10
  end

  # Coma decimal: acá 13.5 se escribe 13,5.
  def coma(valor)
    return "—" if valor.nil?

    format("%.1f", valor).tr(".", ",")
  end

  def dibujar_tabla(pdf, filas, anchos, ultima_en_negrita: false)
    tabla = pdf.make_table(filas,
                           width: pdf.bounds.width,
                           column_widths: repartir_sobrante(anchos, pdf.bounds.width),
                           cell_style: { size: 9, padding: [4, 6], border_color: "DDDDDD" }) do
      row(0).font_style = :bold
      row(0).background_color = "F0EDE8"
      row(0).size = 8
      columns(1..-1).align = :center
      if ultima_en_negrita
        row(-1).font_style = :bold
        row(-1).background_color = "F5F3F0"
      end
    end

    tabla.draw
    pdf.move_down 14
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
  # ⚠️ Se pregunta ANTES de la firma y no antes del código. Saltando solo el
  # código, la firma quedaría al pie de una hoja y lo que la hace comprobable al
  # principio de la otra: dos mitades de un mismo cierre, en dos papeles.
  def pie(pdf, datos, boletin)
    pdf.start_new_page if pdf.cursor < ALTO_DEL_PIE

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

  # Lo que ocupa el pie entero, de la nota de la escala al borde de abajo del QR.
  #
  #       6   aire
  #       9   «Escala del 1 al 20…», un renglón
  #      30   aire antes de la firma
  #      40   la firma                          ← ALTO_DE_FIRMA
  #      14   la línea y «Director(a)»
  #      26   aire, la raya y más aire
  #      50   el QR, que es lo que más baja     ← 54 de lado, arranca 4 pt arriba
  #       5   holgura: los renglones no miden exactamente su cuerpo
  #
  # ⚠️ Si se toca cualquiera de esos números en `pie`, `firma` o `verificacion`,
  # se toca acá. No hay cómo deducirlo: el QR se pinta con coordenadas y no
  # mueve el cursor. Lo cuida un test que barre el largo de la tabla.
  ALTO_DEL_PIE = 6 + 9 + 30 + ALTO_DE_FIRMA + 14 + 26 + 50 + 5

  def firma(pdf, boletin)
    pdf.move_down 30

    colegio   = boletin.enrollment.section.grade.school rescue nil
    escaneada = colegio&.firma_para_pdf
    estampa   = colegio&.sello_para_pdf
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

    dibujar_qr(pdf, url, en: [pdf.bounds.width - 58, alto + 4], lado: 54)
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
