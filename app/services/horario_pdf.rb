# El horario en papel: la hoja de la foto que mandó Daniel (IMG_3975), impresa
# por SIGA (spec `horarios`, decisión 27).
#
#     ┌──────────────────────────────────────────────────────────────────────┐
#     │ [escudo] U.E. SIMÓN BOLÍVAR                       HORARIO DE CLASES  │
#     │          Caracas · Código DEA OD00000000                  2025-2026  │
#     │ ──────────────────────────────────────────────────────────────────── │
#     │ 1er Año A                          Publicado el 22 de octubre de 2026 │
#     │ Turno de la mañana, de 7:10 a. m. a 1:00 p. m. · 38 horas · guía      │
#     │            LUNES      MARTES     MIÉRCOLES  JUEVES     VIERNES       │
#     │ 1ra 7:10  ┃Arte      ┃Inglés    ┃…                                   │
#     │ 2da 7:50  ┃Colmenares┃López     ┃          ← el bloque de 80 min, unido │
#     │ ───────────────── RECESO · 9:50 – 10:20 ──────────────────────────── │
#     │ ÁREAS Y PROFESORES  ┃Arte · Colmenares, Luis · 2 h  ┃Inglés · …       │
#     └──────────────────────────────────────────────────────────────────────┘
#
#     HorarioPdf::DeLaSeccion   cada casilla: el área y el profesor
#     HorarioPdf::DelProfesor   cada casilla: la sección y el área
#
# Dibuja la MISMA `RejillaDeHorarios` que la pantalla —sus casillas, sus
# bloques unidos y su receso—, así que el papel no puede decir otra cosa.
#
# ## ⚠️ Una hoja, siempre
#
# Es una hoja carta ACOSTADA, como la foto: cinco días a lo ancho. Lo que se
# reparte es el alto, y se calcula al revés —primero lo que va arriba y abajo,
# y la rejilla toma lo que queda—. El pie no se mide escribiéndolo: cada
# renglón se dibuja con su alto fijo, así que la cuenta es exacta.
#
# ## ⚠️ Poca tinta
#
# Nada va relleno. El área es una raya fina de su color, como en la pantalla:
# la decisión del boletín —*«si se va a imprimir se gasta menos tinta»*—. Y en
# borrador lo dice arriba y atravesado: uno pegado en la pared tiene que
# poder distinguirse del publicado de un vistazo.
class HorarioPdf
  include DibujaDocumentosOficiales

  MARGEN = 30
  NEGRO = "000000".freeze
  GRIS = "666666".freeze
  LINEA = "B8B8B8".freeze
  RECESO = "F2F2F2".freeze
  MARCA_DE_AGUA = "EBEBEB".freeze

  ALTO_DEL_MEMBRETE = 44
  ANCHO_DE_LA_HORA = 60
  ALTO_DE_LOS_DIAS = 16
  ALTO_DEL_RECESO = 15
  ALTO_DE_UN_RENGLON = 11
  COLUMNAS_DEL_PIE = 3

  def initialize(rejilla, colegio:)
    @rejilla = rejilla
    @colegio = colegio
  end

  def render
    pdf = Prawn::Document.new(page_size: "LETTER", page_layout: :landscape, margin: MARGEN,
                              info: { Title: texto("Horario de clases · #{titulo} · #{anio.name}"),
                                      Creator: "SIGA", CreationDate: Time.current })
    membrete(pdf)
    cabeza(pdf)
    semana(pdf, alto: pdf.cursor - alto_del_pie)
    pie(pdf)
    pdf.render
  end

  def nombre_de_archivo = "horario-#{titulo.parameterize}-#{anio.name.parameterize}.pdf"

  private

  # ── Lo que cambia según de quién es la hoja ──────────────────────────────
  #
  #     titulo           «1er Año A» o «García Pérez, Carlos»
  #     anio             el año escolar
  #     detalle          el turno y las horas, debajo del título
  #     estado           a la derecha del título (publicado o borrador)
  #     contenido(celda) [lo de arriba, lo de abajo, el área] de una casilla
  #     leyenda          [[texto, área]] del pie
  #     titulo_del_pie   «Áreas y profesores» o «Secciones y áreas»
  #     nota             lo que hay que saber antes de pegarla en la pared

  def borrador? = false
  def nota = nil

  # ── El membrete ──────────────────────────────────────────────────────────

  def membrete(pdf)
    arriba = pdf.cursor
    izquierda = escudo(pdf, arriba) ? 52 : 0

    pdf.bounding_box([ izquierda, arriba ], width: pdf.bounds.width - izquierda - 210, height: ALTO_DEL_MEMBRETE) do
      pdf.text texto(@colegio.name).upcase, size: 13, style: :bold
      donde = [ @colegio.location.presence, ("Código DEA #{@colegio.dea_code}" if @colegio.dea_code.present?) ].compact
      pdf.text texto(donde.join(" · ")), size: 8, color: GRIS if donde.any?
    end

    pdf.bounding_box([ pdf.bounds.width - 200, arriba ], width: 200, height: ALTO_DEL_MEMBRETE) do
      pdf.text "HORARIO DE CLASES", size: 11, style: :bold, align: :right, character_spacing: 1
      pdf.text texto(anio.name), size: 9, align: :right, color: GRIS
    end

    pdf.stroke_color LINEA
    pdf.line_width 0.75
    pdf.stroke_horizontal_rule
    pdf.move_down 9
  end

  # El escudo, si el colegio lo cargó: un horario no se cae por un logo.
  #
  # ⚠️ El `rescue` va DENTRO del `bounding_box` (`DibujaDocumentosOficiales`):
  # si la excepción escapa del bloque, Prawn no restaura los límites de la
  # página y el resto de la hoja se dibuja dentro de la caja del escudo.
  def escudo(pdf, arriba)
    imagen = @colegio.logo_para_pdf
    return false unless imagen

    dibujado = false
    pdf.bounding_box([ 0, arriba ], width: 44, height: ALTO_DEL_MEMBRETE) do
      pdf.image imagen, fit: [ 42, 42 ], position: :left, vposition: :top
      dibujado = true
    rescue StandardError
      dibujado = false
    end
    dibujado
  end

  # ── De quién es, y en qué está ───────────────────────────────────────────

  def cabeza(pdf)
    arriba = pdf.cursor
    ancho_del_estado = 300

    pdf.bounding_box([ 0, arriba ], width: pdf.bounds.width - ancho_del_estado) do
      pdf.text texto(titulo), size: 15, style: :bold
      pdf.text texto(detalle), size: 8.5, color: GRIS
    end
    abajo = pdf.cursor

    if estado.present?
      con_color(pdf, borrador? ? NEGRO : GRIS) do
        pdf.text_box texto(estado), at: [ pdf.bounds.width - ancho_del_estado, arriba - 3 ], width: ancho_del_estado,
                                    height: 14, size: 9, align: :right, style: (borrador? ? :bold : :normal),
                                    overflow: :shrink_to_fit
      end
    end

    pdf.move_cursor_to abajo
    pdf.move_down 8
  end

  # ── La semana ────────────────────────────────────────────────────────────

  def semana(pdf, alto:)
    filas = @rejilla.filas
    recesos = filas.count(&:receso?)
    alto_de_la_hora = ((alto - ALTO_DE_LOS_DIAS - (recesos * ALTO_DEL_RECESO)) / [ filas.size - recesos, 1 ].max)
                      .clamp(18, 52)
    ancho_del_dia = (pdf.bounds.width - ANCHO_DE_LA_HORA) / @rejilla.dias.size
    arriba = pdf.cursor
    alto_de_la_rejilla = filas.sum { |fila| fila.receso? ? ALTO_DEL_RECESO : alto_de_la_hora }

    marca_de_borrador(pdf, arriba - ALTO_DE_LOS_DIAS, alto_de_la_rejilla) if borrador?

    @rejilla.dias.each_with_index do |dia, i|
      pdf.text_box Lesson::DIAS[dia - 1].upcase, at: [ ANCHO_DE_LA_HORA + (i * ancho_del_dia), arriba ],
                                                 width: ancho_del_dia, height: ALTO_DE_LOS_DIAS, size: 8, style: :bold,
                                                 align: :center, valign: :center, character_spacing: 0.8
    end

    y = arriba - ALTO_DE_LOS_DIAS
    filas.each do |fila|
      if fila.receso?
        receso(pdf, fila, y)
        y -= ALTO_DEL_RECESO
        next
      end

      rotulo_de_la_hora(pdf, fila, y, alto_de_la_hora)
      @rejilla.dias.each_with_index do |dia, i|
        next if @rejilla.tapada?(dia, fila.numero)

        alto_de_la_casilla = @rejilla.unida?(dia, fila.numero) ? alto_de_la_hora * 2 : alto_de_la_hora
        casilla(pdf, @rejilla.celda(dia, fila.numero), x: ANCHO_DE_LA_HORA + (i * ancho_del_dia), y: y,
                                                       ancho: ancho_del_dia, alto: alto_de_la_casilla)
      end
      y -= alto_de_la_hora
    end

    pdf.move_cursor_to y
    pdf.move_down 10
  end

  def rotulo_de_la_hora(pdf, fila, y, alto)
    pdf.formatted_text_box([ { text: TimeSlot::ORDINALES[fila.numero].to_s, styles: [ :bold ] },
                             { text: "\n#{fila.hora.rango}", color: GRIS } ],
                           at: [ 0, y - 2 ], width: ANCHO_DE_LA_HORA - 6, height: alto - 4, size: 8,
                           valign: :center, overflow: :shrink_to_fit, min_font_size: 5)
  end

  def receso(pdf, fila, y)
    con_color(pdf, RECESO) { pdf.fill_rectangle [ 0, y ], pdf.bounds.width, ALTO_DEL_RECESO }
    con_color(pdf, GRIS) do
      pdf.text_box "RECESO · #{fila.hora.rango}", at: [ 0, y ], width: pdf.bounds.width, height: ALTO_DEL_RECESO,
                                                  size: 7.5, style: :bold, align: :center, valign: :center,
                                                  character_spacing: 1.2
    end
  end

  def casilla(pdf, celda, x:, y:, ancho:, alto:)
    pdf.stroke_color LINEA
    pdf.line_width 0.5
    pdf.stroke_rectangle [ x, y ], ancho, alto

    arriba, abajo, materia = contenido(celda)
    return if arriba.nil?

    con_color(pdf, color_de(materia)) { pdf.fill_rectangle [ x + 0.25, y - 0.25 ], 3, alto - 0.5 }
    pdf.formatted_text_box([ { text: texto(arriba), styles: [ :bold ] }, { text: "\n#{texto(abajo)}", color: GRIS } ],
                           at: [ x + 8, y - 3 ], width: ancho - 12, height: alto - 6, size: 9,
                           valign: :center, overflow: :shrink_to_fit, min_font_size: 5.5)
  end

  # Atravesada y clarita, DEBAJO de las casillas: se lee el horario y se ve que
  # no es el definitivo.
  def marca_de_borrador(pdf, arriba, alto)
    con_color(pdf, MARCA_DE_AGUA) do
      pdf.text_box "BORRADOR", at: [ ANCHO_DE_LA_HORA, arriba ], width: pdf.bounds.width - ANCHO_DE_LA_HORA,
                               height: alto, size: 110, style: :bold, align: :center, valign: :center,
                               rotate: 14, rotate_around: :center, overflow: :shrink_to_fit
    end
  end

  # ── El pie ───────────────────────────────────────────────────────────────

  def renglones_del_pie = (leyenda.size.to_f / COLUMNAS_DEL_PIE).ceil

  # Cada renglón se dibuja con su alto fijo: esto es lo que el pie va a ocupar.
  def alto_del_pie
    leyenda_alto = leyenda.any? ? 13 + (renglones_del_pie * ALTO_DE_UN_RENGLON) : 0
    leyenda_alto + (nota ? ALTO_DE_UN_RENGLON : 0) + ALTO_DE_UN_RENGLON + 4
  end

  def pie(pdf)
    if leyenda.any?
      pdf.text titulo_del_pie.upcase, size: 7.5, style: :bold, character_spacing: 0.8, color: GRIS
      pdf.move_down 3
      ancho = pdf.bounds.width / COLUMNAS_DEL_PIE
      leyenda.each_slice(COLUMNAS_DEL_PIE) do |renglon|
        y = pdf.cursor
        renglon.each_with_index do |(linea, materia), i|
          x = i * ancho
          con_color(pdf, color_de(materia)) { pdf.fill_rectangle [ x, y - 1 ], 3, 8 }
          pdf.text_box texto(linea), at: [ x + 7, y ], width: ancho - 14, height: ALTO_DE_UN_RENGLON,
                                     size: 7.5, overflow: :shrink_to_fit, min_font_size: 5
        end
        pdf.move_down ALTO_DE_UN_RENGLON
      end
    end

    if nota
      pdf.text_box texto(nota), at: [ 0, pdf.cursor ], width: pdf.bounds.width, height: ALTO_DE_UN_RENGLON,
                                size: 7.5, style: :bold, overflow: :shrink_to_fit
      pdf.move_down ALTO_DE_UN_RENGLON
    end

    pdf.move_down 4
    con_color(pdf, GRIS) do
      pdf.text_box "Impreso desde SIGA el #{fecha_larga(HoraDeVenezuela.ahora.to_date)}", at: [ 0, pdf.cursor ],
                   width: pdf.bounds.width, height: ALTO_DE_UN_RENGLON, size: 7
    end
  end

  # ── Lo que comparten las dos ─────────────────────────────────────────────

  # ⚠️ `text_box` NO lee `color:` —lo descarta sin avisar—: el texto se pinta
  # con el color de relleno del documento, y aquí se pone y se devuelve.
  def con_color(pdf, color)
    pdf.fill_color color
    yield
  ensure
    pdf.fill_color NEGRO
  end

  def color_de(materia) = (@colores ||= HorariosHelper.colores_de_las_areas).fetch(materia.id, HorariosHelper::COLORES_DE_AREA.first).delete("#")

  def turno = HorariosHelper.resumen_del_turno(@rejilla.turno)

  def fecha_larga(fecha) = "#{fecha.day} de #{I18n.t('date.month_names')[fecha.month]} de #{fecha.year}"

  def horas(cuantas) = cuantas == 1 ? "1 hora" : "#{cuantas} horas"

  # ══════════════════════════════════════════════════════════════════════════

  class DeLaSeccion < HorarioPdf
    private

    def seccion = @rejilla.seccion
    def carga = @rejilla.carga
    def anio = seccion.academic_period
    def titulo = ChoquesDeHorario.nombre_de(seccion)
    def borrador? = seccion.timetable_published_at.nil?
    def titulo_del_pie = "Áreas y profesores"

    def detalle
      horas_de_la_semana = carga.faltan.zero? ? "#{horas(carga.total)} a la semana" : "#{carga.ubicadas} de #{horas(carga.total)} ubicadas"
      guia = seccion.leader_teacher && "Profesor guía: #{seccion.leader_teacher.user.apellidos_y_nombres}"
      [ turno, horas_de_la_semana, guia ].compact.join(" · ")
    end

    def estado
      return "BORRADOR · sus profesores y sus familias todavía no lo ven" if borrador?

      "Publicado el #{fecha_larga(seccion.timetable_published_at.in_time_zone(HoraDeVenezuela::ZONA).to_date)}"
    end

    def contenido(celda)
      return unless celda.tipo == :clase

      clase = celda.datos[:clase]
      [ clase.subject.name, clase.teacher ? ChoquesDeHorario.apellido_de(clase.teacher) : "sin profesor", clase.subject ]
    end

    # Las áreas con horas o con clases: «Inglés · López Díaz, María · 4 h», o
    # «2 de 4 h» mientras falten.
    def leyenda
      @leyenda ||= carga.areas.reject { |area| area.sin_horas? && area.ubicadas.zero? }.map do |area|
        quien = area.profesor ? area.profesor.user.apellidos_y_nombres : "sin profesor"
        cuantas = area.completa? || area.sin_horas? ? "#{area.ubicadas} h" : "#{area.ubicadas} de #{area.horas} h"
        [ "#{area.materia.name} · #{quien} · #{cuantas}", area.materia ]
      end
    end
  end

  class DelProfesor < HorarioPdf
    def initialize(rejilla, profesor:, anio:, colegio:)
      super(rejilla, colegio:)
      @profesor = profesor
      @anio = anio
    end

    private

    attr_reader :anio

    def clases = @rejilla.clases
    def titulo = @profesor.user.apellidos_y_nombres
    def titulo_del_pie = "Secciones y áreas"
    def estado = nil

    def detalle
      areas = clases.map { |clase| clase.subject.name }.uniq.sort
      [ turno, "#{horas(clases.size)} a la semana", areas.to_sentence.presence ].compact.join(" · ")
    end

    def contenido(celda)
      return unless celda.tipo == :del_profesor

      clase = celda.datos[:clase]
      [ ChoquesDeHorario.nombre_de(clase.section), clase.subject.name, clase.subject ]
    end

    # «1er Año A · Matemática · 4 h», en el orden de los grados.
    def leyenda
      @leyenda ||= clases.group_by { |clase| [ clase.section, clase.subject ] }
                         .sort_by { |(seccion, materia), _| [ seccion.grade.orden || 99, seccion.grade.name, seccion.name, materia.name ] }
                         .map { |(seccion, materia), suyas| [ "#{ChoquesDeHorario.nombre_de(seccion)} · #{materia.name} · #{suyas.size} h", materia ] }
    end

    # Lo que dicta en una sección todavía en borrador puede cambiar: la hoja
    # del director lo dice, y la del profesor ni lo trae (`solo_publicadas`).
    def nota
      en_borrador = clases.map(&:section).uniq.select { |seccion| seccion.timetable_published_at.nil? }
      return if en_borrador.empty?

      nombres = en_borrador.map { |seccion| ChoquesDeHorario.nombre_de(seccion) }.sort.to_sentence
      verbo = en_borrador.one? ? "sigue" : "siguen"
      "#{nombres} #{verbo} en borrador: esas clases todavía pueden cambiar."
    end
  end
end
