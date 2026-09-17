class ApplicationController < ActionController::Base
  include LlevaElRecorrido
  include Pagy::Backend
  include Auditable
  before_action :authenticate_user!

  # El contexto de colegio de toda la petición.
  #
  # Va en un `around_action` y NO en un `before_action`, y la razón es el RLS:
  # la variable de sesión de Postgres se setea con `SET LOCAL`, que solo existe
  # dentro de una transacción. Con `before_action` habría que abrir la
  # transacción en otro lado y el alcance no coincidiría.
  #
  # Y es un solo enganche para las dos capas a propósito: si el `default_scope`
  # y el RLS se establecieran en momentos distintos, habría una ventana donde
  # uno filtra y el otro no.
  around_action :con_el_colegio_de_la_sesion

  # ⚠️ TAMBIÉN después del `around_action`, y por la MISMA razón que lo de abajo
  # (MOR-165). Estuvo arriba de todo y falló exactamente igual: sin
  # `Current.school`, el RLS devuelve cero años escolares, así que
  # `fijar_el_anio_escolar` salía por su `return` y `Current.academic_period`
  # quedaba en nil.
  #
  # Y falló en silencio, como el otro: los listados no filtraban —se veían las
  # secciones de todos los años— y crear un lapso decía «Período académico debe
  # existir» sin ninguna pista de por qué. Lo encontró el test de MOR-165.
  include LlevaElAnioEscolar

  # ⚠️ Y el nivel, DESPUÉS del año y por la MISMA razón. Ver arriba: sin
  # `Current.school`, el RLS devuelve cero grados y `niveles_para_elegir` sale
  # vacío — el selector no aparecería nunca y el filtro no filtraría, en
  # silencio. Es el tercer concern que depende de este orden.
  include LlevaElNivel

  # ⚠️ Va DESPUÉS del `around_action`, y el orden no es estético: es lo único que
  # hace que este control funcione.
  #
  # Rails ordena `before_action` y `around_action` en una sola cadena, por orden
  # de declaración. Con el `include` arriba de todo, la comprobación corría ANTES
  # de que `con_el_colegio_de_la_sesion` fijara `Current.school` — así que no
  # encontraba suscripción y **dejaba pasar todo, en silencio**.
  #
  # Es la peor forma de fallar que puede tener un control de acceso: no explota,
  # no avisa, y parece que funciona. Lo encontró un test que esperaba un 402 y
  # recibió un 200; sin ese test habría quedado puesto y sin efecto.
  #
  # Un colegio con la suscripción vencida pasa a solo lectura (MOR-108). Se
  # bloquea por VERBO y no por pantalla: esconder los botones de guardar no es
  # solo lectura, es una sugerencia.
  include RespetaLaSuscripcion
  # El equipo de SIGA puede entrar a un colegio a dar soporte. Decisión con
  # fecha de vencimiento: ver el comentario del concern y MOR-92.
  include AccesoDelEquipoDeSiga

  # Hacer disponibles los helpers de rol en los controladores
  helper_method :current_user_type, :estudiante?, :profesor?, :administrador?, :representante?
  helper_method :colegios_del_representante
  helper_method :can_manage_students?, :can_manage_teachers?, :can_manage_sections?
  helper_method :can_manage_academic_config?, :show_recent_activity?, :rol_de_admin

  # Redirección post-login personalizada por tipo de usuario
  def after_sign_in_path_for(resource)
    # Al abrir esta petición no había sesión, así que Current quedó vacío.
    # Ahora que Devise autenticó, el colegio ya se puede resolver.
    establecer_colegio(resource)

    log_activity(
      action:  "login",
      message: "#{resource.nombre_completo} inició sesión"
    )
    dashboard_path_for_user
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  private

  # Establece el colegio de la petición y lo aplica en las DOS capas:
  # el `default_scope` de la app y la política de RLS de Postgres.
  #
  # Todo corre dentro de una transacción porque `SET LOCAL` solo existe ahí. Es
  # lo que hace que la variable no sobreviva a la petición: cuando la transacción
  # termina, Postgres la descarta sola. Con `SET` a secas quedaría pegada a la
  # conexión, y la siguiente petición que la tomara del pool heredaría el colegio
  # de la anterior — justo la fuga que se quiere evitar, pero más difícil de ver.
  def con_el_colegio_de_la_sesion
    ActiveRecord::Base.transaction do
      establecer_colegio(current_user)
      yield
    end
  ensure
    Current.reset
  end

  # Fija el colegio en las dos capas. Se llama al abrir la petición y otra vez
  # en `after_sign_in_path_for`, porque al empezar la petición de login todavía
  # no hay sesión y el usuario aparece recién después de autenticar.
  def establecer_colegio(usuario)
    Current.school = colegio_de(usuario)

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array(
        ["SELECT set_config('siga.school_id', ?, true)", Current.school_id.to_s]
      )
    )
  end

  # El colegio sale del ROL del usuario. Nunca de un parámetro: ni de la URL, ni
  # de un header, ni de un campo del formulario.
  #
  # ⚠️ Va con `sin_aislamiento` y hay una razón de fondo: **averiguar de qué
  # colegio es alguien es anterior a poder filtrar por colegio.** Las tablas de
  # roles están protegidas por el mismo aislamiento que se quiere establecer, así
  # que sin esto la consulta devolvería cero filas y ningún usuario tendría
  # colegio jamás. Es el arranque del aislamiento, no un agujero en él.
  #
  # Lo que lo mantiene acotado es que solo busca las filas de ESTE usuario, por
  # su clave primaria, y devuelve un colegio — no expone ningún otro dato.
  #
  # Devuelve nil para un usuario sin rol, que es un caso real: la app degrada a
  # la vista "sin rol" y el RLS no le muestra nada.
  def colegio_de(usuario)
    return nil if usuario.blank?

    # El equipo de SIGA visitando un colegio. Va primero porque no tienen rol de
    # colegio: sin esto, entrar no les mostraría nada (MOR-133).
    return colegio_visitado if visitando_un_colegio?

    Current.sin_aislamiento do
      Student.find_by(user_id: usuario.id)&.school ||
        Teacher.find_by(user_id: usuario.id)&.school ||
        Admin.find_by(user_id: usuario.id)&.school ||
        colegio_del_representante(usuario)
    end
  end

  # El único caso donde la sesión participa de elegir el colegio, y conviene
  # entender exactamente por qué NO es una excepción a la regla de arriba.
  #
  # Un representante puede tener hijos en dos colegios: su usuario es uno, sus
  # inquilinos son dos, y `Current.school` es uno por petición. Alguien tiene que
  # elegir, y esa elección es del representante.
  #
  # ⚠️ **La sesión SELECCIONA entre colegios ya verificados; no concede acceso a
  # ninguno.** El conjunto sale de sus filas de `Representative` —vínculos que
  # cargó el colegio, no él— y un id que no esté en ese conjunto se descarta sin
  # más. Mandar el id de un colegio ajeno no cambia nada: cae en el `||`.
  #
  # Esa distinción es toda la seguridad de este camino. La regla nunca fue "el
  # colegio no puede venir de la sesión": es **"el colegio no puede venir de algo
  # que el usuario controla sin que el sistema lo haya verificado"**. Acá lo
  # verificado es el vínculo; la sesión solo desempata.
  def colegio_del_representante(usuario)
    colegios = Representative.where(user_id: usuario.id).includes(:school).map(&:school)

    return colegios.first if colegios.size <= 1

    colegios.find { |c| c.id == session[:colegio_elegido_id] } || colegios.first
  end

  # Identificación de tipo de usuario.
  #
  # `representante` va ÚLTIMO a propósito: una maestra puede ser además madre de
  # un alumno del colegio, y en ese caso lo que necesita al entrar es su
  # planilla de notas, no el boletín de su hijo. Ese lo alcanza igual desde el
  # menú; al revés, tendría que salir y volver a entrar para dar clase.
  def current_user_type
    return :estudiante if current_user.student.present?
    return :profesor if current_user.teacher.present?
    return :administrador if current_user.admin.present?
    return :administrador if visitando_un_colegio?
    return :representante if representante?

    nil
  end

  # Sin aislamiento por la misma razón que `colegio_de`: averiguar quién es
  # alguien es anterior a poder filtrar por colegio. Solo mira las filas de ESTE
  # usuario, por su id.
  def representante?
    return @es_representante if defined?(@es_representante)

    @es_representante = current_user.present? &&
                        Current.sin_aislamiento { Representative.exists?(user_id: current_user.id) }
  end

  # Los colegios donde esta persona representa a alguien. Vacío para todos los
  # demás roles.
  def colegios_del_representante
    return [] unless representante?

    @colegios_del_representante ||=
      Current.sin_aislamiento do
        Representative.where(user_id: current_user.id).includes(:school).map(&:school)
      end
  end

  # Quién cobra. ⚠️ La coordinadora y la secretaria NO, aunque las dos
  # administren alumnos: el dinero es otra gaveta.
  #
  # Vive acá —y no en `FinanzasController`— porque el MENÚ tiene que hacerse la
  # misma pregunta: un grupo «Finanzas» que se ve y rebota enseña que los
  # enlaces de este sistema a veces no funcionan.
  def puede_cobrar? = puede?(:cobrar)
  helper_method :puede_cobrar?

  def estudiante?
    current_user_type == :estudiante
  end

  def profesor?
    current_user_type == :profesor
  end

  # Mientras visita un colegio, el equipo de SIGA lo ve como lo vería su
  # dirección. Sin esto la visita daría contexto de colegio y ningún rol, así
  # que cada pantalla rebotaría — la visita no serviría de nada.
  def administrador?
    current_user_type == :administrador || visitando_un_colegio?
  end

  # Helpers de autorización para admins.
  #
  # `rol_de_admin` en vez de `current_user.admin.role` porque el equipo de SIGA
  # visitando un colegio no tiene registro de `Admin`: ve como dirección sin
  # pertenecer al colegio.
  def rol_de_admin
    return "director" if visitando_un_colegio? && current_user.admin.nil?

    current_user.admin&.role
  end

  # ⚠️ `asistente` puede lo mismo que `director`, y es una decisión (MOR-208).
  #
  # Daniel, definiendo quién abre la cuenta: *«puedes preguntarle el cargo para
  # saber si es director o asistente»*. O sea que un asistente PUEDE ser el
  # único usuario del colegio — y un colegio cuyo único usuario no puede
  # configurarlo está roto antes de empezar.
  #
  # Además es quien de verdad opera el sistema en un colegio venezolano: el
  # director firma, la asistencia de dirección carga. Darle menos sería modelar
  # el organigrama y no el trabajo.
  #
  # El día que haga falta distinguirlos —que un asistente no pueda tocar la
  # estructura académica, por ejemplo— este es el único lugar donde se cambia.
  DIRECCION = %w[desarrollador director asistente].freeze

  # ⚠️ Los tres GRUPOS de trabajo de un colegio, y las funciones repartidas
  # entre ellos como un DATO.
  #
  # Daniel, definiendo el modelo: *«Directivo (Director: ve y hace todo,
  # inclusive crear otros admins y usuarios), Finanzas: para la parte de
  # cobranzas y pagos (no ve mucho más de eso), y el otro el que vendría siendo
  # el académico, que hace las gestiones generales del plantel (secretarias,
  # coordinadores, control de estudio)»*.
  #
  #     DIRECTIVO   desarrollador · director · asistente
  #     ACADÉMICO   coordinador · secretaria
  #     FINANZAS    finanzas
  #
  # ⚠️ El ENUM no se toca. Daniel: *«no es un rol nuevo… hay que revisar lo que
  # se le permite a cada quien»*. Renumerar `Admin.roles` rompería las filas ya
  # guardadas, que apuntan al número y no al nombre; lo que cambia es el reparto.
  #
  # ⚠️ Y el reparto vive en UNA tabla, no en cinco métodos con su lista a mano.
  #
  # Estaba escrito como `DIRECCION + %w[secretaria coordinador]` en un método y
  # `DIRECCION + %w[coordinador]` en otro, así que la respuesta a «¿qué puede
  # hacer una secretaria?» había que armarla leyendo cinco cuerpos. Con la tabla
  # se lee de un vistazo, que es lo que hace posible discutirla con un director.
  ACADEMICO = %w[coordinador secretaria].freeze
  FINANZAS  = %w[finanzas].freeze

  PERMISOS = {
    # Lo que distingue al DIRECTIVO: crear a la gente que entra al sistema.
    # Daniel: *«inclusive crear otros admins y usuarios»*.
    manage_teachers: DIRECCION,
    manage_admins: DIRECCION,
    # Y ver la bitácora: es donde se contesta «¿quién le cambió esa nota?».
    recent_activity: DIRECCION,

    # Lo ACADÉMICO: la gestión del plantel.
    manage_students: DIRECCION + ACADEMICO,
    manage_sections: DIRECCION + ACADEMICO,
    manage_academic_config: DIRECCION + ACADEMICO,
    # ⚠️ Cerrar la calificación es de ACADÉMICO, no del director.
    #
    # Daniel: *«control de estudio es quien cierra la calificación»* y *«al
    # definir los roles de Admin, a alguno hay que darle esa responsabilidad»*.
    # En un colegio venezolano el vistazo final lo da control de estudio, que
    # acá es coordinación o secretaría — no quien firma.
    emitir_documentos: DIRECCION + ACADEMICO,

    # El DINERO es otra gaveta. La coordinadora administra alumnos y NO valida
    # pagos; finanzas cobra y no toca la estructura académica.
    cobrar: DIRECCION + FINANZAS
  }.freeze

  def puede?(que) = administrador? && PERMISOS.fetch(que).include?(rol_de_admin)
  helper_method :puede?

  def can_manage_students? = puede?(:manage_students)

  def can_manage_teachers? = puede?(:manage_teachers)

  def can_manage_sections? = puede?(:manage_sections)

  # La estructura del colegio —su identidad, sus niveles, sus grados— la
  # administra la dirección. Vive acá y no en un controller porque lo necesitan
  # dos, y una copia privada en cada uno es una copia que se despareja.
  def require_direccion!
    return if can_manage_academic_config?

    redirect_to dashboard_path_for_user,
                alert: "Esta parte del colegio la administra la dirección."
  end

  def can_manage_academic_config? = puede?(:manage_academic_config)

  def show_recent_activity? = puede?(:recent_activity)

  def dashboard_path_for_user
    # El equipo de SIGA no tiene rol de colegio, así que va a su propia
    # administración. Va PRIMERO porque `current_user_type` sería nil para
    # ellos y caerían en la pantalla de "sin rol asignado" (MOR-133).
    return dashboards_administrador_path if visitando_un_colegio?
    return siga_root_path if equipo_de_siga?

    case current_user_type
    when :administrador then dashboards_administrador_path
    when :profesor      then dashboards_profesor_path
    when :estudiante    then dashboards_estudiante_path
    when :representante then representante_path
    else root_path
    end
  end
  helper_method :dashboard_path_for_user
end
