require "test_helper"

# Cualquiera se registra y su colegio queda armado, en UN paso (MOR-158 · MOR-208).
#
# ## Esto REVIERTE `MOR-101`, y conviene que se lea como decisión
#
# El registro se cerró porque `users.email` es único en toda la plataforma:
# cualquiera puede quemar el correo de un profesor real registrándolo antes que
# su colegio. Eso **sigue siendo cierto** y se acepta a propósito — facilidad y
# velocidad por encima de la seguridad, mientras el acceso sea compartir el
# enlace a mano.
#
# ⚠️ Lo que hace tolerable el riesgo es el AISLAMIENTO, no la confianza:
# registrarse crea siempre un colegio nuevo y nunca se une a uno existente, así
# que el daño máximo de un abuso es una fila que no ve nada de nadie. Ese
# invariante es lo primero que prueba este archivo.
#
# ## Y desde `MOR-208` son DOS pantallas menos
#
#     ANTES                          AHORA
#     ─────                          ─────
#     /registrarse   la persona      /registrarse   la persona Y el colegio
#     /mi-colegio    el colegio             ↓
#     8 pasos a mano                 el andamiaje, sembrado
class RegistroAbiertoTest < ActionDispatch::IntegrationTest
  setup { @a, _b = dos_colegios_completos }

  # ⚠️ Sin cédula, a propósito (`MOR-196`): un director no aparece todavía en
  # ninguna planilla del MPPE, así que no hay a quién identificar.
  PERSONA = {
    first_name: "Rosa", last_name: "Mendoza", email: "rosa@nuevo.test",
    password: "clave-larga-123", password_confirmation: "clave-larga-123"
  }.freeze

  # ⚠️ Solo nombre y DEA. Ubicación, teléfono, dirección, logo y sello salieron
  # del formulario: el colegio los completa cuando quiera.
  COLEGIO = { name: "U.E. Nuevo Amanecer", dea_code: "PD00555" }.freeze

  def registrarse(persona: PERSONA, colegio: COLEGIO, niveles: %w[primaria], cargo: "director")
    post registrarse_path, params: { user: persona, school: colegio,
                                     niveles: niveles, cargo: cargo }
  end

  def nuevo_colegio = Current.sin_aislamiento { School.find_by(dea_code: COLEGIO[:dea_code]) }

  test "un solo envío crea la persona y su colegio" do
    get new_user_registration_path
    assert_response :success

    assert_difference [ -> { User.count }, -> { Current.sin_aislamiento { School.count } } ], 1 do
      registrarse
    end

    assert_redirected_to arranque_listo_path
  end

  # ⚠️ El invariante que sostiene todo esto.
  test "registrarse crea un colegio NUEVO, nunca se une a uno existente" do
    registrarse

    assert_not_equal @a.colegio.id, nuevo_colegio.id
    persona = User.find_by(email: PERSONA[:email])
    assert_empty Current.sin_aislamiento { Admin.where(user_id: persona.id, school_id: @a.colegio.id) },
                 "el que se registró quedó con acceso a un colegio que ya existía"
  end

  test "queda con su cargo y su plan Inicial" do
    registrarse(cargo: "asistente")

    Current.en_el_colegio(nuevo_colegio) do
      assert_equal "asistente", Admin.first.role
      assert_equal "gratis", Subscription.first.plan
      assert_equal "activa", Subscription.first.status
    end
  end

  # ⚠️ LAS TRES opciones dan permisos de dirección, y «Otro cargo» no los daba.
  #
  # Mapeaba a `coordinador`, que no está en `DIRECCION`: quien lo elegía quedaba
  # ENCERRADA —sin poder cargar profesores, ni tocar la configuración académica,
  # ni entrar a `/administradores` para corregirse el rol—. Un callejón sin
  # salida en el minuto uno, y le pasó a la primera directora real.
  test "las tres opciones del registro dan permisos de dirección" do
    Admin::CARGOS_AL_REGISTRARSE.each_key do |cargo|
      rol = Admin.rol_al_registrarse(cargo)

      assert_includes ApplicationController::DIRECCION, rol,
                      "«#{Admin::CARGOS_AL_REGISTRARSE[cargo]}» deja a quien registra sin permisos"
    end
  end

  test "«Otro cargo» queda como asistente, no como coordinador" do
    registrarse(cargo: "otro")

    Current.en_el_colegio(nuevo_colegio) { assert_equal "asistente", Admin.first.role }
  end

  # ⚠️ Un cargo que no se ofrece no se acepta: el formulario manda tres valores,
  # y sin filtrar alguien podría pedir `desarrollador`.
  test "un cargo inventado cae en director" do
    registrarse(cargo: "desarrollador")

    Current.en_el_colegio(nuevo_colegio) { assert_equal "director", Admin.first.role }
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El andamiaje
  # ══════════════════════════════════════════════════════════════════════════

  test "el colegio nace con sus grados, materias, años y lapsos" do
    registrarse(niveles: %w[primaria secundaria])

    Current.en_el_colegio(nuevo_colegio) do
      assert_equal 11, Grade.count, "seis de primaria más cinco del bachillerato"
      assert_operator Subject.count, :>, 0
      assert_equal 5, AcademicPeriod.count, "el que corre y los cuatro anteriores"
      assert_equal 15, EvaluationMoment.count
      assert Grade.all.all? { |g| g.subjects.any? }, "un grado sin materias no puede cargar una nota"
    end
  end

  # ⚠️ Decisión de Daniel: el arranque NO crea departamentos.
  test "no se crean departamentos" do
    registrarse(niveles: %w[primaria secundaria])

    Current.en_el_colegio(nuevo_colegio) { assert_equal 0, Department.count }
  end

  test "los niveles se filtran contra el catálogo" do
    registrarse(niveles: %w[primaria inventado])

    Current.en_el_colegio(nuevo_colegio) { assert_equal 6, Grade.count }
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Cuando algo falla
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ La razón por la que las dos pantallas estaban separadas era justamente
  # ésta: «un error de tipeo le borra el usuario». Con una transacción, si el
  # colegio falla NO queda un usuario huérfano que después no puede registrarse
  # porque su correo «ya está en uso».
  test "si el colegio falla no queda un usuario huérfano" do
    assert_no_difference [ -> { User.count }, -> { Current.sin_aislamiento { School.count } } ] do
      registrarse(colegio: { name: "", dea_code: "" })
    end

    assert_response :unprocessable_entity
    assert_nil User.find_by(email: PERSONA[:email])
  end

  # ⚠️ Los DOS bloques se validan antes de guardar cualquiera: quien se equivoca
  # en el correo y en el DEA tiene que enterarse de las dos cosas de una vez, no
  # corregir una, enviar, y descubrir la otra.
  test "el formulario vuelve con los errores de la persona Y del colegio" do
    registrarse(persona: PERSONA.merge(email: ""), colegio: { name: "", dea_code: "" })

    assert_response :unprocessable_entity
    cuerpo = response.body
    assert_match(/[Cc]orreo/, cuerpo)
    assert_match(/DEA/i, cuerpo)
  end

  test "un DEA repetido lo dice" do
    registrarse
    # ⚠️ Hay que salir primero: registrarse deja la sesión abierta, y quien ya
    # tiene colegio no vuelve a pasar por el formulario —lo prueba el test de
    # abajo—. Sin esto, el segundo intento medía el redirect y no el DEA.
    sign_out :user

    assert_no_difference -> { Current.sin_aislamiento { School.count } } do
      registrarse(persona: PERSONA.merge(email: "otra@nuevo.test"))
    end

    assert_response :unprocessable_entity
  end

  # Registrarse deja la sesión abierta; volver al formulario no puede crear un
  # segundo colegio.
  test "quien ya tiene colegio no vuelve a registrarse" do
    registrarse

    assert_no_difference -> { Current.sin_aislamiento { School.count } } do
      get new_user_registration_path
      registrarse(colegio: { name: "U.E. Otro", dea_code: "PD00999" })
    end

    assert_redirected_to dashboards_administrador_path
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El correo
  # ══════════════════════════════════════════════════════════════════════════

  test "quien se registra recibe su correo de bienvenida" do
    assert_emails 1 do
      perform_enqueued_jobs { registrarse }
    end

    correo = ActionMailer::Base.deliveries.last
    assert_equal [ PERSONA[:email] ], correo.to
    assert_equal "Bienvenido a SIGA · Sistema Integrado de Gestión Académica", correo.subject
    assert_equal %w[text/plain text/html],
                 correo.parts.map { |parte| parte.content_type.split(";").first }
  end

  # ⚠️ Y NO sale si el alta falló: un `deliver_later` dentro de la transacción
  # puede correr después de que se deshaga, y le daría la bienvenida a una
  # cuenta que no existe.
  test "no se manda bienvenida si el alta falló" do
    assert_emails 0 do
      perform_enqueued_jobs { registrarse(colegio: { name: "", dea_code: "" }) }
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La comprobación en vivo del correo
  # ══════════════════════════════════════════════════════════════════════════

  test "dice si un correo está libre" do
    get correo_disponible_path(email: "libre@nuevo.test")
    assert_equal({ "libre" => true, "formato" => true }, response.parsed_body)
  end

  # ⚠️ Se pregunta SIN aislamiento: `users.email` es único en toda la
  # plataforma, así que preguntando dentro de un colegio diría «libre» y el
  # INSERT fallaría igual.
  test "un correo de otro colegio también está tomado" do
    get correo_disponible_path(email: @a.profesor.email)
    assert_equal false, response.parsed_body["libre"]
  end

  test "avisa cuando ni siquiera es un correo" do
    get correo_disponible_path(email: "esto-no-es-un-correo")
    assert_equal false, response.parsed_body["formato"]
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que el formulario NO pide
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ La CÉDULA sigue sin pedirse, y eso no cambió (`MOR-196`).
  #
  # Daniel, mirando el formulario: *«no debería pedirse la CI en este momento;
  # además, al director (o asistente) ese dato es irrelevante»*. Quien abre su
  # propia cuenta se identifica con su CORREO.
  test "no pide cédula" do
    get new_user_registration_path

    %w[user[document] user[cedula_escolar]].each do |campo|
      assert_empty css_select("[name='#{campo}']"), "el registro sigue pidiendo #{campo}"
    end
  end

  # ⚠️ Y «Ubicación» tampoco: se DEDUCE del municipio y el estado
  # (`School#deducir_la_ubicacion`). Preguntarla sería preguntar lo mismo dos
  # veces, que es lo que `MOR-208` vino a arreglar.
  test "no pide «Ubicación», que se deduce" do
    get new_user_registration_path

    assert_empty css_select("[name='school[location]']")
  end

  # ⚠️ La UBICACIÓN sí se pide ahora, y es un cambio sobre `MOR-196`.
  #
  # Esa decisión —«el registro pregunta lo mínimo, porque cada campo de más en
  # la puerta es gente que no entra»— se tomó cuando la ubicación había que
  # ESCRIBIRLA. Ahora llega elegida: al escoger el plantel del catálogo del
  # MPPE, el estado y el municipio se deducen de su código DEA y quedan
  # puestos. Con todo preseleccionado deja de ser rellenar y pasa a ser
  # confirmar. Decisión de Daniel, 11 de septiembre de 2026.
  test "la ubicación se elige, y llega preseleccionada del catálogo" do
    get new_user_registration_path

    assert_select "select[name='school[entidad_federal]']"
    assert_select "select[name='school[municipio]']"
    assert_select "select[name='school[parroquia]']"
    # Y los selects están DENTRO del controlador que los preselecciona.
    assert_select "[data-controller~=catalogo-de-planteles] select[name='school[entidad_federal]']"
  end

  # ⚠️ Lo que llega elegido se GUARDA: si el registro no lo persistiera, todo
  # esto sería un adorno y el colegio arrancaría igual de vacío que antes.
  test "lo elegido queda guardado en el colegio" do
    post registrarse_path, params: {
      user: { first_name: "Rosa", last_name: "Mendoza", email: "rosa@ubicado.test",
              password: "clave-larga-123", password_confirmation: "clave-larga-123" },
      school: { name: "U.E. CON UBICACIÓN", dea_code: "PD44445555",
                entidad_federal: "Apure", municipio: "Achaguas", parroquia: "El Yagual" },
      niveles: [ "primaria" ]
    }

    colegio = Current.sin_aislamiento { School.find_by(dea_code: "PD44445555") }

    assert_equal "Apure", colegio.entidad_federal
    assert_equal "Achaguas", colegio.municipio
    assert_equal "El Yagual", colegio.parroquia
  end

  test "pide qué dicta el colegio, con los cuatro niveles" do
    get new_user_registration_path

    assert_equal GradoOficial::NIVELES.size, css_select("input[name='niveles[]']").size
  end

  test "la pantalla vieja del colegio ya no existe" do
    assert_not Rails.application.routes.url_helpers.respond_to?(:nuevo_mi_colegio_path)
  end
end
