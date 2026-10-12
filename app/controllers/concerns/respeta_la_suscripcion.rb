# Lo que la suscripción le permite hacer a un colegio, en dos reglas:
#
#     VENCIDA  ──►  solo lectura: ve y descarga todo, no carga nada nuevo (MOR-108)
#     GRATIS   ──►  carga todo; operar y sacar papeles, con la suscripción
#                   (spec `docs/specs/del-registro-al-cobro.md`, decisión 3)
#
# ## Por qué solo lectura y no corte de acceso
#
# Lo dice el propio issue, y es la decisión más importante de todo el módulo:
#
# > *"Cortar el acceso a un colegio a mitad de año escolar es quitarle las notas
# > de sus alumnos — se gana la disputa de cobranza y se pierde el cliente y su
# > reputación en la red."*
#
# En un mercado de 3.900 instituciones que se conocen entre sí, esa reputación
# vale muchísimo más que una mensualidad. El colegio sigue viendo todo,
# descargando boletines y emitiendo constancias; lo que no puede es cargar nada
# nuevo hasta ponerse al día.
#
# ## Se bloquea por VERBO, no por pantalla
#
# La tentación es esconder los botones de "Guardar". Eso no es solo lectura: es
# una sugerencia. Acá se rechaza cualquier `POST`, `PATCH`, `PUT` o `DELETE`
# antes de que llegue al controller, así que armar la petición a mano tampoco
# sirve — y no hay que acordarse de nada en cada pantalla nueva.
#
# Es la misma lección que dejó `/demo_requests`: **tapar la puerta no alcanza si
# la pared tiene ventana.**
module RespetaLaSuscripcion
  extend ActiveSupport::Concern

  # Lo que sigue funcionando aunque la suscripción esté vencida.
  #
  # Son dos grupos, y los dos importan:
  #
  # **La sesión.** Cerrar sesión y cambiarse la contraseña no son "escribir en el
  # sistema": dejar a alguien encerrado sin poder salir sería un error distinto
  # y peor.
  #
  # **Los documentos oficiales.** Emitir un boletín o una constancia son `POST`
  # por cómo están construidos —producen un PDF y hay que decirles de quién—,
  # pero lo que hacen es LEER información que ya existe. Bloquearlos castiga a
  # la familia que necesita una constancia para el pasaporte, no al colegio que
  # debe la mensualidad. Es la misma lógica que decidió "solo lectura y no corte
  # de acceso": la deuda es del colegio, el perjuicio no puede ser del alumno.
  SIEMPRE_PERMITIDO = [
    ["devise/sessions", "destroy"],
    ["devise/sessions", "create"],
    ["devise/registrations", "update"],
    ["devise/passwords", "create"],
    ["devise/passwords", "update"],
    ["constancias", "create"],
    ["report_cards", "create"],
    # ⚠️ Los certificados por sección se emiten por POST, y los de la ficha por
    # GET. Sin esta línea, el colegio endeudado perdía por la pestaña nueva un
    # papel que por la ficha sigue sacando — el mismo certificado, del mismo
    # alumno, según por qué puerta se pida.
    ["certificados", "create"]
  ].freeze

  VERBOS_QUE_ESCRIBEN = %w[POST PATCH PUT DELETE].freeze

  # ── La frontera de lo gratis ──────────────────────────────────────────────
  #
  # Daniel, 9 de octubre de 2026: *«dejar libre la entrada pero limitar el
  # procesamiento (calificar o asistencia) y la salida»*.
  #
  #     ENTRADA         cargar e importar           libre, sin tope y sin fecha
  #     PROCESAMIENTO   calificar, pasar lista…     con la suscripción
  #     SALIDA          boletines, listas, portales con la suscripción
  #
  # El corte NO es por número de registros: con matrícula promedio de 360 y
  # tope en 200, la importación falla en la fila 201 y el colegio queda a
  # medias, con un problema de datos, justo cuando debía sentirse poderoso.
  #
  # ## ⚠️ Cada controlador del colegio está en UNA de cuatro listas
  #
  # Y un test lo exige (`frontera_de_lo_gratis_test`). Es lo que cerró los ocho
  # huecos: la lista anterior nombraba lo que existía el 27 de agosto de 2026, y
  # lo construido después —cerrar el lapso, reparaciones, valoraciones,
  # informes, la cobranza, la descarga del boletín, las listas en Excel, los
  # correos a las familias— quedó afuera sin que nada avisara. Con un preescolar
  # se operaba completo sin pagar. Ahora un controlador nuevo sin lista no pasa
  # el CI, y si llegara a producción sin ella, en gratis queda CERRADO.

  # Lo que no es del colegio: lo público, la sesión y la cuenta. Nunca se toca.
  SIEMPRE_ABIERTO = %w[
    activaciones demo_requests devise/passwords devise/registrations devise/sessions
    directorio inicio manual planteles registros salud verificaciones
  ].freeze

  # Cargar. Libre en gratis —es lo que hace que un colegio llegue a necesitar el
  # boletín—, salvo los archivos: una lista en Excel ya es SALIDA.
  LA_ENTRADA = %w[
    academic_periods admins anio_escolar arranque buscadores busquedas carga_de_notas
    codigos_a_la_vista colegio competencies copias_del_anio dashboards/activity_logs
    dashboards/administrador dashboards/profesor departments enrollments
    evaluation_activities evaluation_moments grade_subjects grades importaciones
    indicators nivel_escolar niveles promociones representatives rubrics sections
    students subjects teacher_sections teachers
  ].freeze

  # Operar. Las pantallas SE VEN —una pantalla escondida no vende nada; una que
  # se ve y no se toca, sí— pero escribir y descargar piden la suscripción.
  CON_SUSCRIPCION = %w[
    activity_grades asistencias certificados cobros constancias finanzas informes
    mensajes reparaciones report_cards revision_de_boletines valoraciones
  ].freeze

  # Lo que sale del colegio hacia las familias, los alumnos y el ministerio. En
  # gratis ni se abre.
  SOLO_CON_SUSCRIPCION = %w[
    boletines dashboards/estudiante dashboards/notas documentos_oficiales pagos representante
  ].freeze

  # Los únicos archivos que salen sin suscripción: la plantilla que el colegio
  # llena para CARGAR. El manual en PDF también sale, pero ese vive en
  # `SIEMPRE_ABIERTO`: es público.
  ARCHIVOS_LIBRES = [ %w[importaciones plantilla] ].freeze

  FORMATOS_DE_ARCHIVO = %i[pdf xlsx csv].freeze

  # Lo que ven quienes no pagan la suscripción —profesores, familias, alumnos—:
  # que la función existe y no está activa, sin precios que no les corresponden.
  MURO_SIN_PRECIO = "Calificar, pasar lista y emitir todavía no están activos en el " \
                    "colegio: se activan con la suscripción, que lleva la dirección.".freeze

  included do
    before_action :exigir_suscripcion_al_dia!
    before_action :exigir_plan_del_colegio!
    helper_method :suscripcion_del_colegio, :colegio_en_solo_lectura?, :colegio_en_plan_gratis?
  end

  private

  def suscripcion_del_colegio
    return nil if Current.school_id.blank?
    return @suscripcion_del_colegio if defined?(@suscripcion_del_colegio)

    @suscripcion_del_colegio = Subscription.find_by(school_id: Current.school_id)
  end

  def colegio_en_solo_lectura?
    suscripcion_del_colegio.present? && suscripcion_del_colegio.solo_lectura?
  end

  # ⚠️ Un colegio SIN fila cuenta como gratis (decisión 16). Hasta el 12 de
  # octubre de 2026 era lo contrario —acceso completo, sin fecha— y por esa
  # puerta se entraba a todo el producto gratis y para siempre. Hoy todo colegio
  # nace con su fila; esto es la red por si alguno no la tuviera.
  #
  # Sin colegio en la sesión no hay nada que exigir: es una página pública o la
  # cuenta de alguien.
  def colegio_en_plan_gratis?
    return false if Current.school_id.blank?

    suscripcion_del_colegio.nil? || suscripcion_del_colegio.gratis?
  end

  def exigir_plan_del_colegio!
    return unless colegio_en_plan_gratis?
    return unless requiere_suscripcion?

    # ⚠️ Un portal no se contesta con un redirect: el destino por defecto de una
    # familia ES su portal, y redirigirla a él la dejaría dando vueltas. Se le
    # muestra una página que dice qué pasa, como con la deuda de la familia.
    if SOLO_CON_SUSCRIPCION.include?(controller_path) && request.format.html?
      return render("shared/sin_suscripcion", status: :payment_required)
    end

    respond_to do |formato|
      formato.html { redirect_back fallback_location: dashboard_path_for_user, alert: mensaje_del_muro }
      formato.json { render json: { estado: "error", mensaje: mensaje_del_muro }, status: :payment_required }
      formato.any  { head :payment_required }
    end
  end

  def requiere_suscripcion?
    case controller_path
    when *SIEMPRE_ABIERTO      then false
    when *SOLO_CON_SUSCRIPCION then true
    when *CON_SUSCRIPCION      then escribe? || pide_un_archivo?
    when *LA_ENTRADA           then pide_un_archivo? && !archivo_libre?
    else true
    end
  end

  def escribe? = VERBOS_QUE_ESCRIBEN.include?(request.request_method)

  def pide_un_archivo? = FORMATOS_DE_ARCHIVO.include?(request.format.symbol)

  def archivo_libre? = ARCHIVOS_LIBRES.include?([ controller_path, action_name ])

  # El muro dice el precio a quien lo paga (decisión 14: dirección y finanzas).
  # Con eso, «se activa con la suscripción» deja de ser un callejón: el director
  # sabe cuánto le cuesta lo que acaba de tocar, sin buscarlo.
  def mensaje_del_muro
    return MURO_SIN_PRECIO unless puede?(:pagar_la_suscripcion)

    cotizacion = (suscripcion_del_colegio || Subscription.new(school_id: Current.school_id)).cotizacion
    total      = helpers.numero_en_dolares(cotizacion.total)

    detalle =
      if cotizacion.en_el_minimo?
        "el mínimo de #{helpers.numero_en_dolares(cotizacion.minimo)}, más IVA"
      else
        "#{helpers.contar(cotizacion.alumnos, 'alumno', 'alumnos')} a " \
          "#{helpers.numero_en_dolares(cotizacion.por_alumno)}, más IVA"
      end

    "Calificar, pasar lista y emitir se activan con la suscripción: #{total} al mes (#{detalle})."
  end

  def exigir_suscripcion_al_dia!
    return unless VERBOS_QUE_ESCRIBEN.include?(request.request_method)
    return if SIEMPRE_PERMITIDO.include?([controller_path, action_name])
    return unless colegio_en_solo_lectura?

    mensaje = "La suscripción del colegio está vencida. Puedes seguir consultando " \
              "y descargando todo, pero no cargar información nueva hasta regularizar el pago."

    respond_to do |formato|
      formato.html { redirect_back fallback_location: dashboard_path_for_user, alert: mensaje }
      formato.json { render json: { estado: "error", mensaje: mensaje }, status: :payment_required }
      formato.any  { head :payment_required }
    end
  end
end
