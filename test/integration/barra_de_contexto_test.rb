require "test_helper"

# La barra que dice en qué colegio y en qué año escolar estás parado.
#
# Antes de MOR-134 esta franja decía "Período Académico Activo" —una etiqueta
# anunciando un dato que nunca traía— y debajo repetía el nombre del producto.
# El lugar más visible de la app, ocupado por cero información.
#
# Y lo más raro: después de construir el aislamiento entero, `Current.school`
# aparecía en las vistas SOLO en comentarios explicando por qué el colegio no se
# elige. En pantalla, nunca.
#
# Ver MOR-134.
class BarraDeContextoTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @a, @b = dos_colegios_completos
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El colegio, para los tres roles
  # ══════════════════════════════════════════════════════════════════════════
  #
  # No alcanza con probarlo como admin: la barra la pinta el layout, y el layout
  # es el mismo para todos. Si se rompiera para el estudiante, se rompería en la
  # pantalla que ve una familia.

  %i[director profesor estudiante].each do |rol|
    test "#{rol} · la barra dice en qué colegio está parado" do
      sign_in @a.public_send(rol)

      get dashboard_para(rol)

      assert_response :success
      assert_select ".contexto-colegio-nombre", text: @a.colegio.name,
                    message: "#{rol}: la barra de contexto no nombra el colegio de la sesión"
    end
  end

  test "la barra nunca nombra el colegio ajeno" do
    sign_in @a.director

    get dashboards_administrador_url

    assert_select ".contexto-colegio-nombre", text: @a.colegio.name
    assert_no_match(/#{Regexp.escape(@b.colegio.name)}/, response.body)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El año escolar, y no mentir sobre él
  # ══════════════════════════════════════════════════════════════════════════
  #
  # El tiempo se congela en cada caso a propósito. Sin eso, el test diría cosas
  # distintas en julio y en septiembre — y un test que cambia de veredicto según
  # el día en que se corre no protege nada.

  test "durante el año escolar, la barra lo da por en curso" do
    travel_to Date.new(2026, 3, 10) do
      sign_in @a.director
      get dashboards_administrador_url

      assert_select ".contexto-periodo-nombre", text: "2025-2026"
      assert_select ".contexto-periodo-situacion", text: "en curso"
    end
  end

  # Entre julio y septiembre no hay ningún año escolar corriendo. La barra vieja
  # habría dicho "Período Académico Activo" igual: una afirmación falsa sobre el
  # colegio, en la franja más visible.
  #
  # ⚠️ Con MOR-165 cambió CUÁL año se elige por defecto —el que tiene alumnos, no
  # la fila más nueva— pero no cambió lo que este test protege: que la barra no
  # invente un año en curso cuando no hay ninguno.
  test "entre dos años escolares, no inventa uno activo" do
    con_el_colegio(@a.colegio) do
      AcademicPeriod.create!(name: "2026-2027",
                             start_date: Date.new(2026, 9, 15), end_date: Date.new(2027, 7, 31))
    end

    travel_to Date.new(2026, 8, 13) do
      sign_in @a.director
      get dashboards_administrador_url

      # Arranca en el año con clases, no en el que empieza en dos semanas y está
      # vacío: entrar ahí es abrir el panel de un colegio lleno y leer «0 alumnos».
      # El de 2026-2027 está a un clic, en el mismo desplegable.
      assert_select ".contexto-anio-select option[selected]", text: "2025-2026"
      assert_select ".contexto-anio-select option", text: "2026-2027"
      assert_select ".contexto-periodo-situacion", text: "finalizado el 31 de julio"
      assert_no_match(/en curso/, response.body)
    end
  end

  # La otra mitad de lo mismo: si el director SÍ quiere ver el año que viene,
  # lo elige y la barra deja de hablar del anterior.
  test "y si el director elige el que viene, la barra lo acompaña" do
    con_el_colegio(@a.colegio) do
      AcademicPeriod.create!(name: "2026-2027",
                             start_date: Date.new(2026, 9, 15), end_date: Date.new(2027, 7, 31))
    end

    travel_to Date.new(2026, 8, 13) do
      sign_in @a.director
      que_viene = con_el_colegio(@a.colegio) { AcademicPeriod.find_by(name: "2026-2027") }
      post cambiar_anio_escolar_path, params: { id: que_viene.id }
      get dashboards_administrador_url

      assert_select ".contexto-anio-select option[selected]", text: "2026-2027"
      assert_select ".contexto-periodo-situacion", text: "comienza el 15 de septiembre"
      assert_no_match(/en curso/, response.body)
    end
  end

  test "si el último año escolar ya cerró y no hay otro, lo dice" do
    travel_to Date.new(2026, 8, 13) do
      sign_in @a.director
      get dashboards_administrador_url

      assert_select ".contexto-periodo-nombre", text: "2025-2026"
      assert_select ".contexto-periodo-situacion", text: "finalizado el 31 de julio"
    end
  end

  # Un colegio recién dado de alta, que es el primer día de todo cliente nuevo.
  # Antes la barra decía "Período Académico Activo" con la misma seguridad que
  # si lo hubiera.
  test "un colegio sin año escolar cargado lo dice, en vez de dejar el hueco" do
    recien_creado = Current.sin_aislamiento do
      School.create!(name: "Colegio Recién Dado de Alta", dea_code: "TESTNUEVO",
                     location: "Caracas")
    end
    director = User.create!(first_name: "Directora", last_name: "Nueva",
                            email: "dir.nueva@aislamiento.test", password: "123123",
                        document: "V-#{"dir.nueva@aislamiento.test".bytes.sum}")
    con_el_colegio(recien_creado) do
      Admin.create!(user: director, school: recien_creado, role: :director)
    end

    sign_in director
    get dashboards_administrador_url

    assert_response :success
    assert_select ".contexto-colegio-nombre", text: "COLEGIO RECIÉN DADO DE ALTA"
    assert_select ".contexto-periodo-vacio", text: "Sin año escolar cargado"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Ninguna petición a un tercero
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Font Awesome se cargaba desde un CDN en CADA página, para UN ícono: el ojo
  # del formulario de login. En un colegio con conexión mala eso es la página
  # entera esperando a un servidor ajeno.

  test "ninguna pantalla pide recursos a un dominio externo" do
    sign_in @a.director

    [ root_path, students_path, grades_path, report_cards_path ].each do |ruta|
      get ruta

      externos = response.body.scan(%r{(?:src|href)="(https?://[^"]+)"}).flatten
                             .reject { |url| url.include?("://localhost") || url.include?("://www.w3.org") }

      assert_empty externos, "#{ruta} pide recursos a un dominio externo: #{externos.uniq.join(', ')}"
    end
  end

  test "el login tampoco, y el ojo de la contraseña sigue estando" do
    sign_out @a.director

    get new_user_session_url

    assert_response :success
    assert_no_match(/cdnjs|font-?awesome/i, response.body)
    # Dos SVG: el ojo y el ojo tachado. El segundo nace oculto.
    assert_select "svg.password-toggle-icon", count: 2
  end

  private

  def dashboard_para(rol)
    case rol
    when :director   then dashboards_administrador_url
    when :profesor   then dashboards_profesor_url
    when :estudiante then dashboards_estudiante_url
    end
  end
end
