# La Certificación de Calificaciones en papel — forma 31059 (MOR-99).
#
# ## Esto es una PLANILLA DE GOBIERNO, no un documento moderno
#
# La primera versión se dibujó desde la especificación escrita y salió limpia,
# aireada y con secciones tituladas. Después apareció un ejemplar real, lleno y
# sellado, y no se parecía: la 31059 es densa, con rótulos diminutos, líneas
# guía, campos numerados I a VIII y todo apretado en una hoja.
#
# **La diferencia importa.** Quien la recibe en la zona educativa la coteja
# contra la que conoce, y un documento que se ve distinto se devuelve aunque
# diga lo mismo. Se dibuja como es, no como se vería mejor.
#
#     I     plan de estudio · lugar y fecha de expedición
#     II    la institución que emite
#     III   identificación del estudiante
#     IV    instituciones donde cursó estudios
#     V     el plan de estudio: un recuadro por año, en dos columnas
#     VI    observaciones, con el promedio académico
#     VII   director del plantel + sello
#     VIII  director del CDCEE + sello del estado
class CertificacionPdf
  include DibujaDocumentosOficiales

  MARGEN = 22
  GRIS = "444444".freeze
  LINEA = "999999".freeze

  # El ancho de cada columna del recuadro de un año:
  # área · Nº · letras · T-E · mes · año
  COLUMNAS_DE_ANO = [ nil, 22, 62, 20, 22, 28 ].freeze

  def initialize(datos)
    @d = datos
  end

  def render
    pdf = Prawn::Document.new(page_size: "LETTER", margin: MARGEN, info: {
      Title: "Certificación de Calificaciones EMG", Creator: "SIGA", CreationDate: Time.current
    })

    membrete(pdf)
    seccion_i(pdf)
    seccion_ii(pdf)
    seccion_iii(pdf)
    seccion_iv(pdf)
    seccion_v(pdf)
    seccion_vi(pdf)
    firmas(pdf)
    valor_fiscal(pdf)

    pdf.render
  end

  private

  # ── el membrete ───────────────────────────────────────────────────────────

  def membrete(pdf)
    pdf.bounding_box([ 0, pdf.cursor ], width: pdf.bounds.width * 0.5) do
      pdf.text "Gobierno Bolivariano de Venezuela", size: 7, style: :bold
      pdf.text "Ministerio del Poder Popular para la Educación", size: 7
    end

    pdf.move_up 22
    pdf.text "CERTIFICACIÓN DE CALIFICACIONES EMG", size: 12, style: :bold, align: :right
    pdf.text "Código: #{texto(@d.dig('plan', 'codigo'))}", size: 8, align: :right
    pdf.move_down 6
  end

  # ── I ─────────────────────────────────────────────────────────────────────

  def seccion_i(pdf)
    plan = @d["plan"]
    expedida = @d["expedida"]

    renglon(pdf, [
      [ "I.  Plan de Estudio:", plan["nombre"].to_s.upcase, 300 ],
      [ "Lugar y Fecha de Expedición:", "#{texto(expedida['en']).upcase} #{fecha_larga(expedida['el'])}", nil ]
    ])
  end

  # ── II ────────────────────────────────────────────────────────────────────

  def seccion_ii(pdf)
    p_ = @d["plantel"]

    titulo(pdf, "II.  Datos de la Institución Educativa o Centro de Desarrollo de la Calidad " \
                "Educativa Estadal (CDCEE) que emite la Certificación:")
    renglon(pdf, [ [ "Código:", p_["codigo"], 150 ],
                   [ "Denominación del Epónimo:", p_["nombre"].to_s.upcase, nil ] ])
    renglon(pdf, [ [ "Dirección:", p_["direccion"].to_s.upcase, 330 ],
                   [ "Teléfono:", p_["telefono"], nil ] ])
    renglon(pdf, [ [ "Municipio:", p_["municipio"].to_s.upcase, 180 ],
                   [ "Entidad Federal:", p_["entidad_federal"].to_s.upcase, 180 ],
                   [ "CDCEE:", p_["cdcee"].to_s.upcase, nil ] ])
  end

  # ── III ───────────────────────────────────────────────────────────────────

  def seccion_iii(pdf)
    e = @d["estudiante"]

    titulo(pdf, "III.  Datos de identificación del Estudiante:")
    renglon(pdf, [
      # ⚠️ El rótulo dice CUÁL identificador es: la cédula escolar la asigna el
      # MPPE a quien todavía no sacó la de identidad, y quien recibe el documento
      # va a cotejar contra el SAIME.
      [ e["documento"].present? ? "Cédula de Identidad:" : "Cédula Escolar:",
        e["documento"] || e["cedula_escolar"], 260 ],
      [ "Fecha de Nacimiento:", fecha_larga(e["fecha_de_nacimiento"]), nil ]
    ])
    renglon(pdf, [ [ "Apellidos:", e["apellidos"].to_s.upcase, 260 ],
                   [ "Nombres:", e["nombres"].to_s.upcase, nil ] ])
    renglon(pdf, [ [ "Lugar de Nacimiento  País:", e["pais_de_nacimiento"].to_s.upcase, 200 ],
                   [ "Estado:", e["estado_de_nacimiento"].to_s.upcase, 160 ],
                   [ "Municipio:", e["municipio_de_nacimiento"].to_s.upcase, nil ] ])
  end

  # ── IV ────────────────────────────────────────────────────────────────────

  # ⚠️ Cinco renglones numerados, existan o no.
  #
  # El formato los trae impresos y quien lo llena a mano escribe sobre los que
  # necesita. Un alumno que hizo todo en un plantel deja cuatro en blanco, y esos
  # blancos son parte del documento: si se dibujaran solo los usados, el papel
  # dejaría de coincidir con el que la zona educativa conoce.
  RENGLONES_DE_PLANTELES = 5

  def seccion_iv(pdf)
    titulo(pdf, "IV.  Instituciones Educativas donde Cursó Estudios:")
    cursados = Array(@d["planteles_cursados"])

    filas = RENGLONES_DE_PLANTELES.times.map do |i|
      p_ = cursados[i]
      [ (i + 1).to_s,
        texto(p_ && p_["plantel"].to_s.upcase),
        texto(p_ && p_["localidad"].to_s.upcase),
        texto(p_ && abreviar_entidad(p_["entidad_federal"])) ]
    end

    mitad = (RENGLONES_DE_PLANTELES / 2.0).ceil
    encabezado = [ "Nº", "Denominación y Epónimo de la Institución Educativa", "Localidad", "E.F." ]

    pdf.table([ encabezado + encabezado ] + emparejar(filas, mitad),
              width: pdf.bounds.width, header: true,
              cell_style: { size: 5.5, padding: [ 2, 3 ], border_color: LINEA, height: 13 }) do
      row(0).font_style = :bold
      row(0).align = :center
      [ 0, 4 ].each { |i| columns(i).width = 16 }
      [ 2, 6 ].each { |i| columns(i).width = 62 }
      [ 3, 7 ].each { |i| columns(i).width = 22 }
    end
    pdf.move_down 4
  end

  # ── V ─────────────────────────────────────────────────────────────────────

  def seccion_v(pdf)
    pdf.text "V.  Plan de Estudio:", size: 6.5, style: :bold, color: GRIS
    pdf.move_down 2

    bloques = Array(@d["anos"])
    if bloques.empty?
      pdf.text "Sin calificaciones definitivas cargadas.", size: 7, color: GRIS
      return
    end

    # Dos recuadros por renglón, como el formato: primero–segundo, tercero–cuarto,
    # quinto–y las áreas con literal.
    bloques.each_slice(2) { |par| par_de_recuadros(pdf, par[0], par[1]) }

    areas_con_literal(pdf)
  end

  # ⚠️ Se mide con `pdf.y`, no con `pdf.cursor`.
  #
  # Dentro de un `bounding_box`, `cursor` es relativo a LA CAJA y no a la página,
  # así que `arriba - cursor` no da la altura de lo dibujado: da la distancia al
  # fondo de una caja que, sin `height`, ocupa todo lo que queda de hoja. Con eso
  # el cursor terminaba al pie de la página y el resto del documento —tres años,
  # las tablitas de literal y las secciones VI a VIII— se dibujaba fuera.
  #
  # `y` es absoluto y baja: de las dos columnas se toma la MENOR, que es la que
  # llegó más abajo.
  def par_de_recuadros(pdf, izquierdo, derecho)
    ancho = (pdf.bounds.width - 8) / 2.0
    arriba = pdf.y

    pdf.bounding_box([ 0, arriba - pdf.bounds.absolute_bottom ], width: ancho) do
      recuadro_de_ano(pdf, izquierdo, ancho)
    end
    izquierda = pdf.y

    if derecho
      pdf.y = arriba
      pdf.bounding_box([ ancho + 8, arriba - pdf.bounds.absolute_bottom ], width: ancho) do
        recuadro_de_ano(pdf, derecho, ancho)
      end
    end

    pdf.y = [ izquierda, pdf.y ].min - 5
  end

  def recuadro_de_ano(pdf, bloque, ancho)
    return if bloque.nil?

    pdf.text "#{texto(bloque['ordinal'])}  ·  #{texto(bloque['periodo'])}",
             size: 6.5, style: :bold, align: :center
    pdf.move_down 1

    filas = [ [ "ÁREAS DE\nFORMACIÓN", "Nº", "Letras", "T-E", "Mes", "Año" ] ]
    Array(bloque["areas"]).each do |a|
      filas << [ texto(a["area"]).upcase, a["numero"].to_s, texto(a["letras"]),
                 a["te"], a["mes"], a["ano"].to_s ]
    end

    pdf.table(filas, width: ancho, header: true,
                     cell_style: { size: 5.5, padding: [ 2, 2 ], border_color: LINEA }) do
      row(0).font_style = :bold
      row(0).align = :center
      row(0).background_color = "F0F0F0"
      COLUMNAS_DE_ANO.each_with_index { |a, i| columns(i).width = a if a }
      columns(1..5).align = :center
    end
  end

  # ⚠️ Las dos áreas que salen de la tabla y van en sus propias tablitas, por año.
  #
  # «Participación en Grupos» además declara CUÁL grupo —MANUALIDADES, REPOSTERÍA,
  # GASTRONOMÍA— y eso SIGA no lo modela: la casilla queda en blanco para que el
  # colegio la escriba.
  def areas_con_literal(pdf)
    orientacion = Array(@d["orientacion_y_convivencia"])
    participacion = Array(@d["participacion_en_grupos"])
    return if orientacion.empty? && participacion.empty?

    ancho = (pdf.bounds.width - 8) / 2.0
    arriba = pdf.y

    pdf.bounding_box([ 0, arriba - pdf.bounds.absolute_bottom ], width: ancho) do
      tablita(pdf, "ORIENTACIÓN Y CONVIVENCIA", [ "AÑO", "LITERAL" ],
              orientacion.map { |o| [ o["ano"], o["literal"] ] }, ancho)
    end
    izquierda = pdf.y

    pdf.y = arriba
    pdf.bounding_box([ ancho + 8, arriba - pdf.bounds.absolute_bottom ], width: ancho) do
      tablita(pdf, "PARTICIPACIÓN EN GRUPOS DE\nCREACIÓN, RECREACIÓN Y PRODUCCIÓN",
              [ "AÑO", "GRUPO", "LITERAL" ],
              participacion.map { |p_| [ p_["ano"], texto(p_["grupo"]), p_["literal"] ] }, ancho)
    end

    pdf.y = [ izquierda, pdf.y ].min
  end

  def tablita(pdf, titulo, encabezado, filas, ancho)
    return if filas.empty?

    pdf.text titulo, size: 6, style: :bold, align: :center
    pdf.move_down 1

    pdf.table([ encabezado ] + filas, width: ancho, header: true,
                                      cell_style: { size: 5.5, padding: [ 2, 2 ], align: :center,
                                                    border_color: LINEA }) do
      row(0).font_style = :bold
      row(0).background_color = "F0F0F0"
    end
  end

  # ── VI ────────────────────────────────────────────────────────────────────

  def seccion_vi(pdf)
    pdf.move_down 5
    promedio = @d.dig("observaciones", "promedio_academico")

    pdf.text "VI.  Observaciones:  " \
             "#{promedio ? "Promedio Académico : #{format('%.2f', promedio)} Puntos" : ''}",
             size: 6.5, style: :bold, color: GRIS
    pdf.move_down 4
  end

  # ── VII y VIII ────────────────────────────────────────────────────────────

  # ⚠️ Son DOS firmas, no una: el plantel certifica y el CDCEE avala.
  #
  # La del estado no la puede poner SIGA —la estampa la zona educativa cuando el
  # papel llega a su ventanilla— así que el bloque va dibujado y en blanco, que
  # es como sale de la impresora de cualquier colegio.
  def firmas(pdf)
    ancho = (pdf.bounds.width - 8) / 2.0
    pdf.move_down 4
    arriba = pdf.cursor

    pdf.bounding_box([ 0, arriba ], width: ancho, height: 96) do
      pdf.stroke_color LINEA
      pdf.stroke_bounds
      pdf.move_down 3
      pdf.indent(4) do
        pdf.text "VII.  Institución Educativa", size: 6.5, style: :bold, color: GRIS
        pdf.text "Director (a)", size: 6, align: :center
        bloque_de_firma(pdf, @d.dig("firmante", "nombre"), @d.dig("firmante", "documento"))
      end
    end

    pdf.bounding_box([ ancho + 8, arriba ], width: ancho, height: 96) do
      pdf.stroke_color LINEA
      pdf.stroke_bounds
      pdf.move_down 3
      pdf.indent(4) do
        pdf.text "VIII.  Centro de Desarrollo de la Calidad Educativa Estadal", size: 6.5,
                 style: :bold, color: GRIS
        pdf.text "Director (a)", size: 6, align: :center
        bloque_de_firma(pdf, nil, nil)
        pdf.text "SELLO DEL CENTRO DE DESARROLLO", size: 5, align: :center, color: GRIS
        pdf.text "DE LA CALIDAD EDUCATIVA ESTADAL", size: 5, align: :center, color: GRIS
      end
    end

    pdf.move_cursor_to arriba - 100
  end

  def bloque_de_firma(pdf, nombre, documento)
    pdf.move_down 2
    pdf.text "Apellidos y Nombres : #{texto(nombre).upcase}", size: 6
    pdf.text "Cédula de Identidad : #{texto(documento)}", size: 6
    pdf.move_down 12
    pdf.text "Firma :", size: 6
    pdf.move_down 10
    pdf.text "Para efectos de su Validez Nacional", size: 5, color: GRIS
  end

  # ── el pie fiscal ─────────────────────────────────────────────────────────

  # ⚠️ Va impreso porque está en el formato: sin la estampilla el documento no
  # tiene validez legal, y quien lo recibe sin ella lo devuelve.
  def valor_fiscal(pdf)
    pdf.move_down 4
    pdf.text "VALOR FISCAL: Para su validez legal y de acuerdo al Ramo de Estampillas, a este " \
             "documento se le debe colocar tres décimas de la Unidad Tributaria (0,3 U.T.).",
             size: 5, color: GRIS
  end

  # ── el andamiaje ──────────────────────────────────────────────────────────

  def titulo(pdf, texto_del_titulo)
    pdf.move_down 3
    pdf.text texto_del_titulo, size: 6.5, style: :bold, color: GRIS
    pdf.move_down 1
  end

  # Un renglón de campos con su rótulo y una línea guía debajo del valor, como
  # los que trae el formato impreso.
  def renglon(pdf, campos)
    alto = 11
    x = 0
    arriba = pdf.cursor

    campos.each do |rotulo, valor, ancho|
      ancho ||= pdf.bounds.width - x
      pdf.bounding_box([ x, arriba ], width: ancho, height: alto) do
        pdf.text_box texto(rotulo), size: 6, style: :bold, color: GRIS, at: [ 0, alto ], height: alto
        rotulo_ancho = pdf.width_of(texto(rotulo), size: 6, style: :bold) + 4
        pdf.text_box texto(valor.presence || ""), size: 6.5,
                     at: [ rotulo_ancho, alto ], width: ancho - rotulo_ancho - 4, height: alto
        pdf.stroke_color LINEA
        pdf.stroke_line [ rotulo_ancho, 1 ], [ ancho - 4, 1 ]
      end
      x += ancho
    end

    pdf.move_cursor_to arriba - alto - 2
  end

  # Dos bloques de renglones lado a lado, como la sección IV.
  def emparejar(filas, mitad)
    izquierda = filas.first(mitad)
    derecha = filas.drop(mitad)

    izquierda.each_with_index.map { |f, i| f + (derecha[i] || [ "", "", "", "" ]) }
  end

  # «E.F.» es la entidad federal abreviada: ZULIA → ZU, como en el ejemplar real.
  # Sale del dato del colegio y no de partir un texto libre: «Caracas, Distrito
  # Capital» daba «DIS», que no es la abreviatura de nada.
  def abreviar_entidad(entidad)
    return nil if entidad.blank?

    entidad.to_s.strip.upcase[0, 2]
  end

  def fecha_larga(iso)
    return "" if iso.blank?

    fecha = Date.parse(iso)
    "#{fecha.day} DE #{I18n.t('date.month_names')[fecha.month].upcase} DE #{fecha.year}"
  rescue Date::Error
    iso.to_s
  end

  def colegio
    @colegio ||= Current.sin_aislamiento { School.find_by(dea_code: @d.dig("plantel", "codigo")) }
  end
end
