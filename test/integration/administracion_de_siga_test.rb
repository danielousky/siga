require "test_helper"

# La administración de la plataforma, separada de la de los colegios (MOR-133).
#
# El agujero de `/demo_requests` se tapó **tres veces** y volvió a aparecer las
# tres: primero el controller dejaba pasar a cualquier `director`; tapado eso, el
# panel seguía diciendo cuántas solicitudes había pendientes; y el enlace del
# menú delataba que la sección existía.
#
# > **Tapar la puerta no alcanza si la pared tiene ventana.**
#
# Lo que estos tests sostienen no es que las pantallas estén tapadas: es que
# **el panel del colegio ya no las tiene**, y que el equipo de SIGA no pertenece
# a ningún colegio.
class AdministracionDeSigaTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos

    @fundador = User.create!(name: "Equipo", last_name: "SIGA", password: "123123",
                             email: "fundador@siga.app")
    SigaStaff.create!(user: @fundador, role: :fundador)

    @operaciones = User.create!(name: "Ana", last_name: "Operaciones", password: "123123",
                                email: "ops@siga.app")
    SigaStaff.create!(user: @operaciones, role: :operaciones)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Criterio: ningún usuario de un colegio alcanza dato alguno de la plataforma
  # ══════════════════════════════════════════════════════════════════════════

  PANTALLAS_DE_SIGA = %w[/siga /siga/colegios /siga/colegios/new /siga/solicitudes].freeze

  # Los cuatro roles del colegio, contra las cuatro pantallas. Antes bastaba con
  # ser `director` para ver el pipeline comercial completo.
  { director: :director, profesor: :profesor, estudiante: :estudiante }.each_key do |rol|
    test "un #{rol} de colegio no alcanza ninguna pantalla de SIGA" do
      sign_in @a.public_send(rol)

      PANTALLAS_DE_SIGA.each do |ruta|
        get ruta

        assert_response :redirect, "#{rol} entró a #{ruta}"
        assert_equal root_path, URI(response.location).path,
                     "#{ruta} tiene que rebotar afuera, no mostrar nada"
      end
    end
  end

  test "un director tampoco alcanza una solicitud suelta por su id" do
    solicitud = DemoRequest.create!(name: "Colegio Interesado", email: "info@otro.edu", phone: "0424-1112233",
                                    institution: "U.E. Otro", current_system: :escritorio)
    sign_in @a.director

    get "/siga/solicitudes/#{solicitud.id}"

    assert_response :redirect
    assert_no_match(/info@otro\.edu/, response.body)
  end

  # La corrección de raíz: el panel del colegio **ya no tiene** estas pantallas.
  # No es que estén protegidas — es que no existen del lado del colegio.
  test "las rutas viejas de gestión de solicitudes ya no existen" do
    sign_in @a.director

    get "/demo_requests"
    assert_response :not_found, "la ruta de listado tiene que haber desaparecido, no estar protegida"

    get "/demo_requests/1"
    assert_response :not_found
  end

  test "el panel del colegio no menciona las solicitudes de demo" do
    3.times { |i| DemoRequest.create!(name: "P#{i}", email: "p#{i}@x.edu", institution: "U.E. #{i}", phone: "042400000#{i}") }
    sign_in @a.director

    get dashboards_administrador_url

    assert_response :success
    assert_no_match(/Solicitud(es)? de Demo/i, response.body)
    assert_no_match(/demo_requests/, response.body)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Criterio: el equipo de SIGA no pertenece a un colegio
  # ══════════════════════════════════════════════════════════════════════════

  test "un SigaStaff no tiene colegio, ni la tabla tiene school_id" do
    assert_not SigaStaff.column_names.include?("school_id"),
               "si tuviera school_id volveríamos a decir que el equipo de SIGA pertenece a un colegio"
    assert_not SigaStaff.include?(SchoolScoped)
  end

  test "el equipo de SIGA entra a su administración, no al panel de un colegio" do
    sign_in @fundador

    get "/siga"

    assert_response :success
    assert_match(/administración de la plataforma/i, response.body)
  end

  # Sin rol de colegio, `current_user_type` es nil: sin esto caerían en la
  # pantalla de "Sin Rol Asignado", que para ellos es falsa.
  test "al entrar, el equipo de SIGA va derecho a /siga" do
    post user_session_path, params: { user: { email: @fundador.email, password: "123123" } }

    assert_redirected_to "/siga"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que ve: TODOS los colegios, que es su razón de existir
  # ══════════════════════════════════════════════════════════════════════════

  test "el panel ve los dos colegios y sus matrículas" do
    sign_in @fundador

    get "/siga"

    assert_response :success
    assert_match(/#{Regexp.escape(@a.colegio.name)}/, response.body)
    assert_match(/#{Regexp.escape(@b.colegio.name)}/, response.body,
                 "una administración de plataforma que no ve todos los colegios no sirve")
  end

  test "el bypass no se le queda pegado a la conexión" do
    sign_in @fundador
    get "/siga"

    # Si el `ensure` de `sin_colegio` fallara, la conexión volvería al pool con
    # el bypass puesto y la SIGUIENTE petición de un colegio vería la plataforma
    # entera. Sería la fuga original, al revés y peor.
    sign_out @fundador
    sign_in @a.director
    get students_path

    assert_response :success
    # Los alumnos de las fixtures se llaman igual en los dos colegios, así que el
    # nombre no distingue nada: lo que distingue es el carnet, que lleva el id
    # del colegio adentro.
    assert_select ".contexto-colegio-nombre", text: @a.colegio.name
    assert_no_match(/#{Regexp.escape(@b.alumno.school_card)}/, response.body,
                    "el bypass quedó pegado: esta petición vio datos del otro colegio")
    con_el_colegio(@a.colegio) { assert_equal 2, Student.count }
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Criterio: dar de alta un colegio no requiere consola
  # ══════════════════════════════════════════════════════════════════════════

  test "el fundador da de alta un colegio con su primer director" do
    sign_in @fundador

    assert_difference -> { Current.sin_aislamiento { School.count } }, 1 do
      post "/siga/colegios", params: {
        school: { name: "U.E. Nueva Esperanza", dea_code: "NUE-999",
                  location: "Mérida, Mérida", school_type: "primary" },
        director: { name: "Rosa", last_name: "Peña", email: "rosa.pena@nueva.edu" }
      }
    end

    Current.sin_aislamiento do
      creado = School.find_by(dea_code: "NUE-999")
      assert creado.present?
      assert_equal 1, Admin.where(school_id: creado.id, role: :director).count,
                   "un colegio sin nadie que pueda entrar no sirve para nada"
    end
  end

  # Un colegio a medias es peor que ninguno: quedaría ocupando su código DEA sin
  # que nadie pueda entrar, y el DEA es único en toda la plataforma.
  test "si el director es inválido no queda un colegio a medias" do
    sign_in @fundador

    assert_no_difference -> { Current.sin_aislamiento { School.count } } do
      post "/siga/colegios", params: {
        school: { name: "U.E. A Medias", dea_code: "MED-001", location: "Caracas", school_type: "primary" },
        director: { name: "", last_name: "", email: "no-es-un-correo" }
      }
    end
  end

  test "operaciones no da de alta colegios" do
    sign_in @operaciones

    get "/siga/colegios/new"

    assert_redirected_to "/siga/colegios"
  end

  test "operaciones sí ve el pipeline comercial" do
    DemoRequest.create!(name: "Interesado", email: "info@interesado.edu", institution: "U.E. Interesado", phone: "0424-7778899")
    sign_in @operaciones

    get "/siga/solicitudes"

    assert_response :success
    assert_match(/U\.E\. Interesado/, response.body)
  end
end
