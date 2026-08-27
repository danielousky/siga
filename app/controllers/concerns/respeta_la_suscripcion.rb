# Un colegio con la suscripción vencida pasa a SOLO LECTURA (MOR-108).
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
    ["report_cards", "create"]
  ].freeze

  VERBOS_QUE_ESCRIBEN = %w[POST PATCH PUT DELETE].freeze

  # ── El plan gratuito (MOR-156) ────────────────────────────────────────────
  #
  # ## Qué queda libre y por qué
  #
  # **Cargar es libre. Operar el colegio, no.** Un colegio que no puede terminar
  # de cargar su matrícula nunca llega al momento en que el boletín le importa:
  # se queda con media planilla adentro, un problema de datos y la sensación de
  # que el sistema se rompió. Ahí no hay conversión, hay un cliente perdido.
  #
  # Lo que se activa con el plan es lo que el colegio HACE todos los días con
  # esos datos: calificar, pasar lista, emitir papeles, y el portal por donde la
  # familia entra.
  #
  # ## Se puede MIRAR, no hacer
  #
  # Las pantallas no se esconden. El director entra a la planilla de notas, ve
  # su sección, sus alumnos y sus columnas — y el aviso de qué la activa. Una
  # pantalla escondida no vende nada; una pantalla que se ve y no se toca, sí.
  ACCIONES_CON_PLAN = [
    [ "activity_grades", "create" ],
    [ "activity_grades", "update" ],
    [ "activity_grades", "destroy" ],
    [ "asistencias", "create" ],
    [ "report_cards", "create" ],
    [ "constancias", "create" ]
  ].freeze

  # Pantallas enteras que el plan gratuito no incluye. Van por controlador y no
  # por verbo porque son GET: un PDF del MPPE se pide con GET, y el portal del
  # representante es de solo lectura por diseño.
  CONTROLADORES_CON_PLAN = %w[documentos_oficiales representante].freeze

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

  # ⚠️ Sin suscripción se PUEDE escribir, y es deliberado: son los colegios que
  # todavía no se facturan —una demo, un piloto, el primer mes—. Bloquearlos
  # sería romper el producto para quien lo está evaluando, que es exactamente al
  # revés de lo que conviene.
  def colegio_en_solo_lectura?
    suscripcion_del_colegio.present? && suscripcion_del_colegio.solo_lectura?
  end

  # ⚠️ Sin fila de suscripción hay acceso COMPLETO, igual que para escribir: es
  # el piloto y el primer mes. `gratis` es una decisión escrita, no la ausencia
  # de una.
  def colegio_en_plan_gratis?
    suscripcion_del_colegio.present? && !suscripcion_del_colegio.incluye_las_funciones_del_colegio?
  end

  def exigir_plan_del_colegio!
    return unless colegio_en_plan_gratis?
    return unless requiere_plan?

    mensaje = "Calificar, pasar lista y emitir documentos se activan con un plan. " \
              "Cargar alumnos, profesores y materias es libre y no vence."

    respond_to do |formato|
      formato.html { redirect_back fallback_location: dashboard_path_for_user, alert: mensaje }
      formato.json { render json: { estado: "error", mensaje: mensaje }, status: :payment_required }
      formato.any  { head :payment_required }
    end
  end

  def requiere_plan?
    CONTROLADORES_CON_PLAN.include?(controller_path) ||
      ACCIONES_CON_PLAN.include?([ controller_path, action_name ])
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
