# La Certificación de Calificaciones en Excel — forma 31059 (MOR-99).
#
# ## Por qué existe además del PDF
#
# El PDF es el documento terminado: sale como tiene que verse y no se toca. Pero
# la 31059 tiene casillas que SIGA no puede llenar —el teléfono del plantel, el
# grupo de Participación, los datos del director del CDCEE— y otras que el
# colegio va a querer ajustar mientras esto se asienta.
#
# Con el PDF eso obliga a pedirnos un cambio y esperar. Con la planilla, el
# colegio abre, escribe lo que falta, imprime y sigue. **La versión editable no
# es un lujo mientras el formato esté en ajuste: es lo que evita que el colegio
# quede bloqueado por algo que nosotros todavía no modelamos.**
#
# Los datos son los MISMOS: los arma `CertificacionDeCalificaciones` y acá solo
# se decide cómo se ven. Es la razón por la que ese servicio está separado del
# dibujo.
class CertificacionXlsx
  # El ancho de la hoja: dos bloques de año de seis columnas, con una angosta en
  # el medio para separarlos.
  COLUMNAS = 13
  SEPARADORA = 6

  def initialize(datos)
    @d = datos
  end

  def to_stream = libro.to_stream

  def nombre_de_archivo
    apellidos = @d.dig("estudiante", "apellidos").to_s.parameterize.presence || "estudiante"

    "certificacion-31059-#{apellidos}.xlsx"
  end

  private

  def libro
    Axlsx::Package.new do |paquete|
      estilos(paquete.workbook)

      paquete.workbook.add_worksheet(name: "Certificación 31059") do |hoja|
        @hoja = hoja
        membrete
        seccion_i
        seccion_ii
        seccion_iii
        seccion_iv
        seccion_v
        seccion_vi
        firmas
        valor_fiscal
        ajustar
      end
    end
  end

  def estilos(libro)
    @titulo = libro.styles.add_style(sz: 14, b: true, alignment: { horizontal: :right })
    @membrete = libro.styles.add_style(sz: 8, b: true)
    @seccion = libro.styles.add_style(sz: 8, b: true, fg_color: "444444")
    @rotulo = libro.styles.add_style(sz: 8, b: true, alignment: { horizontal: :right })
    # ⚠️ Los valores llevan borde inferior a propósito: en el formato impreso hay
    # una línea guía debajo de cada campo, y quien lo llena a mano escribe sobre
    # ella. Acá cumple la misma función y además marca dónde se puede escribir.
    @valor = libro.styles.add_style(sz: 9, border: { style: :thin, color: "BBBBBB", edges: [ :bottom ] })
    @cabecera = libro.styles.add_style(sz: 8, b: true, bg_color: "EFEFEF",
                                       alignment: { horizontal: :center, vertical: :center, wrap_text: true },
                                       border: { style: :thin, color: "999999" })
    @celda = libro.styles.add_style(sz: 8, border: { style: :thin, color: "999999" })
    @centrada = libro.styles.add_style(sz: 8, alignment: { horizontal: :center },
                                       border: { style: :thin, color: "999999" })
    @ano = libro.styles.add_style(sz: 9, b: true, alignment: { horizontal: :center })
    @nota = libro.styles.add_style(sz: 7, i: true, fg_color: "777777")
  end

  # ── el membrete ───────────────────────────────────────────────────────────

  def membrete
    fila = @hoja.add_row([ "Gobierno Bolivariano de Venezuela", nil, nil, nil, nil, nil,
                           nil, "CERTIFICACIÓN DE CALIFICACIONES EMG" ] + vacias(5),
                         style: [ @membrete ] + Array.new(6) + [ @titulo ] + Array.new(5))
    @hoja.merge_cells "H#{fila.row_index + 1}:M#{fila.row_index + 1}"

    fila = @hoja.add_row([ "Ministerio del Poder Popular para la Educación", nil, nil, nil, nil, nil,
                           nil, "Código: #{@d.dig('plan', 'codigo')}" ] + vacias(5),
                         style: [ @membrete ] + Array.new(6) + [ @rotulo ] + Array.new(5))
    @hoja.merge_cells "H#{fila.row_index + 1}:M#{fila.row_index + 1}"
    @hoja.add_row
  end

  # ── I a III · los campos ──────────────────────────────────────────────────

  def seccion_i
    campos("I.  Plan de Estudio:", [
      [ "Plan de Estudio", @d.dig("plan", "nombre").to_s.upcase ],
      [ "Lugar y Fecha de Expedición", "#{@d.dig('expedida', 'en').to_s.upcase} #{fecha(@d.dig('expedida', 'el'))}" ]
    ])
  end

  def seccion_ii
    p_ = @d["plantel"]

    campos("II.  Datos de la Institución Educativa o Centro de Desarrollo de la Calidad Educativa " \
           "Estadal (CDCEE) que emite la Certificación:", [
             [ "Código", p_["codigo"] ], [ "Denominación del Epónimo", p_["nombre"].to_s.upcase ],
             [ "Dirección", p_["direccion"].to_s.upcase ], [ "Teléfono", p_["telefono"] ],
             [ "Municipio", p_["municipio"].to_s.upcase ],
             [ "Entidad Federal", p_["entidad_federal"].to_s.upcase ],
             [ "CDCEE", p_["cdcee"].to_s.upcase ]
           ])
  end

  def seccion_iii
    e = @d["estudiante"]
    identificador = e["documento"].present? ? "Cédula de Identidad" : "Cédula Escolar"

    campos("III.  Datos de identificación del Estudiante:", [
             [ identificador, e["documento"] || e["cedula_escolar"] ],
             [ "Fecha de Nacimiento", fecha(e["fecha_de_nacimiento"]) ],
             [ "Apellidos", e["apellidos"].to_s.upcase ], [ "Nombres", e["nombres"].to_s.upcase ],
             [ "Lugar de Nacimiento  País", e["pais_de_nacimiento"].to_s.upcase ],
             [ "Estado", e["estado_de_nacimiento"].to_s.upcase ],
             [ "Municipio", e["municipio_de_nacimiento"].to_s.upcase ]
           ])
  end

  # Los campos de una sección, de a dos por renglón.
  def campos(titulo, pares)
    encabezado_de_seccion(titulo)

    pares.each_slice(2) do |izquierdo, derecho|
      valores = [ izquierdo[0], izquierdo[1], nil, nil,
                  derecho&.first, derecho&.last, nil, nil ] + vacias(5)
      fila = @hoja.add_row(valores, style: [ @rotulo, @valor, @valor, @valor,
                                             @rotulo, @valor, @valor, @valor ] + Array.new(5))
      n = fila.row_index + 1
      @hoja.merge_cells "B#{n}:D#{n}"
      @hoja.merge_cells "F#{n}:H#{n}" if derecho
    end
    @hoja.add_row
  end

  # ── IV ────────────────────────────────────────────────────────────────────

  # ⚠️ Cinco renglones numerados, existan o no: los blancos son parte del
  # formato y acá además son las casillas donde el colegio escribe.
  RENGLONES_DE_PLANTELES = 5

  def seccion_iv
    encabezado_de_seccion("IV.  Instituciones Educativas donde Cursó Estudios:")
    cursados = Array(@d["planteles_cursados"])

    @hoja.add_row([ "Nº", "Denominación y Epónimo de la Institución Educativa", nil, nil,
                    "Localidad", "E.F." ] + vacias(7),
                  style: Array.new(6, @cabecera) + Array.new(7))
    @hoja.merge_cells "B#{@hoja.rows.last.row_index + 1}:D#{@hoja.rows.last.row_index + 1}"

    RENGLONES_DE_PLANTELES.times do |i|
      p_ = cursados[i]
      @hoja.add_row([ i + 1, p_ && p_["plantel"].to_s.upcase, nil, nil,
                      p_ && p_["localidad"].to_s.upcase, p_ && p_["entidad_federal"].to_s.upcase ] + vacias(7),
                    style: [ @centrada, @celda, @celda, @celda, @celda, @centrada ] + Array.new(7))
      n = @hoja.rows.last.row_index + 1
      @hoja.merge_cells "B#{n}:D#{n}"
    end
    @hoja.add_row
  end

  # ── V ─────────────────────────────────────────────────────────────────────

  def seccion_v
    encabezado_de_seccion("V.  Plan de Estudio:")
    bloques = Array(@d["anos"])

    if bloques.empty?
      @hoja.add_row [ "Sin calificaciones definitivas cargadas." ], style: [ @nota ]
      return
    end

    bloques.each_slice(2) { |izquierdo, derecho| par_de_recuadros(izquierdo, derecho) }
    areas_con_literal
  end

  ENCABEZADO_DE_ANO = [ "ÁREAS DE FORMACIÓN", "Nº", "Letras", "T-E", "Mes", "Año" ].freeze

  def par_de_recuadros(izquierdo, derecho)
    @hoja.add_row([ titulo_de_bloque(izquierdo), nil, nil, nil, nil, nil, nil,
                    titulo_de_bloque(derecho) ] + vacias(5),
                  style: [ @ano ] + Array.new(6) + [ @ano ] + Array.new(5))
    n = @hoja.rows.last.row_index + 1
    @hoja.merge_cells "A#{n}:F#{n}"
    @hoja.merge_cells "H#{n}:M#{n}" if derecho

    @hoja.add_row(ENCABEZADO_DE_ANO + [ nil ] + (derecho ? ENCABEZADO_DE_ANO : vacias(6)),
                  style: Array.new(6, @cabecera) + [ nil ] + Array.new(6, derecho ? @cabecera : nil))

    izq = Array(izquierdo && izquierdo["areas"])
    der = Array(derecho && derecho["areas"])

    [ izq.size, der.size ].max.times do |i|
      @hoja.add_row(celdas_de_area(izq[i]) + [ nil ] + celdas_de_area(der[i]),
                    style: estilo_de_area(izq[i]) + [ nil ] + estilo_de_area(der[i]))
    end
    @hoja.add_row
  end

  def titulo_de_bloque(bloque)
    return nil if bloque.nil?

    "#{bloque['ordinal']}  ·  #{bloque['periodo']}"
  end

  def celdas_de_area(area)
    return vacias(6) if area.nil?

    [ area["area"].to_s.upcase, area["numero"], area["letras"], area["te"], area["mes"], area["ano"] ]
  end

  def estilo_de_area(area)
    return Array.new(6) if area.nil?

    [ @celda, @centrada, @centrada, @centrada, @centrada, @centrada ]
  end

  # ⚠️ La columna GRUPO va VACÍA y editable.
  #
  # «Participación en Grupos» declara cuál grupo —manualidades, repostería,
  # gastronomía— y SIGA no lo modela. Inventarlo sería poner en un documento
  # oficial algo que nadie declaró; dejarlo en blanco en una planilla editable es
  # exactamente para lo que sirve esta versión.
  def areas_con_literal
    orientacion = Array(@d["orientacion_y_convivencia"])
    participacion = Array(@d["participacion_en_grupos"])
    return if orientacion.empty? && participacion.empty?

    @hoja.add_row([ "ORIENTACIÓN Y CONVIVENCIA", nil, nil, nil, nil, nil, nil,
                    "PARTICIPACIÓN EN GRUPOS DE CREACIÓN, RECREACIÓN Y PRODUCCIÓN" ] + vacias(5),
                  style: [ @ano ] + Array.new(6) + [ @ano ] + Array.new(5))
    n = @hoja.rows.last.row_index + 1
    @hoja.merge_cells "A#{n}:F#{n}"
    @hoja.merge_cells "H#{n}:M#{n}"

    @hoja.add_row([ "AÑO", "LITERAL", nil, nil, nil, nil, nil, "AÑO", "GRUPO", nil, nil, "LITERAL" ],
                  style: [ @cabecera, @cabecera ] + Array.new(5) + [ @cabecera, @cabecera, @cabecera, @cabecera, @cabecera ])

    [ orientacion.size, participacion.size ].max.times do |i|
      o = orientacion[i]
      p_ = participacion[i]
      @hoja.add_row([ o && o["ano"], o && o["literal"], nil, nil, nil, nil, nil,
                      p_ && p_["ano"], p_ && p_["grupo"], nil, nil, p_ && p_["literal"] ],
                    style: [ @centrada, @centrada ] + Array.new(5) +
                           [ @centrada, @celda, @celda, @celda, @centrada ])
    end
    @hoja.add_row
  end

  # ── VI a VIII ─────────────────────────────────────────────────────────────

  def seccion_vi
    promedio = @d.dig("observaciones", "promedio_academico")
    texto = promedio ? "Promedio Académico : #{format('%.2f', promedio)} Puntos" : nil

    encabezado_de_seccion("VI.  Observaciones:")
    @hoja.add_row([ texto ] + vacias(12), style: [ @valor ] + Array.new(12))
    @hoja.add_row
  end

  # Los dos bloques de firma. El del CDCEE va VACÍO porque lo llena la zona
  # educativa cuando el papel llega a su ventanilla, no nosotros.
  def firmas
    @hoja.add_row([ "VII.  Institución Educativa", nil, nil, nil, nil, nil, nil,
                    "VIII.  Centro de Desarrollo de la Calidad Educativa Estadal" ] + vacias(5),
                  style: [ @seccion ] + Array.new(6) + [ @seccion ] + Array.new(5))

    [ [ "Director (a)", nil, nil ],
      [ "Apellidos y Nombres", @d.dig("firmante", "nombre").to_s.upcase, nil ],
      [ "Cédula de Identidad", @d.dig("firmante", "documento"), nil ],
      [ "Firma", nil, nil ] ].each do |rotulo, izq, der|
      @hoja.add_row([ rotulo, izq, nil, nil, nil, nil, nil, rotulo, der ] + vacias(4),
                    style: [ @rotulo, @valor, @valor, @valor ] + Array.new(3) +
                           [ @rotulo, @valor, @valor, @valor ] + Array.new(2))
    end

    @hoja.add_row([ "Para efectos de su Validez Nacional", nil, nil, nil, nil, nil, nil,
                    "SELLO DEL CENTRO DE DESARROLLO DE LA CALIDAD EDUCATIVA ESTADAL" ] + vacias(5),
                  style: [ @nota ] + Array.new(6) + [ @nota ] + Array.new(5))
    @hoja.add_row
  end

  def valor_fiscal
    @hoja.add_row([ "VALOR FISCAL: Para su validez legal y de acuerdo al Ramo de Estampillas, a este " \
                    "documento se le debe colocar tres décimas de la Unidad Tributaria (0,3 U.T.)." ] + vacias(12),
                  style: [ @nota ] + Array.new(12))
  end

  # ── el andamiaje ──────────────────────────────────────────────────────────

  def encabezado_de_seccion(titulo)
    @hoja.add_row([ titulo ] + vacias(12), style: [ @seccion ] + Array.new(12))
    @hoja.merge_cells "A#{@hoja.rows.last.row_index + 1}:M#{@hoja.rows.last.row_index + 1}"
  end

  def vacias(cuantas) = Array.new(cuantas)

  def ajustar
    # El bloque de un año son seis columnas; la del medio solo separa.
    anchos = [ 28, 5, 13, 5, 5, 6 ]
    @hoja.column_widths(*(anchos + [ 2 ] + anchos))

    # Que quepa en una hoja al imprimir, que es para lo que se descarga.
    @hoja.page_setup.set(orientation: :portrait, fit_to_width: 1, paper_size: 1)
    @hoja.sheet_view.show_grid_lines = false
  end

  def fecha(iso)
    return "" if iso.blank?

    d = Date.parse(iso)
    "#{d.day} DE #{I18n.t('date.month_names')[d.month].upcase} DE #{d.year}"
  rescue Date::Error
    iso.to_s
  end
end
