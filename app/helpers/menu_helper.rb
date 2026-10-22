# El menú lateral, descrito como DATOS (MOR-149).
#
# ## Por qué esto es un helper y no cuatro plantillas
#
# Los cuatro menús —admin, profesor, alumno, representante— eran cuatro archivos
# Haml con el MISMO bloque de cuatro líneas repetido cuarenta veces:
#
#     %li.sidebar-nav-item
#       = link_to students_path, class: "sidebar-nav-link #{'active' if controller_name == 'students'}", data: { nombre: "Alumnos" } do
#         = icono(:alumnos, tamano: 18)
#         %span Alumnos
#
# Cuarenta copias son cuarenta lugares donde cambiar una clase, y cuarenta
# lugares donde escribir mal el `controller_name` y que el enlace nunca se marque
# como activo — sin que nada falle ni avise.
#
# Acá el menú se DECLARA y `shared/_menu` lo dibuja. Agregar una pantalla es una
# línea; cambiar cómo se ve un enlace es un lugar.
#
# ## La convención que ahorra la mitad de las declaraciones
#
# «Estás acá» se deduce de la RUTA, no se escribe a mano: si el enlace apunta a
# `students_path` y estás en `StudentsController`, está activo. `recognize_path`
# hace justamente eso, y es lo que Rails ya sabe de sus propias rutas.
#
# `tambien_en:` es para el caso que la convención no cubre: una entrada que
# representa varias pantallas —«Reportes» son boletines Y constancias— y que sin
# eso quedaría apagada en la mitad de sus propias pantallas.
module MenuHelper
  # Un enlace: lo que se ve y a dónde va.
  #
  # `nombre` va también en un `data-nombre` porque el menú encogido lo muestra
  # como globo al pasar el mouse — con el menú angosto, el icono queda solo.
  # ⚠️ `estado` es opcional y solo lo usan las secciones del profesor: dice
  # cómo va su carga de notas (MOR-223). El resto del menú lo deja en nil, y la
  # plantilla no dibuja nada — un punto de color al lado de «Alumnos» no
  # significaría nada.
  Enlace = Data.define(:nombre, :icono, :ruta, :tambien_en, :estado) do
    def initialize(nombre:, icono:, ruta:, tambien_en: [], estado: nil) = super
  end

  # Cómo se llama cada estado de carga, para el tooltip y el lector de pantalla.
  #
  # ⚠️ Nombrados por lo que SIGNIFICAN, no por su color: «al día» y no «verde».
  # Es la misma regla que ya siguen los chips de estado — un alumno retirado es
  # `--inactivo`, no `--gris`.
  NOMBRES_DE_ESTADO = {
    completo: "Notas al día",
    a_medias: "Le faltan notas por cargar",
    vacio: "Sin ninguna nota cargada",
    sin_evaluaciones: "Todavía sin evaluaciones"
  }.freeze

  # ⚠️ Un ICONO por estado, no un punto de color.
  #
  # QA de Daniel: *«check o icon-check verde. Si no está completado, otro ícono
  # descriptivo. Incluso si no tiene evaluación, el ícono debe indicarlo»*.
  #
  # El punto obligaba a leer el tooltip para saber CUÁL de los tres estados era
  # —los tres eran el mismo círculo de 8 px— así que el color cargaba solo con
  # todo el significado. Un check, un reloj y un signo de admiración se
  # distinguen sin color, que es exactamente lo que pide la regla: el color
  # acompaña al dato, nunca lo sustituye.
  #
  # Y «sin evaluaciones» ahora se DIBUJA. Antes devolvía `nil` y la sección
  # aparecía sin nada, indistinguible de una sección cuyo avance no se pudo
  # calcular — que es el estado NORMAL de un colegio en septiembre.
  ICONOS_DE_ESTADO = {
    completo: :ok,
    a_medias: :pendiente,
    vacio: :error,
    sin_evaluaciones: :notas
  }.freeze

  # Un grupo plegable, que nace PLEGADO (MOR-203).
  #
  # Daniel: *«el enlace está muy oculto; creo que por defecto los grupos del
  # sidebar deberían estar contraídos y solo desplegar el grupo que el usuario
  # requiera»*.
  #
  # Suena contradictorio —esconder para encontrar— y no lo es: con los cinco
  # grupos abiertos el menú son veintitantos renglones que no caben en una
  # pantalla, así que la mitad vive debajo del pliegue y hay que scrollear el
  # menú para leerlo. Plegados, los cinco títulos se ven de una y la persona abre
  # uno.
  #
  # ⚠️ El grupo de la pantalla actual se abre solo (`grupo_abierto?`), así que
  # nadie aterriza sin saber dónde está parado.
  #
  # Un grupo SIN título no se pliega: es el «Panel» suelto de arriba. Se
  # representa así, y no con un caso aparte en la plantilla, para que el menú
  # tenga UNA forma y el renderizador un solo camino.
  # Un nodo del árbol del menú: puede tener hijas y hojas (MOR-③).
  #
  # ## Por qué hace falta un árbol y no bastan Grupo → Enlace
  #
  # El profesor navega **área → grado → sección**, y eso son tres niveles. Con
  # la estructura plana anterior, Sofía Moreno —tres áreas, diecinueve
  # asignaciones— veía quince renglones seguidos donde el área no aparecía por
  # ningún lado, así que «1er Año – B» no decía cuál de sus dos áreas era.
  #
  # ## ⚠️ La regla que lo hace usable: un escalón aparece solo si DIVIDE algo
  #
  # Es la misma de las pastillas y del selector de nivel, subida al menú. Y acá
  # es lo que hace que el mismo árbol le sirva a los cuatro perfiles reales:
  #
  #     Colmenares  1 sección, 3 áreas    →  todo colapsa: un renglón
  #     Ochoa       5 asignac., 2 áreas   →  divide el ÁREA
  #     García      16 asignac., 1 área   →  el área colapsa; divide el GRADO
  #     Moreno      19 asignac., 3 áreas  →  divide el área Y el grado
  #
  # Sin la regla, Carlos García leería una rama «Matemática» con las dieciséis
  # secciones adentro: un renglón que no decide nada y hay que abrir igual.
  Rama = Data.define(:titulo, :nodos) do
    def initialize(titulo: nil, nodos: []) = super

    def id = "rama-#{titulo.to_s.parameterize}"

    # ⚠️ UNA lista de nodos, y no `hijas` + `enlaces` por separado.
    #
    # La primera versión los tenía aparte, y las hojas sueltas caían todas al
    # final: Educación Estética se leía «1er Grado, 2do Grado, 4to Grado» y
    # después «3er Grado – A, 5to, 6to». El orden pedagógico es lo único que
    # hace legible una lista de doce grados, y así se perdía.
    def ramas   = nodos.grep(Rama)
    def enlaces = nodos.reject { |n| n.is_a?(Rama) }

    # ⚠️ Un escalón que no DIVIDE nada se salta, en sus dos formas.
    #
    #   · con un solo nodo y ese nodo es una rama → sus nietos suben
    #   · una rama con un solo enlace → se vuelve ese enlace
    #
    # Sin lo segundo, un grado con una sección se leía «Ciencias Naturales ›
    # 1er Grado › 1er Grado – A», con el grado escrito dos veces seguidas.
    #
    # Se hace al construir y no al dibujar, para que la vista no decida nada.
    def podada
      podados = nodos.map { |n| n.is_a?(Rama) ? n.podada : n }
      return podados.first.with(titulo: titulo) if podados.one? && podados.first.is_a?(Rama)

      with(nodos: podados.map { |n| n.is_a?(Rama) && n.redundante? ? n.nodos.first : n })
    end

    # Una rama que es, en realidad, un enlace: un solo destino y nada que abrir.
    def hoja_suelta? = nodos.one? && !nodos.first.is_a?(Rama)

    # ⚠️ Y solo se colapsa si el enlace YA DICE lo que dice la rama.
    #
    # «3er Grado › 3er Grado – A» es redundante y se colapsa. Pero
    # «Comunicación y Representación › 1er Nivel – U» NO: el área es lo único
    # que distingue ese destino de los otros dos de la misma sección, y
    # colapsarla dejaba tres renglones llamados «1er Nivel – U», idénticos e
    # inútiles. Costó ver: la poda parecía correcta en el profesor de primaria
    # y rompía justo en el de preescolar, que dicta tres áreas en una sección.
    def redundante? = hoja_suelta? && nodos.first.nombre.start_with?(titulo.to_s)
  end

  # ⚠️ Un grupo lleva enlaces (una lista plana) O ramas (un árbol), nunca los
  # dos: «Día a día» es una lista de pantallas y «Dicto» es área → grado →
  # sección. Mezclarlos en el mismo grupo dejaría media lista antes del árbol y
  # media después, sin nada que explique por qué.
  Grupo = Data.define(:titulo, :enlaces, :ramas, :abierto_por_defecto) do
    def initialize(titulo: nil, enlaces: [], ramas: [], abierto_por_defecto: false) = super

    def arbol? = ramas.any?

    def plegable? = titulo.present?

    def id = "grupo-#{titulo.to_s.parameterize}"
  end

  # ── Los cuatro menús ──────────────────────────────────────────────────────

  # El del administrador (MOR-149).
  #
  # ## Por qué este agrupamiento y no el anterior
  #
  # El anterior cortaba por FRECUENCIA —«Día a día» / «El colegio»— y sonaba
  # bien, pero obligaba a saber cada cuánto se usa algo para saber dónde buscarlo.
  # Y no se sostenía: «Representantes» estaba en «El colegio» y «Alumnos» en
  # «Día a día», siendo las dos fichas de personas.
  #
  # Ahora corta por QUÉ ES LA COSA, que es como la gente pregunta: «¿dónde están
  # los profesores?» — en Usuarios, con las otras personas.
  #
  #     Panel           suelto arriba: no es una categoría, es el punto de partida
  #     Usuarios        las personas, las cuatro juntas
  #     Académico       cómo está armado el colegio: grados, secciones, materias
  #     Día a día       lo que pasa esta semana: asistencia y evaluaciones
  #     Reportes        lo que el colegio EMITE y lo que consulta
  #     Configuración   se toca al empezar el año y casi no se vuelve
  def menu_del_administrador
    [
      Grupo.new(enlaces: [ Enlace.new(nombre: "Panel", icono: :panel, ruta: dashboards_administrador_path) ]),
      Grupo.new(titulo: "Usuarios", enlaces: enlaces_de_usuarios),
      Grupo.new(titulo: "Académico", enlaces: enlaces_academicos),
      Grupo.new(titulo: "Día a día", enlaces: enlaces_del_dia),
      Grupo.new(titulo: "Reportes", enlaces: enlaces_de_reportes),
      Grupo.new(titulo: "Finanzas", enlaces: enlaces_de_finanzas),
      Grupo.new(titulo: "Configuración", enlaces: enlaces_de_configuracion)
    ].reject { |grupo| grupo.enlaces.empty? }
  end

  # El menú del profesor: sus secciones, y nada más (etapa ③).
  #
  # ## ⚠️ «Mi trabajo» se retiró, y era medio menú
  #
  # Tenía tres entradas —«Competencias e indicadores», «Mis evaluaciones» y
  # «Asistencia»— y las tres pasaron a ser pestañas DENTRO de la sección.
  #
  # Daniel, tachando ese grupo: *«al final esta parte tiende a desaparecer»*. Y
  # es la consecuencia de la decisión anterior: si el trabajo del profesor es
  # por sección, un renglón que lleva a «todas mis competencias» sin decir de
  # cuál sección es exactamente la descontextualización que las pestañas vienen
  # a evitar — con el agravante de que ahí hay que volver a elegir grado, área,
  # sección y lapso, que el árbol ya sabe.
  #
  #     ANTES                        AHORA
  #     ▾ MI TRABAJO                 ▾ SOY GUÍA DE
  #         Competencias e indic.        4to Grado – A
  #         Mis evaluaciones         ▾ DICTO
  #         Asistencia                   …
  #     ▾ MIS SECCIONES
  #         …quince renglones
  #
  # ⚠️ Las pantallas NO desaparecen: `/competencias`, `/evaluaciones` y
  # `/asistencia` siguen respondiendo, y la dirección las usa desde su propio
  # menú. Lo que se quita es la entrada que le ofrecía al profesor entrar por el
  # camino largo.
  def menu_del_profesor
    [
      Grupo.new(enlaces: [ Enlace.new(nombre: "Inicio", icono: :panel, ruta: dashboards_profesor_path) ]),
      *grupo_de_lo_que_guio,
      *grupo_de_lo_que_dicto
    ]
  end

  # ── Las dos ramas del profesor ────────────────────────────────────────────
  #
  # Daniel: *«creo que la siguiente división natural es el área y la guía. Una
  # cosa es las áreas que yo dicto y otra cosa es la guía: las secciones que yo
  # guío. Creo que tienen comportamientos distintos»*.
  #
  # ## ⚠️ La misma sección aparece en las dos, y no es un bug
  #
  # Sofía Moreno guía 1er Grado A **y además dicta ahí**. Se pregunta si eso
  # confunde, y la respuesta de Daniel fue *«no importa que se dupliquen, es
  # entendible y no se siente como un bug»* — porque son **dos trabajos**:
  #
  #     SOY GUÍA DE › 1er Grado – A      la SECCIÓN: asistencia, boletín,
  #                                      informe. Sin área: la asistencia es
  #                                      de todos.
  #     DICTO › Ed. Estética › 1er Grado A   una ASIGNACIÓN: planificar y
  #                                          calificar ESA área.
  #
  # Y eso resuelve de paso una ambigüedad vieja: `/secciones/76` no dice qué
  # área, así que la libreta tenía que volver a preguntarlo con pastillas.
  # Entrando por la rama de áreas, el clic ya trae las dos cosas.
  def grupo_de_lo_que_guio
    secciones = sections_que_guio
    return [] if secciones.empty?

    [ Grupo.new(titulo: "Soy guía de",
                enlaces: secciones.map { |s| enlace_a_seccion(s) }) ]
  end

  # ⚠️ Sin secciones que guiar, la rama NO se dibuja — ni vacía.
  # Decisión de Daniel: *«no se ve si no es guía»*. Un renglón que no lleva a
  # ningún lado enseña a ignorar esa zona del menú.
  def sections_que_guio
    @sections_que_guio ||= begin
      docente = current_user.teacher
      docente ? mis_secciones.select { |s| s.leader_teacher_id == docente.id } : []
    end
  end

  # El árbol de lo que dicta: área → grado → sección.
  def grupo_de_lo_que_dicto
    raiz = Rama.new(nodos: ramas_por_area).podada
    return [] if raiz.nodos.empty?

    [ Grupo.new(titulo: "Dicto", ramas: [ raiz ]) ]
  end

  # ⚠️ El orden: las áreas por nombre, los grados por su ORDEN OFICIAL.
  # Alfabéticamente «1er Año» va antes que «6to Grado» y el árbol mezcla
  # primaria con media; `grades.orden` es el del catálogo del Reglamento, que
  # es el que un profesor tiene en la cabeza.
  def ramas_por_area
    mis_asignaciones_del_menu.group_by(&:subject)
                             .sort_by { |area, _| area.name }
                             .map { |area, filas| Rama.new(titulo: area.name, nodos: ramas_por_nivel(filas, area)) }
  end

  # ⚠️ El NIVEL sigue dividiendo, aunque ya no sea un encabezado suelto.
  #
  # Antes el menú agrupaba las secciones por nivel —«lo mismo con ese chorrero
  # de secciones, hay que dividirlas por nivel»— y al pasar al árbol por área
  # eso se perdió: Carlos García, que da Matemática de 1er Grado a 6to Año,
  # habría visto sus doce grados seguidos con primaria y media mezcladas.
  #
  # Va como un escalón más y la poda se encarga del resto: con un nivel
  # elegido en la barra, o con un profesor de un solo nivel, desaparece solo.
  def ramas_por_nivel(asignaciones, area)
    asignaciones.map(&:section).uniq
                .group_by { |s| GradoOficial.se_elige_como(s.grade.level) }
                .sort_by { |nivel, _| GradoOficial::ABARCA.keys.index(nivel) || 99 }
                .map do |nivel, secciones|
      Rama.new(titulo: GradoOficial.etiqueta(nivel, corto: true),
               nodos: ramas_por_grado(secciones, area))
    end
  end

  def ramas_por_grado(secciones, area)
    secciones.group_by(&:grade)
             .sort_by { |grado, _| [ grado.orden || 99, grado.name ] }
             .map do |grado, del_grado|
      hojas = del_grado.sort_by(&:name).map { |s| enlace_a_seccion(s, area: area) }
      Rama.new(titulo: grado.name, nodos: hojas)
    end
  end

  # Si este profesor tiene alguna sección que se evalúe por competencias.
  #
  # ⚠️ Se pregunta por `Grade#por_competencias?` y no por «primaria» a mano: es
  # la misma pregunta que hace `CompetenciesController`, y con dos lugares
  # decidiéndolo el menú termina ofreciendo una pantalla que el controller
  # rechaza.
  def dicta_primaria?
    mis_secciones.any? { |s| s.grade.por_competencias? }
  end

  def menu_del_estudiante
    [
      Grupo.new(enlaces: [ Enlace.new(nombre: "Inicio", icono: :panel, ruta: dashboards_estudiante_path) ]),
      Grupo.new(titulo: "Mis estudios", enlaces: [
        Enlace.new(nombre: "Mis notas", icono: :notas, ruta: dashboards_notas_path)
      ])
    ]
  end

  def menu_del_representante
    [ Grupo.new(titulo: "Mis representados", enlaces: [
        Enlace.new(nombre: "Todos", icono: :alumnos, ruta: representante_path)
      ]) ]
  end

  # ── Las pestañas ──────────────────────────────────────────────────────────
  #
  # Van acá y no en cada vista por la misma razón que el menú: son navegación, y
  # una pestaña declarada en dos plantillas se despareja en cuanto una cambie.

  # Asistencia: pasar lista hoy, y quién viene acumulando faltas. Eran dos
  # renglones del menú y son la misma pantalla vista de dos maneras.
  #
  # ⚠️ «Pasar lista» incluye `show`, y no es un detalle.
  #
  # `AsistenciasController#index` **redirige directo a la sección** cuando hay una
  # sola —«un profesor guía normalmente tiene una sola y entra directo»—. O sea
  # que para la mayoría de los guías la pantalla de pasar lista ES `show`, y si
  # las pestañas vivieran solo en `index` no las verían NUNCA: no habría manera
  # de llegar a Inasistencias.
  def pestanas_de_asistencia
    [
      [ "Pasar lista", asistencias_path, action_name.in?(%w[index show]) ],
      [ "Inasistencias", reporte_asistencia_path, action_name == "reporte" ]
    ]
  end

  # Las cuatro vistas de una sección, para el profesor (etapa ③).
  #
  # Daniel fijó el orden: **Asistencia · Calificar · Planificar · Alumnos**.
  #
  #     ASISTENCIA    solo el GUÍA, y es lo diario
  #     CALIFICAR     la libreta del área que dicto acá
  #     PLANIFICAR    competencias, indicadores y evaluaciones
  #     ALUMNOS       quiénes son
  #
  # ## ⚠️ Las cuatro viven EN la sección
  #
  # Daniel: *«no me gustan ni Asistencia ni Planificación como URL, se
  # descontextualiza todo, se supone que estoy en mi espacio de trabajo —la
  # Sección— no para salir de él, ese es todo el fin de esta división: no es
  # solo "fingir" sino realmente estar en la sección»*.
  #
  # Y tenía razón: una pestaña que te expulsa no divide nada, solo mueve el
  # problema. Las cuatro son acciones de `SectionsController` y comparten el
  # encabezado; la planilla de asistencia y el plan son los MISMOS parciales que
  # usan `/asistencia` y `/competencias`, vía `PreparaLaAsistencia` y
  # `MuestraElPlan`, para que no se separen.
  #
  # Esas dos rutas siguen existiendo: son la entrada por el MENÚ, para quien no
  # viene de una sección.
  #
  # ## ⚠️ Y la ACTIVA por defecto sale de POR DÓNDE ENTRÓ
  #
  # Daniel puso «Asistencia» primera y notó la consecuencia: *«no había pensado
  # en la pestaña de default»*. Con las pestañas leyéndose en ese orden, la
  # primera es la que abre — y quien viene de «Dicto › Matemática › 4to A» no
  # viene a pasar lista, viene a calificar esa área.
  #
  # No hace falta preguntarlo: el árbol ya lo dice.
  #
  #     entró por «Soy guía de»  (sin área)  →  Asistencia
  #     entró por «Dicto»        (con área)  →  Calificar
  def pestanas_de_la_seccion(seccion, area: nil, activa: nil)
    contexto = { area: area&.id }
    pestanas = []

    if guio?(seccion) || can_manage_sections?
      pestanas << [ "Asistencia", asistencia_section_path(seccion, contexto), activa == :asistencia ]
    end

    pestanas << [ "Calificar", section_path(seccion, contexto), activa == :calificar ]

    # ⚠️ Educación Inicial NO planifica: su calificación es un texto, así que no
    # hay evaluaciones que ponderar. Se pregunta por `planifica?` y no por «no
    # es primaria», que es la trampa de esta zona — con eso, Inicial y
    # bachillerato caen juntos y a la maestra de 1er Nivel se le pedía un
    # «Examen 40 %» para un niño de tres años.
    if seccion.grade.planifica?
      pestanas << [ "Plan de Evaluación", planificar_section_path(seccion, contexto), activa == :planificar ]
    end

    # ⚠️ Los informes descriptivos son una PESTAÑA, no un botón de la cabecera.
    #
    # Cyndi, en la prueba de campo: el informe descriptivo es parte del trabajo
    # del lapso —se escribe junto con las notas, en la misma sección— y estaba
    # detrás de un botón en la esquina. Un botón en la cabecera se lee como una
    # ACCIÓN sobre lo que la pantalla muestra; esto es otro sitio donde trabajar,
    # y eso es exactamente lo que una pestaña dice.
    #
    # ⚠️ Lo escribe el GUÍA, no cualquier profesor. En bachillerato son doce
    # profesores y ninguno ve al alumno entero; el guía sí. La dirección también,
    # porque una sección puede no tener guía y esos alumnos se quedarían sin
    # informe para siempre. Es la misma condición de `InformesController`.
    if guio?(seccion) || can_manage_sections?
      pestanas << [ "Informes", section_informes_path(seccion, contexto), activa == :informes ]
    end

    pestanas << [ "Alumnos", alumnos_section_path(seccion, contexto), activa == :alumnos ]

    # ⚠️ Quién dicta qué es de la DIRECCIÓN, que es quien asigna. Fue una
    # segunda tarjeta debajo de la lista de alumnos hasta que Daniel la mandó a
    # su pestaña (13 de octubre de 2026).
    if can_manage_sections?
      pestanas << [ "#{Vocabulario::AREAS_CORTAS} y profesores", areas_section_path(seccion, contexto), activa == :areas ]
    end
    pestanas
  end

  def guio?(seccion)
    docente = current_user.teacher
    docente.present? && seccion.leader_teacher_id == docente.id
  end
  helper_method :guio? if respond_to?(:helper_method)

  # Los papeles que emite el colegio. Los tres son «elegir sección, elegir
  # alumno, emitir»: la misma tarea con distinto papel al final.
  #
  # ⚠️ Los certificados llegaron el 1 de octubre de 2026 y existían desde el 11
  # de septiembre: estaban en la última tarjeta de la ficha de cada alumno, y
  # quien abría «Documentos» veía dos pestañas y concluía que no había más.
  #
  # ⚠️ La sección ELEGIDA viaja de una pestaña a la otra. Se llega desde el
  # botón «Documentos oficiales» de una sección (13 de octubre de 2026), y quien
  # pasa de sus boletines a sus constancias sigue hablando de la misma sección.
  def pestanas_de_documentos
    seccion = { section_id: params[:section_id].presence }.compact
    [
      [ "Boletines", report_cards_path(seccion), controller_name == "report_cards" ],
      [ "Constancias", constancias_path(seccion), controller_name == "constancias" ],
      [ "Certificados", certificados_path(seccion), controller_name == "certificados" ]
    ]
  end

  # ── La puesta en marcha ───────────────────────────────────────────────────

  # A dónde lleva cada paso del arranque.
  #
  # Va acá, con el resto de la navegación, y como un `case` explícito en vez de
  # `send("#{paso.ruta}_path")`: una clave mal escrita tiene que fallar al
  # renderizar y no producir un enlace a ninguna parte.
  # ⚠️ `recorrido:` lo pega ACÁ, y no cada vista con `"#{ruta}?recorrido=..."`.
  #
  # Estaba escrito así en cinco lugares y era una bomba con la mecha puesta: el
  # día que un paso apunte a una ruta que YA lleva parámetros —el importador con
  # su `?tipo=matricula`, que es justo lo que acaba de pasar— la concatenación
  # produce `?tipo=matricula?recorrido=alumnos`. Dos signos de interrogación:
  # Rails lee el segundo como parte del valor del primero, el tipo llega como
  # «matricula?recorrido=alumnos» y el importador no reconoce ninguno de los dos.
  #
  # Falla en silencio y solo en los pasos que llevan parámetros, que son los
  # nuevos. Por eso el separador se decide acá una vez.
  def ruta_del_paso(paso, recorrido: false)
    destino = destino_del_paso(paso)
    return destino unless recorrido

    "#{destino}#{destino.include?('?') ? '&' : '?'}recorrido=#{paso.clave}"
  end

  def destino_del_paso(paso)
    case paso.ruta
    when :niveles_del_colegio then niveles_del_colegio_path
    when :colegio             then colegio_path
    when :academic_periods    then academic_periods_path
    when :evaluation_moments  then evaluation_moments_path
    when :subjects            then subjects_path
    when :sections            then sections_path
    when :teachers            then teachers_path
    when :importaciones       then importaciones_path
    when :departments         then departments_path
    # ⚠️ Directo al ALTA (MOR-205): mandar al listado de un colegio que no tiene
    # ninguno es mandar a un estado vacío para que desde ahí toque otro botón.
    when :academic_period_nuevo then new_academic_period_path
    # ⚠️ Al ALTA de la planilla, con su tipo puesto. `/importaciones` es la
    # bitácora: mandar ahí es volver a preguntar lo que el paso ya dijo.
    when :importar_matricula  then new_importacion_path(tipo: :matricula)
    when :importar_historial  then new_importacion_path(tipo: :historial)
    else raise ArgumentError, "paso sin ruta conocida: #{paso.ruta.inspect}"
    end
  end

  # ── «Estás acá» ───────────────────────────────────────────────────────────

  # Por convención: el enlace está activo si su ruta cae en el controlador donde
  # estás parado. Nada que declarar y nada que se pueda escribir mal.
  #
  # `recognize_path` recorre las rutas al revés y puede levantar si la ruta no
  # existe —un enlace roto—, así que el rescate evita que un menú tumbe la página
  # entera por un enlace mal armado.
  # ⚠️ El controller NO alcanza cuando el enlace apunta a UNO en concreto.
  #
  # QA de Daniel: *«el resaltado absorbe todas las secciones en el side»*. Y era
  # literal: las nueve secciones del menú apuntan a `sections#show`, así que
  # estando en `/secciones/78` las nueve daban `controller == "sections"` y las
  # nueve se pintaban activas. El menú decía «estás en todas partes», que es lo
  # mismo que no decir nada.
  #
  # Con `:id` en el destino se compara también el id. Sin él —`students_path`,
  # `asistencias_path`, todo el menú de arriba— la comparación por controller
  # sigue siendo la correcta: son listados, y cualquier pantalla de ese
  # controller cuenta como «estás acá».
  def enlace_activo?(enlace)
    return true if enlace.tambien_en.include?(controller_path)

    destino = Rails.application.routes.recognize_path(enlace.ruta)
    return false unless destino[:controller] == controller_path
    return true if destino[:id].blank?
    return false unless destino[:id].to_s == params[:id].to_s

    # ⚠️ Y el ÁREA, que viaja en la query y `recognize_path` no devuelve.
    #
    # Desde el árbol del profesor, la misma sección aparece una vez por cada
    # área que dicta ahí —«Castellano › 6to Grado – A» y «Ciencias › 6to Grado
    # – A»— más otra en «Soy guía de», sin área. Comparando solo el id se
    # marcaban las tres. Es la misma trampa del 7 de septiembre, un escalón más
    # abajo: lo que identifica el destino ya no es la sección, es la asignación.
    area_del_enlace(enlace) == params[:area].presence
  rescue ActionController::RoutingError, ActionController::UrlGenerationError
    false
  end

  def area_del_enlace(enlace)
    consulta = enlace.ruta.to_s.split("?", 2).last
    return nil unless consulta

    Rack::Utils.parse_nested_query(consulta)["area"].presence
  end

  def grupo_activo?(grupo)
    return grupo.ramas.any? { |rama| rama_activa?(rama) } if grupo.arbol?

    grupo.enlaces.any? { |enlace| enlace_activo?(enlace) }
  end

  # ⚠️ Una rama está activa si la pantalla actual está EN CUALQUIER PARTE de
  # ella, por hondo que sea. Sin esto, abrir «Arte y Patrimonio › 1er Año › B»
  # dejaría las dos ramas de arriba cerradas y el menú no diría dónde estoy.
  def rama_activa?(rama)
    rama.nodos.any? { |n| n.is_a?(Rama) ? rama_activa?(n) : enlace_activo?(n) }
  end
  helper_method :rama_activa? if respond_to?(:helper_method)

  # Un grupo se dibuja abierto si estás adentro —esconder dónde estás parado es
  # peor que un menú largo— o si la persona lo dejó abierto.
  #
  # ⚠️ La cookie anota lo ABIERTO y ya no lo plegado (MOR-203). Con los grupos
  # naciendo cerrados, una lista de «los que cerré» no alcanza: abrir uno lo
  # sacaba de esa lista y en la página siguiente volvía a su default, que ahora
  # es cerrado. O sea que el menú se olvidaba de lo que la persona acababa de
  # hacer. La lista tiene que ser de lo que se APARTÓ del default, y el default
  # cambió de lado.
  def grupo_abierto?(grupo)
    return true unless grupo.plegable?
    return true if grupo_activo?(grupo)
    return true if cookies[:menu_abierto].to_s.split(",").include?(grupo.id)

    grupo.abierto_por_defecto
  end

  private

  def enlaces_de_usuarios
    enlaces = []
    enlaces << Enlace.new(nombre: "Alumnos", icono: :alumnos, ruta: students_path) if can_manage_students?
    enlaces << Enlace.new(nombre: "Representantes", icono: :representantes, ruta: representatives_path) if can_manage_students?
    enlaces << Enlace.new(nombre: "Profesores", icono: :profesores, ruta: teachers_path) if can_manage_teachers?
    enlaces << Enlace.new(nombre: "Administradores", icono: :llave, ruta: admins_path) if puede_ver_administradores?  # rubocop:disable Layout/LineLength
    enlaces
  end

  def enlaces_academicos
    enlaces = []
    if can_manage_academic_config?
      enlaces << Enlace.new(nombre: "Grados", icono: :grados, ruta: grades_path)
    end
    if can_manage_sections?
      enlaces << Enlace.new(nombre: "Secciones", icono: :secciones, ruta: sections_path)
      enlaces << Enlace.new(nombre: "Inscripciones", icono: :inscripciones, ruta: enrollments_path)
    end
    enlaces << Enlace.new(nombre: Vocabulario::AREAS, icono: :materias, ruta: subjects_path)
    # Los horarios (spec `horarios`): abre en la semana de una sección, la hoja
    # que el colegio reconoce (decisión 19). Lo ve toda la dirección; armarlo
    # es de quien administra secciones.
    enlaces << Enlace.new(nombre: "Horarios", icono: :horario, ruta: horarios_path,
                          tambien_en: %w[time_slots lessons])
    # ⚠️ «Planes de evaluación» se retiró del menú (etapa ③).
    #
    # Apuntaba a `/competencias`, que dejó de ser una pantalla: su escalera se
    # alimentaba de `mis_asignaciones`, vacía para la dirección, así que un
    # director que entraba veía «todavía no tienes secciones asignadas». O sea
    # que el enlace llevaba a un estado vacío desde el día uno.
    #
    # La dirección ve el plan donde vive: entrando a la sección, pestaña
    # «Planificar». Sigue sin poder tocarlo, por la misma razón que no toca la
    # ponderación — es la decisión pedagógica de quien evalúa (MOR-136).
    enlaces << Enlace.new(nombre: "Departamentos", icono: :colegio, ruta: departments_path)
    enlaces
  end

  # ⚠️ Asistencia es UNA entrada, no dos.
  #
  # «Asistencia» e «Inasistencias» eran dos renglones del menú y son la misma
  # pantalla vista de dos maneras: pasar lista hoy, y quién viene acumulando
  # faltas. Ahora son dos pestañas, y el menú marca la entrada en las dos.
  def enlaces_del_dia
    return [] unless can_manage_sections?

    [
      Enlace.new(nombre: "Asistencia", icono: :asistencia, ruta: asistencias_path),
      Enlace.new(nombre: "Evaluaciones", icono: :notas, ruta: evaluation_activities_path),
      # La segunda oportunidad del Art. 112 (MOR-168). Va acá y no en Reportes
      # porque se CARGA, no se consulta: es la misma tarea que Evaluaciones, en
      # septiembre.
      Enlace.new(nombre: "Reparaciones", icono: :notas, ruta: reparaciones_path)
    ]
  end

  # Lo que el colegio emite y lo que consulta. Boletines y constancias son dos
  # pestañas de la misma pantalla: las dos son «elegir sección, elegir alumno,
  # emitir el papel».
  #
  # ⚠️ «Inasistencias» NO va acá aunque suene a reporte: es pestaña de Asistencia.
  # Puesta acá encendería a la vez que «Asistencia» —las dos rutas caen en el
  # mismo controlador— y el menú marcaría dos lugares para una sola pantalla.
  def enlaces_de_reportes
    enlaces = []
    if can_manage_students?
      enlaces << Enlace.new(nombre: "Documentos", icono: :boletines,
                            ruta: report_cards_path, tambien_en: %w[constancias certificados])
    end
    # ⚠️ Solo a quien la puede abrir. Se ofrecía a CUALQUIER admin —finanzas
    # incluida— mientras el panel escondía el bloque de actividad reciente: el
    # menú prometía una pantalla que ahora rebota.
    if show_recent_activity?
      enlaces << Enlace.new(nombre: "Registro de actividad", icono: :auditoria,
                            ruta: dashboards_activity_logs_path)
    end
    enlaces
  end

  # Los pagos que reportó la familia (spec: `docs/specs/pagos-de-la-familia.md`).
  #
  # ⚠️ Grupo PROPIO, no un enlace dentro de «Día a día» ni de «Reportes».
  #
  # No es un reporte —no se consulta, se DECIDE sobre él— y no es día a día: es
  # el trabajo de otra persona. En un colegio, quien cobra no es quien pasa
  # lista, y meterlo con lo demás le pone el dinero delante a la coordinadora
  # cada vez que abre el menú.
  #
  # ⚠️ Y por eso el grupo entero no existe para quien no cobra: `puede_cobrar?`
  # es la misma lista de cargos que `FinanzasController`. Un grupo vacío en el
  # menú es una puerta que se ve y no abre.
  def enlaces_de_finanzas
    enlaces = []

    if puede_cobrar?
      enlaces << Enlace.new(nombre: "Pagos reportados", icono: :inscripciones, ruta: finanzas_path)

      # ⚠️ Cuelga del AÑO de la sesión: los montos cambian cada año, y los del
      # año pasado tienen que seguir diciendo lo que decían.
      if Current.academic_period
        enlaces << Enlace.new(nombre: "Lo que se cobra", icono: :lapsos,
                              ruta: academic_period_cobros_path(Current.academic_period))
      end
    end

    # Lo que el COLEGIO le paga a SIGA, al lado de lo que cobra a las familias:
    # es la misma gaveta (decisión 14 del spec `del-registro-al-cobro`). Se
    # pregunta aparte de `puede_cobrar?` aunque hoy sean los mismos cargos: son
    # dos permisos, y el día que se separen no puede arrastrar al otro.
    if puede?(:pagar_la_suscripcion)
      enlaces << Enlace.new(nombre: "Suscripción", icono: :llave, ruta: suscripcion_path)
    end
    enlaces
  end

  def enlaces_de_configuracion
    enlaces = []
    if can_manage_academic_config?
      enlaces << Enlace.new(nombre: "Años escolares", icono: :calendario, ruta: academic_periods_path)
      enlaces << Enlace.new(nombre: "Lapsos", icono: :lapsos, ruta: evaluation_moments_path)
    end
    # Va en Configuración aunque se use una vez al año, porque esa vez es la
    # PRIMERA semana del colegio en SIGA — y para esa semana el camino no es el
    # menú: es el estado vacío de Alumnos, que lo ofrece cuando hace falta.
    # ⚠️ Y solo a quien administra alumnos: importar CREA alumnos, profesores y
    # notas. Se ofrecía a cualquier admin, finanzas incluida.
    if can_manage_students?
      enlaces << Enlace.new(nombre: "Importar datos", icono: :subir, ruta: importaciones_path)
    end
    if can_manage_academic_config?
      # ⚠️ La rúbrica va en Configuración y no en Académico, aunque hable de
      # notas: no se toca durante el año. Se define una vez, al arrancar, y
      # después solo se consulta — igual que la identidad del colegio.
      enlaces << Enlace.new(nombre: "Rúbrica de evaluación", icono: :notas, ruta: rubrica_path)
      enlaces << Enlace.new(nombre: "Identidad del colegio", icono: :configuracion, ruta: colegio_path)
    end
    enlaces
  end

  # ⚠️ La MISMA lista que los permisos, no una copia: dos listas de roles se
  # desparejan, y el síntoma es un menú que ofrece una pantalla a la que el
  # controller después no deja entrar (`ApplicationController::DIRECCION`).
  def puede_ver_administradores?
    ApplicationController::DIRECCION.include?(rol_de_admin)
  end

  # Las secciones del profesor: son datos, no menú fijo, así que se arman aparte.
  #
  # ⚠️ Agrupadas por NIVEL, no en una lista sola (QA de Daniel: «lo mismo con
  # ese chorrero de secciones, hay que dividirlas por Nivel»). Un profesor de
  # Matemática con diecinueve secciones tenía diecinueve renglones seguidos
  # donde primaria y bachillerato se pisaban.
  #
  # ⚠️ Se AGRUPA, no se filtra, y esa es la diferencia con la barra de arriba.
  # El filtro de nivel esconde; un encabezado ordena y sigue mostrando todo. En
  # un menú de navegación, esconder es peor: el profesor va a buscar la sección
  # que no ve y concluye que se la quitaron.
  #
  # ⚠️ Sin icono, y es a propósito: un icono distingue categorías distintas
  # —«Asistencia» de «Boletines»—. Diez secciones son diez cosas del MISMO tipo,
  # y el mismo símbolo repetido diez veces no agrega información, agrega ruido.
  # Lo que las distingue es su nombre, que ya está.
  # `grupo_de_mis_secciones` se retiró: era la lista plana por nivel, y la
  # reemplazaron `grupo_de_lo_que_guio` y `grupo_de_lo_que_dicto`. Con quince
  # renglones seguidos, el área no aparecía por ningún lado — así que «1er Año
  # – B» no decía cuál de las dos que Sofía dicta ahí era.

  # ⚠️ Ordenadas por el ORDEN OFICIAL del grado, no por su nombre.
  #
  # Alfabéticamente, «1er Año» va antes que «6to Grado» y el menú queda
  # mezclando primaria con bachillerato. `grades.orden` es el del catálogo del
  # Reglamento de la LOE, que es el que un profesor tiene en la cabeza.
  # ⚠️ Del AÑO y del NIVEL de la sesión.
  #
  # Del año, porque un colegio que ya copió su estructura al año que viene tiene
  # cada sección DOS veces, y el menú las listaba las veinte: «1er Año – A»
  # arriba de «1er Año – A», sin nada que las distinga.
  #
  # Del nivel, porque con «Primaria» puesto arriba el menú tiene que acompañar:
  # un filtro que la barra dice tener y el menú ignora es peor que no tenerlo.
  def mis_secciones
    mis_asignaciones_del_menu.map(&:section).uniq
                .sort_by { |s| [ s.grade.orden || 99, s.grade.name, s.name ] }
  end

  # ⚠️ La hoja de «Dicto» lleva su ÁREA; la de «Soy guía de», no.
  #
  # Es la diferencia entre los dos trabajos, puesta en la URL: como guía entro
  # a la sección entera —la asistencia es de todos— y como docente entro a una
  # asignación. Sin el área, `/secciones/76` obliga a la pantalla a volver a
  # preguntarla con pastillas, que es exactamente lo que este árbol evita.
  def enlace_a_seccion(seccion, area: nil)
    Enlace.new(nombre: "#{seccion.grade.name} – #{seccion.name}",
               icono: nil, ruta: section_path(seccion, area: area&.id),
               estado: estado_de_calificacion(seccion, area: area))
  end

  # Cómo va la carga de notas de esta sección, para pintarla en el menú.
  #
  # Daniel: *«en el panel de cada sección, además de un enlace al detalle, hay
  # un indicativo de si les falta por calificar alguna nota»*.
  #
  # ⚠️ El peor de sus áreas manda. Un profesor que da dos áreas en la misma
  # sección y tiene una al día y otra sin empezar necesita ver que le falta —
  # promediarlas diría «a medias» y esconde que una está en cero.
  # ⚠️ Con ÁREA, el estado es el de ESA asignación; sin ella, el peor de todas.
  #
  # En «Soy guía de» la pregunta es «¿me falta algo en esta sección?» y ahí el
  # peor manda: una al día y otra sin empezar tiene que verse como que falta.
  # En «Dicto → Matemática → 4to A» la pregunta es otra —«¿me falta en ESTA
  # área?»— y responderla con el estado de otra sería mentir en el renglón.
  def estado_de_calificacion(seccion, area: nil)
    avance = avances_del_profesor.select do |ts, _|
      ts.section_id == seccion.id && (area.nil? || ts.subject_id == area.id)
    end.values
    return nil if avance.empty?

    estados = avance.map(&:estado)
    return :vacio    if estados.include?(:vacio)
    return :a_medias if estados.include?(:a_medias)

    # ⚠️ Devuelve `:sin_evaluaciones`, NO `nil`.
    #
    # Con `nil` la sección se dibujaba sin marca ninguna, igual que si el avance
    # no se hubiera podido calcular. Y ese es el estado normal de un colegio en
    # septiembre: el profesor todavía no armó sus evaluaciones. Callarlo lo deja
    # sin saber si el sistema no tiene nada o si no lo está mirando.
    return :sin_evaluaciones if estados.all? { |e| e == :sin_evaluaciones }

    :completo
  end

  # ⚠️ UNA consulta para todo el menú, no una por sección. El menú se dibuja en
  # CADA pantalla, así que una consulta por sección serían diecinueve en cada
  # petición — el error clásico de N+1, en el lugar donde más cuesta.
  def avances_del_profesor
    @avances_del_profesor ||= CargaDeNotas.avance_por_asignacion(mis_asignaciones_del_menu)
  end

  def mis_asignaciones_del_menu
    current_user.teacher&.teacher_sections
                &.del_anio_de_la_sesion&.del_nivel_de_la_sesion
                &.includes(section: :grade) || []
  end
end
