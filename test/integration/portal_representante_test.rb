require "test_helper"

# El portal del representante (MOR-110).
#
# Es la superficie más visible del producto: dos representantes por alumno, ~700
# en un colegio de 350, contra quince profesores. Lo que se prueba acá es lo que
# no puede fallar nunca —que vea a sus hijos y a nadie más— y el caso que
# obligó a diseñar distinto: hijos en DOS colegios.
class PortalRepresentanteTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos

    @madre = User.create!(first_name: "Carmen", last_name: "López", password: "123123",
                          email: "carmen@portal.test",
                        document: "V-#{"carmen@portal.test".bytes.sum}")

    @rep_a = con_el_colegio(@a.colegio) do
      rep = Representative.create!(user: @madre, school: @a.colegio, phone: "0414-1112233")
      StudentRepresentative.create!(representative: rep, student: @a.alumno, parentesco: :madre)
      rep
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Ve a sus hijos y a nadie más
  # ══════════════════════════════════════════════════════════════════════════

  # `InicioController` tenía su propia lista de roles y `dashboard_path_for_user`
  # tenía otra, más completa. El representante estaba solo en la segunda: entrar
  # por la raíz le decía "Tu cuenta no tiene un rol asignado" teniendo un hijo
  # inscrito. Ahora hay una sola lista.
  test "desde la raíz llega a su portal y no a la pantalla de sin rol" do
    sign_in @madre

    get root_path

    assert_redirected_to representante_path
    follow_redirect!
    assert_no_match(/no tiene un rol asignado/i, response.body)
  end

  test "con un solo hijo entra directo a su detalle" do
    sign_in @madre

    get representante_path

    # Un paso menos para quien entra tres veces al año.
    assert_redirected_to hijo_representante_path(@a.alumno)
  end

  test "ve las notas de su hijo" do
    sign_in @madre

    get hijo_representante_path(@a.alumno)

    assert_response :success
    assert_match(/#{Regexp.escape(@a.alumno.user.last_name)}/, response.body)
  end

  # El corazón del issue: "un representante ve las notas de sus hijos y de nadie
  # más". Pedir explícitamente el id de otro alumno del MISMO colegio tiene que
  # dar 404 — el aislamiento por colegio no alcanza acá, porque los dos alumnos
  # son del mismo inquilino.
  test "no alcanza a otro alumno del mismo colegio" do
    otro = con_el_colegio(@a.colegio) { @a.escenario.alumno(2) }
    sign_in @madre

    get hijo_representante_path(otro)

    assert_response :not_found
    assert_no_match(/#{Regexp.escape(otro.user.last_name)}/, response.body)
  end

  test "no alcanza a un alumno de otro colegio" do
    sign_in @madre

    get hijo_representante_path(@b.alumno)

    assert_response :not_found
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Estrictamente de lectura
  # ══════════════════════════════════════════════════════════════════════════
  #
  # No alcanza con no poner botones: si existiera la ruta, alguien podría armar
  # la petición a mano. Lo que sostiene el "solo lectura" es que esos verbos NO
  # EXISTEN para este rol.

  test "un representante no alcanza ninguna pantalla de gestión" do
    sign_in @madre

    { students_path        => "alumnos",
      teachers_path        => "profesores",
      grades_path          => "grados",
      report_cards_path    => "emisión de boletines",
      asistencias_path     => "toma de asistencia",
      representatives_path => "gestión de representantes" }.each do |ruta, que|
      get ruta

      assert_response :redirect, "un representante llegó a #{que}"
    end
  end

  test "no puede escribir una nota aunque arme la petición a mano" do
    sign_in @madre

    assert_no_difference -> { cantidad(ActivityGrade) } do
      patch "/evaluation_activities/#{@a.actividad.id}/notas/#{@a.alumno.id}",
            params: { score: "20" }, as: :json
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El caso que obligó a diseñar distinto: hijos en DOS colegios
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Su usuario es uno, sus inquilinos son dos, y `Current.school` es uno por
  # petición. Es el único lugar del sistema donde la sesión participa de elegir
  # el colegio — y por eso es el que más test necesita.

  test "con hijos en dos colegios NO entra directo: necesita ver el selector" do
    representar_tambien_en_b

    sign_in @madre
    get representante_path

    # Con un hijo por colegio, saltear esta vista la dejaría encerrada en el
    # primero sin forma de llegar al otro. Lo encontré probando este caso.
    assert_response :success
    assert_match(/más de un colegio/, response.body)
  end

  # Los alumnos de las fixtures se llaman igual en los dos colegios, así que el
  # nombre no distingue nada: lo que se mira es el COLEGIO de la barra de
  # contexto, que es la identidad de la pantalla (MOR-134).
  test "cambiar de colegio cambia lo que ve" do
    representar_tambien_en_b
    sign_in @madre

    get representante_path
    assert_select ".contexto-colegio-nombre", text: @a.colegio.name

    post cambiar_colegio_representante_path, params: { colegio_id: @b.colegio.id }
    follow_redirect!

    assert_select ".contexto-colegio-nombre", text: @b.colegio.name,
                  message: "tras cambiar tiene que estar parada en el otro colegio"
  end

  # ⚠️ El test que sostiene toda la decisión de dejar que la sesión elija.
  #
  # La sesión SELECCIONA entre colegios ya verificados; no concede acceso a
  # ninguno. Mandar el id de un colegio donde no representa a nadie tiene que
  # no hacer absolutamente nada.
  test "mandar el id de un colegio ajeno no lleva a ningún lado" do
    sign_in @madre   # solo representa en A

    post cambiar_colegio_representante_path, params: { colegio_id: @b.colegio.id }
    follow_redirect!
    follow_redirect! if response.redirect?   # con un solo hijo entra a su detalle

    assert_select ".contexto-colegio-nombre", text: @a.colegio.name,
                  message: "el colegio no puede salir de un id que el usuario mandó sin más"
  end

  test "un id inventado tampoco" do
    representar_tambien_en_b
    sign_in @madre

    post cambiar_colegio_representante_path, params: { colegio_id: 999_999 }
    follow_redirect!

    assert_response :success
    # Cae en el `||`: se queda en el primero de los SUYOS.
    assert_select ".contexto-colegio-nombre", text: @a.colegio.name
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El colegio los da de alta
  # ══════════════════════════════════════════════════════════════════════════

  test "la secretaría registra un representante y lo vincula a un alumno" do
    sign_in @a.director

    assert_difference -> { con_el_colegio(@a.colegio) { Representative.count } }, 1 do
      post representatives_path, params: {
        user: { first_name: "Nueva", last_name: "Madre", email: "nueva.madre@portal.test",
                document: "V-16223004", document_type: "cedula_v" },
        representative: { phone: "0414-9998877" },
        student_ids: [@a.alumno.id]
      }
    end

    con_el_colegio(@a.colegio) do
      creado = Representative.joins(:user).find_by(users: { email: "nueva.madre@portal.test" })
      assert_includes creado.students.map(&:id), @a.alumno.id
    end
  end

  # `users.email` es único global justamente para que una persona sea una sola
  # cuenta: la maestra que además es madre de un alumno no puede tener dos.
  test "si la persona ya tiene cuenta se reutiliza en vez de duplicarla" do
    sign_in @a.director

    assert_no_difference -> { Current.sin_aislamiento { User.count } } do
      post representatives_path, params: {
        user: { first_name: "Carmen", last_name: "López", email: @madre.email },
        representative: { phone: "0414-0000000" },
        student_ids: []
      }
    end
  end

  test "un profesor no puede dar de alta representantes" do
    sign_in @a.profesor

    get representatives_path

    assert_redirected_to dashboards_profesor_path
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El vínculo no puede cruzar colegios
  # ══════════════════════════════════════════════════════════════════════════

  test "no se puede vincular al hijo de otro colegio" do
    con_el_colegio(@a.colegio) do
      cruzado = StudentRepresentative.new(representative: @rep_a, student: @b.alumno)

      assert_not cruzado.valid?, "vincular a un alumno de otro colegio abriría el portal a datos ajenos"
    end
  end

  private

  def representar_tambien_en_b
    con_el_colegio(@b.colegio) do
      rep = Representative.create!(user: @madre, school: @b.colegio)
      StudentRepresentative.create!(representative: rep, student: @b.alumno, parentesco: :madre)
    end
  end
end
