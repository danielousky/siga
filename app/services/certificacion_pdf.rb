# La Certificación de Calificaciones en papel — forma 31059 (MOR-99).
#
# Dibuja las cinco secciones del formato oficial del MPPE. Los datos los arma
# `CertificacionDeCalificaciones`; acá solo se decide cómo se ven.
#
# ## Por qué apaisado
#
# La sección V es una tabla de áreas × años: hasta cinco columnas de año más el
# nombre del área. En vertical, «Geografía, Historia y Ciudadanía» se parte en
# tres líneas y la tabla deja de leerse. El formato oficial también es apaisado.
class CertificacionPdf
  include DibujaDocumentosOficiales

  MARGEN = 30
  ANCHO_DE_AREA = 190
  ANCHO_DE_NOTA = 74

  def initialize(datos)
    @d = datos
  end

  def render
    pdf = Prawn::Document.new(page_size: "LETTER", page_layout: :landscape, margin: MARGEN, info: {
      Title: "Certificación de Calificaciones", Creator: "SIGA", CreationDate: Time.current
    })

    membrete(pdf)
    seccion_del_plantel(pdf)
    seccion_del_estudiante(pdf)
    seccion_de_planteles(pdf)
    seccion_de_calificaciones(pdf)
    pie(pdf)

    pdf.render
  end

  private

  # ── el membrete, y la sección I ───────────────────────────────────────────

  def membrete(pdf)
    pdf.text "REPÚBLICA BOLIVARIANA DE VENEZUELA", size: 9, align: :center
    pdf.text "MINISTERIO DEL PODER POPULAR PARA LA EDUCACIÓN", size: 9, align: :center
    pdf.move_down 8

    pdf.text "CERTIFICACIÓN DE CALIFICACIONES", size: 14, style: :bold, align: :center
    plan = @d["plan"]
    pdf.text "#{texto(plan['nombre'])}  ·  Plan de estudio #{texto(plan['codigo'])}",
             size: 9, align: :center, color: "666666"
    pdf.move_down 10
  end

  # ── sección II ────────────────────────────────────────────────────────────

  def seccion_del_plantel(pdf)
    p_ = @d["plantel"]
    ubicacion = [ p_["municipio"], p_["entidad_federal"] ].compact_blank.join(", ")

    rotulo(pdf, "DATOS DEL PLANTEL")
    campos(pdf, [
      [ "Plantel", p_["nombre"], "Código DEA", p_["dea"] ],
      [ "Dirección", p_["direccion"], "Municipio y entidad", ubicacion.presence ]
    ])
  end

  # ── sección III ───────────────────────────────────────────────────────────

  def seccion_del_estudiante(pdf)
    e = @d["estudiante"]

    rotulo(pdf, "IDENTIFICACIÓN DEL ESTUDIANTE")
    campos(pdf, [
      # ⚠️ Apellidos y nombres en casillas SEPARADAS: quien recibe el documento
      # compara el PRIMER apellido contra la cédula del SAIME.
      [ "Apellidos", e["apellidos"], "Nombres", e["nombres"] ],
      # ⚠️ El rótulo tiene que decir CUÁL identificador es.
      #
      # Un alumno de bachillerato trae cédula de identidad; uno que todavía no la
      # sacó trae cédula ESCOLAR, que es otra cosa y la asigna el MPPE. Poner
      # «Cédula: V20141000555» sobre una cédula escolar es un dato mal rotulado
      # en un documento oficial, y quien lo recibe lo va a cotejar contra el
      # SAIME y no lo va a encontrar.
      [ e["documento"].present? ? "Cédula de identidad" : "Cédula escolar",
        e["documento"] || e["cedula_escolar"],
        "Fecha y lugar de nacimiento",
        [ fecha(e["fecha_de_nacimiento"]), e["lugar_de_nacimiento"] ].compact_blank.join(", ").presence ]
    ])
  end

  # ── sección IV ────────────────────────────────────────────────────────────

  def seccion_de_planteles(pdf)
    cursados = Array(@d["planteles_cursados"])
    return if cursados.empty?

    rotulo(pdf, "PLANTELES DONDE CURSÓ")
    filas = [ [ "PLANTEL", "LOCALIDAD", "AÑOS ESCOLARES" ] ]
    cursados.each { |p_| filas << [ texto(p_["plantel"]), texto(p_["localidad"]), p_["anos"].join(" · ") ] }

    tabla(pdf, filas, [ 260, 160, nil ])
  end

  # ── sección V ─────────────────────────────────────────────────────────────

  def seccion_de_calificaciones(pdf)
    anos = Array(@d["anos"])
    rotulo(pdf, "ÁREAS DE FORMACIÓN Y CALIFICACIONES")

    if anos.empty? || Array(@d["areas"]).empty?
      pdf.text "Este estudiante todavía no tiene calificaciones definitivas cargadas.",
               size: 9, color: "666666"
      return
    end

    filas = [ [ "ÁREA DE FORMACIÓN" ] + anos.map { |a| a.gsub(" · ", "\n") } ]
    @d["areas"].each do |area|
      filas << [ texto(area["area"]) ] + anos.map { |a| area.dig("notas", a, "texto") || "—" }
    end

    tabla(pdf, filas, [ ANCHO_DE_AREA ] + Array.new(anos.size, ANCHO_DE_NOTA), centrar_desde: 1)
  end

  # ── el pie ────────────────────────────────────────────────────────────────

  def pie(pdf)
    pdf.move_down 8
    pdf.text "Escala del 1 al 20. Calificación mínima aprobatoria: 10 (Art. 108 del Reglamento " \
             "General de la Ley Orgánica de Educación). Las áreas de Orientación y Convivencia y " \
             "Participación en Grupos de Creación, Recreación y Producción se certifican con " \
             "calificación literal.",
             size: 7, color: "666666"

    expedida = @d["expedida"]
    pdf.move_down 6
    pdf.text "Expedida en #{texto(expedida['en'])}, el #{fecha(expedida['el'])}.", size: 8

    # ⚠️ La vigencia va IMPRESA. No es una decisión nuestra: la fija el MPPE, y
    # quien recibe el papel necesita saber hasta cuándo le sirve.
    pdf.text "Válida por #{@d['plan']['vigencia']} años a partir de la fecha de expedición.",
             size: 7, color: "666666"

    pdf.move_down 24
    firma_del_director(pdf, colegio, rotulo: "Director(a) del plantel",
                                     nombre: @d.dig("firmante", "nombre"),
                                     documento: @d.dig("firmante", "documento"))
  end

  # ── el andamiaje ──────────────────────────────────────────────────────────

  def rotulo(pdf, titulo)
    pdf.move_down 8
    pdf.text titulo, size: 8, style: :bold, color: "1F5C8B"
    pdf.move_down 3
  end

  # Los campos de una sección, en dos pares por fila.
  def campos(pdf, filas)
    pdf.table(filas.map { |f| f.map { |v| texto(v.presence || "—") } },
              width: pdf.bounds.width, cell_style: { size: 8, borders: [], padding: [ 2, 4 ] }) do
      columns(0).font_style = :bold
      columns(2).font_style = :bold
      columns(0).width = 80
      columns(2).width = 120
    end
  end

  def tabla(pdf, filas, anchos, centrar_desde: nil)
    # ⚠️ El rango va CERRADO, no infinito: `columns(1..)` le da a prawn-table un
    # `Range` sin fin y responde «Don't understand spec nil». La última columna
    # se calcula, no se deja abierta.
    ultima = filas.first.size - 1
    anchos = repartir_sobrante(anchos, pdf.bounds.width)

    pdf.table(filas, width: pdf.bounds.width, header: true,
                     cell_style: { size: 8, padding: [ 3, 4 ], border_color: "CCCCCC" }) do
      row(0).font_style = :bold
      row(0).background_color = "EEF2F6"
      row(0).align = :center
      anchos.each_with_index { |a, i| columns(i).width = a if a }
      columns(centrar_desde..ultima).align = :center if centrar_desde
    end
  end

  # ⚠️ Los anchos fijos tienen que SUMAR el ancho de la página.
  #
  # Con un alumno de un solo año, la tabla de calificaciones pedía 264 pt de
  # contenido en una página de 732 y Prawn levanta `CannotFit`: no acepta que le
  # pidan más ancho del que sus columnas pueden ocupar.
  #
  # El sobrante va a la PRIMERA columna, que en las dos tablas es la del rótulo
  # —el área o el plantel— y es la que más agradece el espacio.
  def repartir_sobrante(anchos, total)
    fijos = anchos.compact.sum
    return anchos if anchos.any?(&:nil?) || fijos >= total

    [ anchos.first + (total - fijos) ] + anchos.drop(1)
  end

  def fecha(iso)
    return "—" if iso.blank?

    I18n.l(Date.parse(iso), format: :long)
  rescue Date::Error
    iso.to_s
  end

  # El colegio que emite. Se busca por su código DEA, que es lo único del plantel
  # que viaja en los datos y no cambia.
  def colegio
    @colegio ||= Current.sin_aislamiento { School.find_by(dea_code: @d.dig("plantel", "dea")) }
  end
end
