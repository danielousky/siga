require "test_helper"

# Cualquiera se registra y crea su colegio, sin depender de nadie (MOR-158).
#
# ## Esto REVIERTE `MOR-101`, y conviene que se lea como decisión
#
# El registro se cerró porque `users.email` es único en toda la plataforma:
# cualquiera puede quemar el correo de un profesor real registrándolo antes que
# su colegio. Eso **sigue siendo cierto** y se acepta a propósito — la decisión
# de producto es facilidad y velocidad por encima de la seguridad, mientras el
# acceso sea compartir el enlace a mano y no haya publicidad.
#
# ⚠️ Lo que hace tolerable el riesgo es el AISLAMIENTO, no la confianza:
# registrarse crea siempre un colegio nuevo y nunca se une a uno existente, así
# que el daño máximo de un abuso es una fila que no ve nada de nadie. Ese
# invariante es lo primero que prueba este archivo.
class RegistroAbiertoTest < ActionDispatch::IntegrationTest
  setup { @a, _b = dos_colegios_completos }

  # ⚠️ Sin cédula, a propósito (`MOR-196`): el formulario dejó de pedirla y el
  # modelo la deja de exigir a quien abre su propia cuenta.
  DATOS = {
    first_name: "Rosa", last_name: "Mendoza", email: "rosa@nuevo.test",
    password: "clave-larga-123", password_confirmation: "clave-larga-123"
  }.freeze

  COLEGIO = {
    name: "U.E. Nuevo Amanecer", dea_code: "PD00555", location: "Barquisimeto", entidad_federal: "Lara", municipio: "Iribarren",
    parroquia: "Catedral", direccion: "Av. Vargas", telefono: "0251-444-7788"
  }.freeze

  test "la puerta está abierta y lleva a crear el colegio" do
    get new_user_registration_path
    assert_response :success

    assert_difference -> { User.count }, 1 do
      post registrarse_path, params: { user: DATOS }
    end

    assert_redirected_to nuevo_mi_colegio_path
  end

  # ⚠️ El invariante que sostiene todo esto.
  test "registrarse crea un colegio NUEVO, nunca se une a uno existente" do
    registrarse

    assert_difference -> { Current.sin_aislamiento { School.count } }, 1 do
      post mi_colegio_path, params: { school: COLEGIO }
    end

    nuevo = Current.sin_aislamiento { School.find_by!(dea_code: "PD00555") }
    assert_not_equal @a.colegio.id, nuevo.id
    assert_empty Current.sin_aislamiento { Admin.where(user_id: User.find_by(email: DATOS[:email]).id, school_id: @a.colegio.id) },
                 "el que se registró quedó con acceso a un colegio que ya existía"
  end

  test "queda como director, con su suscripción gratis y su ubicación" do
    registrarse
    post mi_colegio_path, params: { school: COLEGIO }

    assert_redirected_to dashboards_administrador_path

    Current.sin_aislamiento do
      colegio = School.find_by!(dea_code: "PD00555")
      persona = User.find_by!(email: DATOS[:email])

      assert_equal persona.id, colegio.registrado_por_id,
                   "no quedó registrado quién lo creó: es la semilla de Account " \
                   "y después no se puede reconstruir"
      assert Admin.exists?(user_id: persona.id, school_id: colegio.id, role: "director")
      assert_equal "Lara", colegio.entidad_federal
      assert_equal "0251-444-7788", colegio.telefono

      suscripcion = Subscription.find_by!(school_id: colegio.id)
      assert suscripcion.gratis?, "un colegio recién registrado tiene que nacer en el Plan Inicial"
      assert_equal 0, suscripcion.precio_mensual.to_i
    end
  end

  # ⚠️ Quien acaba de registrarse no tiene rol, y el layout tapa el contenido con
  # «contacte al administrador» — pero el administrador es él. Sin la excepción,
  # el registro abierto termina en una pared.
  test "sin rol todavía, igual ve el formulario de su colegio" do
    registrarse

    get nuevo_mi_colegio_path

    assert_response :success
    assert_select "form[action=?]", mi_colegio_path
    assert_no_match(/Sin rol asignado/, response.body,
                    "el layout le tapó el formulario: el administrador es él mismo")
  end

  # El RLS rechaza escribir sin contexto de colegio, y el colegio recién existe
  # a mitad de la petición. Si esto falla, vuelve el `PG::InsufficientPrivilege`.
  test "el aislamiento no impide crear el primer rol del colegio nuevo" do
    registrarse

    assert_nothing_raised { post mi_colegio_path, params: { school: COLEGIO } }
    assert_response :redirect
  end

  test "quien ya tiene colegio no puede crear otro por esta puerta" do
    sign_in @a.director

    assert_no_difference -> { Current.sin_aislamiento { School.count } } do
      get nuevo_mi_colegio_path
      post mi_colegio_path, params: { school: COLEGIO }
    end

    assert_response :redirect
  end

  # ⚠️ Qué dicta el colegio NO se pregunta en el alta (MOR-160).
  #
  # `school_type` era excluyente —o primaria o bachillerato— y para la mitad del
  # mercado la respuesta era falsa: un colegio con preescolar y primaria decía
  # «Primaria» a secas. La columna se borró; lo que dicta se DERIVA de sus grados,
  # que se siembran marcando niveles en `/niveles`.
  test "el alta no pregunta qué dicta el colegio: se deriva de los grados" do
    registrarse

    get nuevo_mi_colegio_path
    assert_select "[name='school[school_type]']", 0,
                  "volvió una pregunta que la columna ya no puede responder"

    post mi_colegio_path, params: { school: COLEGIO }
    colegio = Current.sin_aislamiento { School.find_by!(dea_code: "PD00555") }

    # ⚠️ Se lee DENTRO del colegio, y no es ceremonia del test: `niveles` consulta
    # `grades`, que está bajo RLS. Sin contexto la base devuelve cero filas — que
    # es el aislamiento haciendo lo suyo, no un error. El panel de SIGA lo
    # resuelve corriendo dentro de `sin_aislamiento`.
    con_el_colegio(colegio) do
      assert_nil colegio.que_dicta, "un colegio sin grados todavía no dicta nada"

      SembrarGrados.para(colegio, niveles: [ :preescolar, :primaria ])
      assert_equal "Preescolar y Primaria", colegio.que_dicta,
                   "un colegio con dos niveles tiene que poder decir los dos"

      SembrarGrados.para(colegio, niveles: [ :media_tecnica ])
      assert_equal "Preescolar, Primaria, Bachillerato y Media Técnica", colegio.que_dicta,
                   "la Media Técnica es un nivel más, y arrastra el bachillerato"
    end
  end


  private

  def registrarse
    post registrarse_path, params: { user: DATOS }
    follow_redirect!
  end

  # ── Lo que el registro NO pide, y lo que sí manda (MOR-196) ───────────────

  # Daniel: «no debería pedirse la CI en este momento; además, al director (o
  # asistente) ese dato es irrelevante».
  test "el formulario no pide la cédula" do
    get new_user_registration_path

    assert_empty css_select("input[name='user[document]']"), "sigue pidiendo la cédula"
    assert_empty css_select("select[name='user[document_type]']")
  end

  # ⚠️ Que no la pida la PANTALLA no alcanza: si el modelo la sigue exigiendo,
  # el registro devuelve 422 y la persona no entiende qué le falta.
  test "registrarse sin cédula funciona de punta a punta" do
    assert_difference "User.count", 1 do
      post registrarse_path, params: { user: DATOS }
    end

    persona = User.find_by(email: DATOS[:email])
    assert_nil persona.document, "no debería haber cédula"
    assert_redirected_to nuevo_mi_colegio_path
  end

  # ⚠️ Pero el alumno que carga el colegio SÍ la sigue necesitando: va a salir
  # en un boletín. Aflojar la regla para todos era el error fácil acá.
  test "un registro que NO se registró solo sigue exigiendo identificador" do
    alumno = User.new(first_name: "Ana", last_name: "Pérez", email: "ana@familia.test")

    assert_not alumno.valid?
    assert_match(/cédula/, alumno.errors.full_messages.to_sentence)
  end

  # Daniel: «hay que enviarle un correo cuando se registren, eso no lo tenemos
  # configurado».
  test "quien se registra recibe su correo de bienvenida" do
    assert_emails 1 do
      perform_enqueued_jobs { post registrarse_path, params: { user: DATOS } }
    end

    correo = ActionMailer::Base.deliveries.last
    assert_equal [ DATOS[:email] ], correo.to
    assert_equal "Bienvenido a SIGA", correo.subject
  end

  # ⚠️ El mismo filtro que el resto de la app, no una lista escrita acá
  # (`MOR-191`): si se copia, se despareja.
  test "los nombres solo aceptan letras" do
    get new_user_registration_path

    %w[first_name last_name].each do |campo|
      entrada = css_select("input[name='user[#{campo}]']").first
      assert_equal Normaliza::LETRAS_DE_NOMBRE, entrada["data-campo-filtrado-permite-value"],
                   "#{campo} no usa el filtro compartido"
    end
  end
end
