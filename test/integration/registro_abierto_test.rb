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

  DATOS = {
    first_name: "Rosa", last_name: "Mendoza", document: "V-19876543",
    document_type: "cedula_v", email: "rosa@nuevo.test",
    password: "clave-larga-123", password_confirmation: "clave-larga-123"
  }.freeze

  COLEGIO = {
    name: "U.E. Nuevo Amanecer", dea_code: "PD00555", location: "Barquisimeto",
    school_type: "secondary", entidad_federal: "Lara", municipio: "Iribarren",
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

  # ⚠️ Preguntar dos veces la misma cosa le enseña a la persona que el sistema
  # no se acuerda de lo que le dijo. El alta preguntaba «qué dicta
  # principalmente» y dos pantallas después `/niveles` volvía a preguntarlo,
  # mejor. El tipo se DEDUCE de los grados en `SembrarGrados`.
  test "el alta no pregunta qué dicta el colegio: se deduce de los niveles" do
    registrarse

    get nuevo_mi_colegio_path
    assert_select "[name='school[school_type]']", 0,
                  "el alta volvió a preguntar el tipo, que `/niveles` ya pregunta mejor"

    post mi_colegio_path, params: { school: COLEGIO.except(:school_type) }
    colegio = Current.sin_aislamiento { School.find_by!(dea_code: "PD00555") }

    con_el_colegio(colegio) { SembrarGrados.para(colegio, niveles: [ :primaria ]) }
    assert_equal "primary", colegio.reload.school_type

    con_el_colegio(colegio) { SembrarGrados.para(colegio, niveles: [ :secundaria ]) }
    assert_equal "secondary", colegio.reload.school_type,
                 "un colegio con bachillerato es `secondary` aunque también dé primaria"
  end

  private

  def registrarse
    post registrarse_path, params: { user: DATOS }
    follow_redirect!
  end
end
