require "test_helper"

# El equipo de SIGA entrando a un colegio a dar soporte.
#
# ## Es una decisión con fecha de vencimiento
#
# Decisión de Daniel, 14 de agosto de 2026: para el lanzamiento conviven todos
# —misma base, misma tabla `users`, roles distintos— y el equipo de SIGA tiene
# acceso amplio, porque para responderle a un colegio hay que poder ver lo que él
# ve, en el momento.
#
# ⚠️ Es el vector que describe `MOR-92`, que sigue abierto a propósito. Lo que
# estos tests sostienen es lo que sí se hizo mientras tanto: que haya que elegir
# el colegio, que quede rastro **en el historial del colegio**, y que el
# aislamiento se APUNTE en vez de apagarse.
class VisitaDeSoporteTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos

    @siga_user = User.create!(first_name: "Ana", last_name: "Soporte", password: "123123",
                              email: "soporte@siga.app",
                        document: "V-#{"soporte@siga.app".bytes.sum}")
    SigaStaff.create!(user: @siga_user, role: :fundador)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Tener el rol no mete a nadie en ningún lado
  # ══════════════════════════════════════════════════════════════════════════

  test "sin elegir colegio, el equipo de SIGA no está en ningún colegio" do
    sign_in @siga_user

    get students_path

    assert_response :redirect, "hay que ELEGIR el colegio: el rol no alcanza"
  end

  test "al entrar va a su propia administración, no a un colegio" do
    post user_session_path, params: { user: { email: @siga_user.email, password: "123123" } }

    assert_redirected_to "/siga"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Eligiendo colegio: ve lo que ve el colegio, y NADA más
  # ══════════════════════════════════════════════════════════════════════════

  test "entra al colegio y ve sus datos" do
    entrar_a(@a)

    get students_path

    assert_response :success
    assert_select ".contexto-colegio-nombre", text: @a.colegio.name
    assert_match(/#{Regexp.escape(@a.alumno.school_card)}/, response.body)
  end

  # ⚠️ Lo que hace que esto no sea "apagar el aislamiento": el filtro se APUNTA
  # al colegio elegido. Nunca hay un momento en que vea dos colegios a la vez.
  test "y NO ve los del otro colegio, ni por un instante" do
    entrar_a(@a)

    get students_path

    assert_no_match(/#{Regexp.escape(@b.alumno.school_card)}/, response.body,
                    "la visita es a UN colegio: apunta el filtro, no lo apaga")
  end

  test "pedir un alumno del otro colegio da 404" do
    entrar_a(@a)

    get student_path(@b.alumno)

    assert_response :not_found
  end

  test "cambiar de colegio cambia lo que ve" do
    entrar_a(@a)
    get students_path
    assert_select ".contexto-colegio-nombre", text: @a.colegio.name

    entrar_a(@b)
    get students_path

    assert_select ".contexto-colegio-nombre", text: @b.colegio.name
    assert_match(/#{Regexp.escape(@b.alumno.school_card)}/, response.body)
    assert_no_match(/#{Regexp.escape(@a.alumno.school_card)}/, response.body)
  end

  test "salir del colegio lo devuelve a la plataforma" do
    entrar_a(@a)
    delete "/siga/visitas/#{@a.colegio.id}"

    assert_redirected_to "/siga"

    get students_path
    assert_response :redirect, "salir tiene que salir de verdad"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La sesión propone; el sistema verifica
  # ══════════════════════════════════════════════════════════════════════════

  test "un director de colegio no puede entrar a otro colegio por esta puerta" do
    sign_in @a.director

    post "/siga/visitas", params: { school_id: @b.colegio.id }

    assert_response :redirect
    get students_path
    assert_select ".contexto-colegio-nombre", text: @a.colegio.name
    assert_no_match(/#{Regexp.escape(@b.alumno.school_card)}/, response.body)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El colegio se entera. Es lo que lo hace defendible.
  # ══════════════════════════════════════════════════════════════════════════

  test "entrar deja rastro en el historial DEL COLEGIO" do
    entrar_a(@a)

    con_el_colegio(@a.colegio) do
      rastro = ActivityLog.where(action: "soporte_siga_entro").last

      assert rastro.present?, "un acceso sin rastro no se le puede explicar a nadie"
      assert_equal @a.colegio.id, rastro.school_id
      assert_match(/equipo de SIGA/, rastro.message)
    end
  end

  test "el rastro NO queda en el historial del otro colegio" do
    entrar_a(@a)

    con_el_colegio(@b.colegio) do
      assert_equal 0, ActivityLog.where(action: "soporte_siga_entro").count
    end
  end

  test "el aviso se ve en pantalla mientras dura" do
    entrar_a(@a)

    get dashboards_administrador_url

    assert_select ".aviso-visita"
    assert_match(/Soporte de SIGA adentro/, response.body)
  end

  test "el colegio lo ve en su registro de actividad" do
    entrar_a(@a)
    delete "/siga/visitas/#{@a.colegio.id}"
    sign_out @siga_user

    sign_in @a.director
    get dashboards_activity_logs_url

    assert_response :success
    assert_match(/equipo de SIGA/, response.body)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Y el bypass no se queda pegado
  # ══════════════════════════════════════════════════════════════════════════
  #
  # `/siga` corre con el aislamiento apagado. Si eso sobreviviera a la petición,
  # la siguiente —de un colegio— vería la plataforma entera: la fuga original al
  # revés, y peor.

  test "después de pasar por la plataforma, un colegio sigue viendo solo lo suyo" do
    sign_in @siga_user
    get "/siga"
    sign_out @siga_user

    sign_in @a.director
    get students_path

    assert_response :success
    assert_no_match(/#{Regexp.escape(@b.alumno.school_card)}/, response.body)
    con_el_colegio(@a.colegio) { assert_equal 2, Student.count }
  end

  private

  def entrar_a(colegio)
    sign_in @siga_user
    post "/siga/visitas", params: { school_id: colegio.colegio.id }

    assert_equal colegio.colegio.id, session[:colegio_visitado_id],
                 "la visita no quedó en la sesión · #{response.status} · #{flash.to_hash.inspect}"
  end
end
