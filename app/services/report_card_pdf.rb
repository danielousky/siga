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

  def tabla_de_lapso(pdf, datos)
    filas = [["MATERIA", "CALIFICACIÓN"]]
    datos["materias"].each { |m| filas << [texto(m["materia"]), celda(m["nota"])] }
    filas << ["PROMEDIO DEL LAPSO", celda(datos["promedio"])]

    dibujar_tabla(pdf, filas, [nil, 110], ultima_en_negrita: true)
  end

  # Las notas de LAPSO van en número; las del AÑO llevan el literal cuando el
  # grado se califica así (MOR-129).
  #
  # No es una inconsistencia: *"los literales son la nota final del año escolar"*
  # —Cyndi—. Durante los lapsos primaria evalúa con competencias e indicadores y
  # una rúbrica de cinco niveles, que es `MOR-136` y todavía no existe. Hasta
  # entonces el lapso se muestra como lo que se cargó: un número.
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

  def pie(pdf, datos, boletin)
    pdf.move_down 6
    pdf.text "Escala del 1 al 20. Calificación mínima aprobatoria: 10 " \
             "(Art. 108 del Reglamento General de la Ley Orgánica de Educación).",
             size: 7, color: "666666"

    pdf.move_down 34
    pdf.table(
      [["_____________________________", "_____________________________"],
       ["Director(a)", "Representante"]],
      width: pdf.bounds.width, cell_style: { size: 8, borders: [], align: :center, padding: [1, 4] }
    )

    pdf.move_down 18
    pdf.stroke_color "DDDDDD"
    pdf.stroke_horizontal_rule
    pdf.move_down 6

    pdf.text "Código de verificación: <b>#{boletin.code}</b>", size: 8, inline_format: true
    pdf.text "Este boletín se puede verificar en #{ruta_de_verificacion(boletin)} — " \
             "emitido el #{I18n.l(Date.parse(datos['emitido']), format: :long)}.",
             size: 7, color: "666666"
  end

  def ruta_de_verificacion(boletin)
    "/verificar/#{boletin.code}"
  end
end
