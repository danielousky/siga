# El RESUMEN FINAL DEL RENDIMIENTO ESTUDIANTIL en PDF, formato `RR-DEA-04-03`.
#
# ## ⚠️ ACOSTADO, y no es una preferencia
#
# Son quince columnas de asignatura más la cédula, el nombre y el resumen. En
# vertical no entran: o se achica la letra hasta que no se lea, o se parte la
# tabla en dos páginas y deja de ser un acta.
#
# ## ⚠️ Tres bloques quedan en BLANCO, a propósito
#
#     Plan de Estudio · Mención     SIGA no los modela
#     Educación para el Trabajo     tampoco, ni programas ni horas
#     «Resumen» (última columna)    el formato no dice qué va ahí
#
# El papel oficial se llena a mano en esas casillas, y acá pasa lo mismo. Quien
# necesite escribirlas antes de imprimir usa la versión en Excel — la misma
# decisión que la 31059.
class ResumenFinalPdf
  include DibujaDocumentosOficiales

  MARGEN = 28
  COLUMNAS = ResumenFinalDeLaSeccion::COLUMNAS_DE_ASIGNATURA

  def initialize(datos)
    @d = datos
  end

  def render
    pdf = Prawn::Document.new(page_size: "LETTER", page_layout: :landscape, margin: MARGEN,
                              info: { Title: "Resumen Final del Rendimiento Estudiantil",
                                      Creator: "SIGA", CreationDate: Time.current })

    encabezado(pdf)
    datos_del_plantel(pdf)
    rendimiento(pdf)
    profesores(pdf)
    pie(pdf)

    pdf.render
  end

  private

  def encabezado(pdf)
    pdf.text "RESUMEN FINAL DEL RENDIMIENTO ESTUDIANTIL", size: 12, style: :bold, align: :center
    pdf.text "(Régimen Regular) · Código del Formato RR-DEA-04-03", size: 7.5, align: :center,
             color: "666666"
    pdf.move_down 8
  end

  # Secciones I y II del formato, en una tirada.
  #
  # ⚠️ «Plan de Estudio» y «Mención» salen como línea: SIGA no los modela, y
  # una casilla vacía sin línea se lee como un dato que falta y no como uno que
  # hay que escribir.
  def datos_del_plantel(pdf)
    p_ = @d["plantel"]
    c = @d["curso"]

    filas = [
      [ "I. Plan de Estudio:", linea(28), "Mención:", linea(28) ],
      [ "Año Escolar:", texto(c["anio_escolar"]), "Cód. DEA:", texto(p_["dea"]) ],
      [ "Plantel:", texto(p_["nombre"]), "Dirección:", texto(p_["direccion"]) ],
      [ "Municipio:", texto(p_["municipio"]), "Ent. Federal:", texto(p_["entidad_federal"]) ],
      [ "Director(a):", texto(p_["director"]), "Grado o Año / Sección:",
        "#{texto(c['grado'])} – #{texto(c['seccion'])}" ]
    ]

    pdf.table(filas, width: pdf.bounds.width,
                     cell_style: { size: 7.5, padding: [ 2, 4 ], border_color: "999999" }) do
      columns(0).font_style = :bold
      columns(2).font_style = :bold
      columns(0).width = 92
      columns(2).width = 108
    end
    pdf.move_down 8
  end

  # Sección III: una fila por alumno, una columna por asignatura.
  def rendimiento(pdf)
    pdf.text "III. Resumen Final del Rendimiento", size: 8, style: :bold
    pdf.move_down 3

    cabecera = [ "N°", "Cédula de Identidad", "Apellidos y Nombres" ] +
               (1..COLUMNAS).map { |n| format("%02d", n) } + [ "Resumen" ]

    cuerpo = @d["filas"].map do |f|
      notas = Array.new(COLUMNAS) { |i| f["notas"][i]&.to_s }
      [ f["numero"], texto(f["cedula"]), texto(f["nombre"]) ] + notas + [ "" ]
    end

    pdf.table([ cabecera ] + cuerpo, width: pdf.bounds.width, header: true,
              cell_style: { size: 6, padding: [ 1.5, 2 ], border_color: "999999",
                            align: :center }) do
      row(0).font_style = :bold
      row(0).background_color = "F2F2F2"
      columns(2).align = :left
      columns(1).width = 74
      columns(2).width = 138
    end

    pdf.move_down 4
    pdf.text "TOTAL DE ALUMNOS DE LA SECCIÓN: #{@d['total_de_alumnos']}", size: 8, style: :bold
  end

  # Sección IV: qué asignatura es cada número, y quién la dictó.
  #
  # ⚠️ Sin esto la tabla de arriba es ilegible: son columnas numeradas 01 a 15 y
  # nada dice cuál es Matemática. Y la FIRMA de cada profesor es lo que
  # convierte el acta en un documento: la zona educativa la exige.
  def profesores(pdf)
    pdf.move_down 10
    pdf.text "IV. Asignaturas y profesores", size: 8, style: :bold
    pdf.move_down 3

    filas = @d["asignaturas"].map do |a|
      [ a["codigo"], texto(a["nombre"]), texto(a.dig("profesor", "nombre")),
        texto(a.dig("profesor", "documento")), "" ]
    end

    pdf.table([ [ "N°", "Asignatura", "Apellidos y Nombres del Profesor",
                  "Cédula de Identidad", "Firma" ] ] + filas,
              width: pdf.bounds.width, header: true,
              cell_style: { size: 6.5, padding: [ 2, 3 ], border_color: "999999" }) do
      row(0).font_style = :bold
      row(0).background_color = "F2F2F2"
      row(0).align = :center
      columns(0).width = 26
      columns(0).align = :center
    end
  end

  # Secciones V a VIII. Todas en blanco: las llena el colegio y la zona.
  def pie(pdf)
    pdf.move_down 10

    pdf.table([ [ "V. Programas Cursados de Educación para el Trabajo / Horas-Alumnos Semanales de C/Uno." ],
                [ " " ], [ "VI. Observaciones:" ], [ " " ] ],
              width: pdf.bounds.width,
              cell_style: { size: 7, padding: [ 3, 4 ], border_color: "999999" }) do
      row(0).font_style = :bold
      row(2).font_style = :bold
      row(1).height = 22
      row(3).height = 22
    end

    pdf.move_down 8
    pdf.table([
      [ "VII. Fecha de Remisión:", "VIII. Fecha de Recepción:" ],
      [ "Director(a) — SELLO DEL PLANTEL", "Funcionario Receptor — SELLO DE LA ZONA EDUCATIVA" ],
      [ "Apellidos y Nombres:  #{texto(@d.dig('firmante', 'nombre')).upcase}", "Apellidos y Nombres:" ],
      [ "Número de C.I.:  #{texto(@d.dig('firmante', 'documento'))}", "Número de C.I.:" ],
      [ "Firma:", "Firma:" ]
    ], width: pdf.bounds.width,
       cell_style: { size: 7, padding: [ 3, 4 ], border_color: "999999" }) do
      row(0).font_style = :bold
      row(1).font_style = :bold
      row(1).align = :center
      row(1).background_color = "F2F2F2"
      row(4).height = 40
    end
  end

  # Una línea para llenar a mano, que es lo que hace el papel oficial.
  def linea(largo) = "_" * largo
end
