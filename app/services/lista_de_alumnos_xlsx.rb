# La lista de alumnos de una sección —o de todas—, en Excel.
#
# ## Por qué hace falta, si la pantalla ya la muestra
#
# Un colegio venezolano vive de listas en papel: la de la cartelera, la de
# coordinación, la de la salida pedagógica, la que se manda al MPPE. La de SIGA
# estaba SOLO en pantalla, así que la secretaria la volvía a tipear en Excel — y
# desde ahí las dos listas empiezan a separarse, que es peor que no tenerla.
#
#     ┌──────────────────────────────────────────────────────────────────┐
#     │ ╭───╮  U.E. SIMÓN BOLÍVAR                                        │
#     │ │ ⬤ │  Libertador, Distrito Capital · DEA PD000001               │
#     │ ╰───╯  Lista de alumnos · 1er Grado – A · 2025-2026              │
#     │        22 inscritos · guía: Moreno, Sofía · al 11 de sep de 2026 │
#     ├───┬──────────────┬───────────┬─────┬──────┬─────────────────────┤
#     │ # │ APELLIDOS    │ NOMBRES   │ C.I.│ SEXO │ REPRESENTANTE   …   │  ← congelada
#     │ 1 │ Aponte Reyes │ Eduardo   │V-30…│  M   │ Daniela Aponte  …   │
#     │ 2 │ Cabrera Ap.  │ Tomás     │V-30…│  M   │ Luis Cabrera    …   │  ← cebra
#     └───┴──────────────┴───────────┴─────┴──────┴─────────────────────┘
#
# ## ⚠️ `.xlsx` de verdad, no un CSV con otro nombre
#
# Un CSV no dice con qué está separado, y Excel en español NO usa coma: el
# archivo abre con todo en una columna o con los acentos rotos. Es el mismo
# problema que `Planilla` resuelve al LEER, y al escribir se evita de raíz con
# el formato binario. La gema ya estaba: `caxlsx`.
#
# ## ⚠️ UNA HOJA POR SECCIÓN
#
# Con todas las secciones en una sola hoja, ordenar por apellido mezcla los
# quince grados del colegio y la lista deja de servir para lo que se pidió. Una
# hoja por sección es además la forma en que el colegio ya piensa: una lista es
# de una sección.
class ListaDeAlumnosXlsx
  # Cada columna dice su título, su ancho en caracteres y con qué estilo se
  # pinta. Los tres juntos y no en tres listas paralelas: separados, agregar una
  # columna son tres ediciones que tienen que quedar alineadas POR POSICIÓN, y
  # el día que una se desfase el Excel sale con las fechas alineadas a la
  # izquierda y el correo centrado, sin que falle nada.
  #
  # ⚠️ La primera es ancha a propósito: ahí va el escudo, y uno de 64 px no
  # cabe en una columna de «#».
  Columna = Data.define(:titulo, :ancho, :estilo)

  COLUMNAS = [
    [ "#",                    9, :orden ],
    [ "Apellidos",           24, :texto ],
    [ "Nombres",             20, :texto ],
    [ "Cédula",              15, :centrado ],
    [ "Cédula escolar",      17, :centrado ],
    [ "Sexo",                 8, :centrado ],
    [ "Fecha de nacimiento", 14, :fecha ],
    [ "Edad",                 7, :centrado ],
    [ "Nro. de expediente",  14, :centrado ],
    [ "Representante",       28, :texto ],
    [ "Parentesco",          17, :texto ],
    [ "Teléfono",            15, :centrado ],
    [ "Correo",              30, :texto ],
    [ "Inscrito el",         13, :fecha ],
    [ "Estado",              11, :centrado ]
  ].map { |datos| Columna.new(*datos) }.freeze

  FILAS_DEL_MEMBRETE = 5

  def initialize(secciones:, colegio: Current.school)
    @secciones = Array(secciones)
    @colegio = colegio
  end

  def to_stream = libro.to_stream

  def nombre_de_archivo
    base =
      if @secciones.one?
        seccion = @secciones.first
        "#{seccion.grade.name} #{seccion.name} #{seccion.academic_period.name}"
      else
        "#{@colegio&.name} #{@secciones.first&.academic_period&.name}"
      end

    # ⚠️ `parameterize`: «1er Grado – A» lleva espacios y una raya larga, y un
    # archivo con eso en el nombre viaja mal por correo y peor por WhatsApp.
    "lista-de-alumnos-#{base.to_s.parameterize.presence || 'siga'}.xlsx"
  end

  private

  # Los inscritos de todas las secciones, en UNA consulta y agrupados.
  #
  # ⚠️ Uno por uno serían quince consultas para el libro del colegio entero, más
  # una por alumno para su representante. Acá son dos.
  def inscripciones_por_seccion
    # ⚠️ Se ordena ANTES de agrupar: `group_by` conserva el orden de entrada,
    # así que una sola pasada deja cada sección en orden de lista.
    @inscripciones_por_seccion ||=
      Enrollment.en_orden_de_lista(Enrollment.where(section_id: @secciones.map(&:id)))
                .group_by(&:section_id)
  end

  # El representante PRINCIPAL de cada alumno.
  #
  # ⚠️ `order(principal: :desc).reverse_each` deja arriba al principal cuando lo
  # hay y a cualquiera cuando no: un alumno puede tener dos, y la lista lleva
  # uno — a quién llamar primero.
  def responsables
    @responsables ||= StudentRepresentative
                      .where(student_id: inscripciones_por_seccion.values.flatten.map(&:student_id))
                      .includes(representative: :user)
                      .order(principal: :desc)
                      .reverse_each.index_by(&:student_id)
  end

  def libro
    Axlsx::Package.new do |paquete|
      estilos(paquete.workbook)
      @secciones.each { |seccion| hoja_de(seccion, paquete.workbook) }
    end
  end

  def estilos(libro)
    @titulo    = libro.styles.add_style(sz: 15, b: true, fg_color: "1F5C8B")
    @subtitulo = libro.styles.add_style(sz: 10, fg_color: "6B7280")
    @contexto  = libro.styles.add_style(sz: 11, b: true, fg_color: "374151")
    @cabecera  = libro.styles.add_style(b: true, sz: 10, bg_color: "1F5C8B", fg_color: "FFFFFF",
                                        alignment: { horizontal: :center, vertical: :center, wrap_text: true },
                                        border: { style: :thin, color: "FFFFFF" })

    # ⚠️ La cebra son DOS juegos completos de estilos, no uno con el fondo
    # cambiado: en caxlsx el estilo es inmutable una vez creado, así que la fila
    # par y la impar necesitan cada una los suyos.
    @normal = juego_de_estilos(libro, nil)
    @cebra  = juego_de_estilos(libro, "F3F6FA")
  end

  # Los cuatro estilos de una fila de datos: texto, centrado, fecha y el número
  # de orden. Cambian solo en el fondo.
  def juego_de_estilos(libro, fondo)
    borde = { style: :thin, color: "DDE3EA" }
    comun = { sz: 10, border: borde }
    comun[:bg_color] = fondo if fondo

    {
      texto:    libro.styles.add_style(**comun),
      centrado: libro.styles.add_style(**comun, alignment: { horizontal: :center }),
      # ⚠️ La fecha con FORMATO de fecha, no como texto: si va como texto, Excel
      # no la ordena ni la resta, que es la mitad de para qué se baja.
      fecha:    libro.styles.add_style(**comun, format_code: "dd/mm/yyyy",
                                       alignment: { horizontal: :center }),
      orden:    libro.styles.add_style(**comun, fg_color: "9CA3AF",
                                       alignment: { horizontal: :center })
    }
  end

  def hoja_de(seccion, libro)
    inscripciones = inscripciones_por_seccion[seccion.id] || []

    libro.add_worksheet(name: nombre_de_hoja(seccion)) do |hoja|
      membrete(hoja, seccion, inscripciones.size)
      hoja.add_row COLUMNAS.map(&:titulo), style: @cabecera, height: 30
      inscripciones.each_with_index { |inscripcion, i| fila(hoja, inscripcion, i) }
      ajustar(hoja, inscripciones.size)
      escudo(hoja)
      titulos_al_imprimir(libro, hoja)
    end
  end

  # El nombre de la pestaña de Excel, y las tres reglas que lo hacen no reventar:
  #
  #   1. sin `[ ] : * ? / \`   — Excel los PROHÍBE y el archivo no abre
  #   2. 31 caracteres          — el tope, y pasarse tampoco trunca: falla
  #   3. único en el libro      — dos secciones «1er Grado A» de años distintos
  #                               tienen el mismo nombre, y `add_worksheet`
  #                               levanta una excepción en vez de desempatar
  def nombre_de_hoja(seccion)
    @nombres_usados ||= []

    base = "#{seccion.grade.name} #{seccion.name}".gsub(%r{[\[\]:*?/\\]}, " ").strip[0, 31]
    nombre = base
    repetido = 1
    while @nombres_usados.include?(nombre)
      repetido += 1
      sufijo = " (#{repetido})"
      nombre = base[0, 31 - sufijo.length] + sufijo
    end

    @nombres_usados << nombre
    nombre
  end

  def membrete(hoja, seccion, inscritos)
    guia = seccion.leader_teacher&.user&.apellidos_y_nombres

    hoja.add_row [ "", @colegio&.name.to_s ], style: [ nil, @titulo ], height: 20
    hoja.add_row [ "", [ @colegio&.location, dea ].compact_blank.join(" · ") ],
                 style: [ nil, @subtitulo ], height: 16
    hoja.add_row [ "", "Lista de alumnos · #{seccion.grade.name} – #{seccion.name} · #{seccion.academic_period.name}" ],
                 style: [ nil, @contexto ], height: 18
    # ⚠️ La FECHA en que se bajó. Una lista impresa sin fecha se confunde con la
    # del mes pasado, y la matrícula se mueve todo el año.
    hoja.add_row [ "", [ "#{inscritos} alumnos inscritos",
                         ("guía: #{guia}" if guia),
                         "al #{I18n.l(Date.current, format: :long)}" ].compact.join(" · ") ],
                 style: [ nil, @subtitulo ], height: 16
    hoja.add_row []

    # El título y sus tres renglones ocupan el ancho de la tabla, o Excel los
    # corta en la columna siguiente en cuanto tiene algo escrito.
    (1..4).each { |f| hoja.merge_cells("B#{f}:#{ultima_columna}#{f}") }
  end

  def dea = @colegio&.dea_code.presence && "DEA #{@colegio.dea_code}"

  def fila(hoja, inscripcion, indice)
    juego = indice.even? ? @normal : @cebra

    hoja.add_row valores_de(inscripcion, indice),
                 style: COLUMNAS.map { |columna| juego[columna.estilo] }
  end

  # Los quince valores, en el orden de `COLUMNAS`.
  def valores_de(inscripcion, indice)
    persona = inscripcion.student.user
    vinculo = responsables[inscripcion.student_id]
    responsable = vinculo&.representative

    [ indice + 1,
      persona.apellidos,
      Normaliza.titulo(persona.first_name),
      persona.documento_a_la_vista,
      persona.cedula_escolar,
      User::SEX_LABELS[persona.sex],
      persona.birth_date,
      edad_de(persona, inscripcion),
      inscripcion.student.school_card,
      responsable&.user&.nombre_completo,
      vinculo&.etiqueta,
      responsable&.phone,
      responsable&.user&.email,
      inscripcion.enrollment_date,
      inscripcion.status.to_s.capitalize ]
  end

  # ⚠️ La edad AL INICIO DEL AÑO ESCOLAR, no la de hoy.
  #
  # Es la que el MPPE usa para ubicar a un niño en su grado, y la que el colegio
  # escribe en sus listas. La de hoy cambia sola a mitad de año y hace que dos
  # copias de la misma lista se contradigan.
  def edad_de(persona, inscripcion)
    return nil if persona.birth_date.blank?

    corte = inscripcion.section.academic_period.start_date || Date.current
    edad = corte.year - persona.birth_date.year
    edad -= 1 if corte < persona.birth_date + edad.years
    edad
  end

  def ultima_columna = ("A".."Z").to_a[COLUMNAS.size - 1]

  def ajustar(hoja, inscritos)
    hoja.column_widths(*COLUMNAS.map(&:ancho))

    # Los encabezados se quedan a la vista al bajar por treinta filas, y con el
    # número y el apellido pegados a la izquierda al correr hasta «Correo».
    hoja.sheet_view.pane do |panel|
      panel.top_left_cell = "C#{FILAS_DEL_MEMBRETE + 2}"
      panel.state = :frozen
      panel.x_split = 2
      panel.y_split = FILAS_DEL_MEMBRETE + 1
      panel.active_pane = :bottom_right
    end

    # Filtrar y ordenar sin tener que seleccionar nada: es lo primero que hace
    # quien abre una lista de treinta.
    if inscritos.positive?
      hoja.auto_filter = "A#{FILAS_DEL_MEMBRETE + 1}:#{ultima_columna}#{FILAS_DEL_MEMBRETE + 1 + inscritos}"
    end

    # Y sale lista para imprimir: acostada, en una página de ancho, con los
    # encabezados repetidos en cada hoja.
    hoja.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
    hoja.print_options.set(horizontal_centered: true)
  end

  # La fila de encabezados se repite arriba de CADA página impresa. Sin esto, la
  # segunda hoja de una sección de treinta es una tabla de columnas sin nombre.
  #
  # ⚠️ El nombre definido vive en el LIBRO, no en la hoja (`add_defined_name`),
  # y `local_sheet_id` es lo que lo ata a esta.
  def titulos_al_imprimir(libro, hoja)
    fila = FILAS_DEL_MEMBRETE + 1
    libro.add_defined_name("'#{hoja.name}'!$#{fila}:$#{fila}",
                           local_sheet_id: hoja.index, name: "_xlnm.Print_Titles")
  end

  # El escudo del colegio, arriba a la izquierda.
  #
  # ⚠️ Se redimensiona a 64 px ANTES de meterlo: el que sube un colegio sale de
  # un teléfono y pesa dos megas, y quince hojas con quince copias del mismo
  # archivo dan un libro que no se puede mandar por correo.
  #
  # ⚠️ Y si algo falla —no hay escudo, `libvips` no está, el formato no le
  # sirve a Excel— la lista sale IGUAL, sin escudo. Una planilla sin logo sirve;
  # una que no se descarga, no.
  def escudo(hoja)
    ruta = archivo_del_escudo
    return if ruta.nil?

    hoja.add_image(image_src: ruta, noSelect: true, noMove: true) do |imagen|
      imagen.width = 64
      imagen.height = 64
      imagen.start_at 0, 0
    end
  rescue StandardError => e
    Rails.logger.warn("[lista-de-alumnos] sin escudo: #{e.class} — #{e.message}")
  end

  # El escudo reducido, en un archivo temporal que dura lo que dura esta lista.
  #
  # ## ⚠️ Se reduce ACÁ, y no pidiéndole una variante a Active Storage
  #
  # Estuvo escrito `logo.variant(…).processed.download`, que es lo que la
  # documentación enseña, y dentro de una petición de SIGA eso no puede andar:
  #
  #     variante nueva   ──►  Rails la guarda al CONFIRMAR la transacción
  #     en SIGA          ──►  la transacción es la petición entera, por el RLS
  #                           (`con_el_colegio_de_la_sesion`)
  #
  #     1 · `.download`  la miniatura todavía no está guardada → no hay archivo
  #                      → la lista sale SIN escudo, y esto lo tapa el `rescue`
  #     2 · al terminar  Rails va a guardarla desde un temporal que ya cerró
  #                      → `IOError: closed stream`, y la descarga es un 500
  #     3 · desde ahí    el registro de la variante existe y su archivo no:
  #                      ya no falla nada, y el escudo no sale nunca más
  #
  # Lo encontró Daniel el 5 de octubre de 2026 pulsando «Descargar las listas»
  # con el colegio de la demostración, que tiene escudo. Los tests de la lista
  # no le ponían ninguno, así que el camino entero estaba sin ejercitar — y con
  # escudo es como está todo colegio de verdad.
  #
  # `Variation#transform` hace la misma reducción con el mismo procesador, sin
  # registro y sin nada pendiente para después: entra un archivo y sale otro.
  #
  # ⚠️ La regla general: **en una petición, «después de confirmar» es cuando ya
  # terminó**. Lo que se adjunta no se puede leer en la misma petición, y lo
  # que se calcula para usar ahora no se le encarga a un `after_commit`.
  def archivo_del_escudo
    return @archivo_del_escudo if defined?(@archivo_del_escudo)

    @archivo_del_escudo = begin
      logo = @colegio&.logo
      raise "sin logo" unless logo&.attached?

      # ⚠️ El `Tempfile` se guarda en una variable de instancia a propósito:
      # `caxlsx` lee el archivo al armar el `.xlsx`, no al declararlo, y un
      # temporal sin referencia lo borra el recolector antes de esa lectura.
      @temporal = Tempfile.new([ "escudo", ".png" ], binmode: true)
      logo.blob.open do |original|
        miniatura.transform(original) { |reducido| IO.copy_stream(reducido, @temporal) }
      end
      @temporal.flush
      @temporal.path
    # ⚠️ `LoadError` también, y a propósito: es lo que levanta `ruby-vips` cuando
    # `libvips` no está instalada, y NO es un `StandardError`. Sin nombrarlo, la
    # promesa de arriba —«si `libvips` no está, la lista sale igual»— era falsa
    # justo en ese caso: la descarga entera se caía por un escudo.
    rescue StandardError, LoadError => e
      Rails.logger.warn("[lista-de-alumnos] no se pudo preparar el escudo: #{e.class} — #{e.message}")
      nil
    end
  end

  # 128 px para una imagen que se muestra a 64: el doble, para que no se vea
  # borrosa en una pantalla de alta densidad ni al imprimir.
  def miniatura = ActiveStorage::Variation.wrap(resize_to_limit: [ 128, 128 ], format: :png)
end
