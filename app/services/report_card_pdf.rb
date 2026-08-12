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

  private

  def pagina(pdf, boletin)
    datos = boletin.snapshot

    encabezado(pdf, datos)
    identificacion(pdf, datos)
    datos["tipo"] == "anual" ? tabla_anual(pdf, datos) : tabla_de_lapso(pdf, datos)
    pie(pdf, datos, boletin)
  end

  def encabezado(pdf, datos)
    colegio = datos["colegio"]

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

  def tabla_anual(pdf, datos)
    encabezados = ["MATERIA"] + datos["lapsos"].map { |l| abreviar(l) } + %w[ANUAL REPAR. DEFINIT.]
    filas = [encabezados]

    datos["materias"].each do |m|
      filas << [texto(m["materia"])] + m["lapsos"].map { |n| celda(n) } +
               [celda(m["anual"]), celda(m["reparacion"]), celda(m["definitiva"])]
    end

    filas << ["PROMEDIO GENERAL"] + Array.new(datos["lapsos"].size + 2, "") + [celda(datos["promedio"])]

    anchos = [nil] + Array.new(datos["lapsos"].size + 3, 52)
    dibujar_tabla(pdf, filas, anchos, ultima_en_negrita: true)
  end

  def dibujar_tabla(pdf, filas, anchos, ultima_en_negrita: false)
    tabla = pdf.make_table(filas, width: pdf.bounds.width,
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

    anchos.each_with_index { |ancho, i| tabla.column(i).width = ancho if ancho }
    tabla.draw
    pdf.move_down 14
  end

  # "Sin nota" en letras, nunca un cero. Es la misma regla del cálculo y de la
  # pantalla del alumno, y en un papel oficial importa todavía más: un cero
  # impreso donde el profesor no corrigió es una reclamación en la dirección.
  def celda(valor)
    valor.presence&.to_s || "Sin nota"
  end

  # Deja pasar tal cual lo que la fuente puede dibujar, y translitera solo lo que
  # no. Un "José" se imprime "José"; un "Ștefan" se imprime "Stefan" en vez de
  # tirar abajo el boletín. Ver el comentario de `representable?`.
  def texto(valor)
    cadena = valor.to_s
    self.class.representable?(cadena) ? cadena : ActiveSupport::Inflector.transliterate(cadena)
  end

  def abreviar(nombre)
    texto(nombre).sub(/^Primer/, "1er").sub(/^Segundo/, "2do").sub(/^Tercer/, "3er")
          .sub(/ Lapso$/, " Lapso").sub(/ Semestre$/, " Sem.")
  end

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
