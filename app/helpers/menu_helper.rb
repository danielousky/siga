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
  Enlace = Data.define(:nombre, :icono, :ruta, :tambien_en) do
    def initialize(nombre:, icono:, ruta:, tambien_en: []) = super
  end

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
  Grupo = Data.define(:titulo, :enlaces, :abierto_por_defecto) do
    def initialize(titulo: nil, enlaces:, abierto_por_defecto: false) = super

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
      Grupo.new(titulo: "Configuración", enlaces: enlaces_de_configuracion)
    ].reject { |grupo| grupo.enlaces.empty? }
  end

  def menu_del_profesor
    [
      Grupo.new(enlaces: [ Enlace.new(nombre: "Inicio", icono: :panel, ruta: dashboards_profesor_path) ]),
      Grupo.new(titulo: "Mi trabajo", enlaces: [
        Enlace.new(nombre: "Mis evaluaciones", icono: :notas, ruta: evaluation_activities_path),
        Enlace.new(nombre: "Asistencia", icono: :asistencia, ruta: asistencias_path)
      ]),
      *grupo_de_mis_secciones
    ]
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

  # Los papeles que emite el colegio. Los dos son «elegir sección, elegir alumno,
  # emitir»: la misma tarea con distinto papel al final.
  def pestanas_de_documentos
    [
      [ "Boletines", report_cards_path, controller_name == "report_cards" ],
      [ "Constancias", constancias_path, controller_name == "constancias" ]
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
  def enlace_activo?(enlace)
    return true if enlace.tambien_en.include?(controller_path)

    destino = Rails.application.routes.recognize_path(enlace.ruta)
    destino[:controller] == controller_path
  rescue ActionController::RoutingError, ActionController::UrlGenerationError
    false
  end

  def grupo_activo?(grupo)
    grupo.enlaces.any? { |enlace| enlace_activo?(enlace) }
  end

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
    enlaces << Enlace.new(nombre: "Materias", icono: :materias, ruta: subjects_path)
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
                            ruta: report_cards_path, tambien_en: %w[constancias])
    end
    enlaces << Enlace.new(nombre: "Registro de actividad", icono: :auditoria,
                          ruta: dashboards_activity_logs_path)
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
    enlaces << Enlace.new(nombre: "Importar datos", icono: :subir, ruta: importaciones_path)
    if can_manage_academic_config?
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
  # ⚠️ Sin icono, y es a propósito: un icono distingue categorías distintas
  # —«Asistencia» de «Boletines»—. Diez secciones son diez cosas del MISMO tipo,
  # y el mismo símbolo repetido diez veces no agrega información, agrega ruido.
  # Lo que las distingue es su nombre, que ya está.
  def grupo_de_mis_secciones
    secciones = current_user.teacher&.teacher_sections&.includes(section: :grade) || []
    return [] if secciones.empty?

    enlaces = secciones.map do |ts|
      Enlace.new(nombre: "#{ts.section.grade.name} – #{ts.section.name}",
                 icono: nil, ruta: section_path(ts.section))
    end

    [ Grupo.new(titulo: "Mis secciones", enlaces: enlaces) ]
  end
end
