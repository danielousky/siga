class ApplicationController < ActionController::Base
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

  # Hacer disponibles los helpers de rol en los controladores
  helper_method :current_user_type, :estudiante?, :profesor?, :administrador?, :representante?
  helper_method :colegios_del_representante
  helper_method :can_manage_students?, :can_manage_teachers?, :can_manage_sections?
  helper_method :can_manage_academic_config?, :show_recent_activity?

  # Redirección post-login personalizada por tipo de usuario
  def after_sign_in_path_for(resource)
    # Al abrir esta petición no había sesión, así que Current quedó vacío.
    # Ahora que Devise autenticó, el colegio ya se puede resolver.
    establecer_colegio(resource)

    log_activity(
      action:  "login",
      message: "#{resource.name} #{resource.last_name} inició sesión"
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

  def estudiante?
    current_user_type == :estudiante
  end

  def profesor?
    current_user_type == :profesor
  end

  def administrador?
    current_user_type == :administrador
  end

  # Helpers de autorización para admins
  def can_manage_students?
    administrador? && %w[desarrollador director secretaria coordinador].include?(current_user.admin.role)
  end

  def can_manage_teachers?
    administrador? && %w[desarrollador director].include?(current_user.admin.role)
  end

  def can_manage_sections?
    administrador? && %w[desarrollador director coordinador].include?(current_user.admin.role)
  end

  def can_manage_academic_config?
    administrador? && %w[desarrollador director].include?(current_user.admin.role)
  end

  def show_recent_activity?
    administrador? && %w[desarrollador director].include?(current_user.admin.role)
  end

  def dashboard_path_for_user
    # El equipo de SIGA no tiene rol de colegio, así que va a su propia
    # administración. Va PRIMERO porque `current_user_type` sería nil para
    # ellos y caerían en la pantalla de "sin rol asignado" (MOR-133).
    return siga_root_path if SigaStaff.para(current_user).present?

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
