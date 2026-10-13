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
    assert_match(/#{Regexp.escape(@a.alumno.user.apellidos)}/, response.body)
  end

  # ── Educación Inicial: lo que la maestra escribió ─────────────────────────

  # ⚠️ Inicial no pone número: describe (`MOR-218`). La valoración vive en la
  # misma fila que una nota, y esta pantalla solo le preguntaba por el número:
  # la madre de un niño de cuatro años leía «Pendiente» en un área que la
  # maestra ya había escrito. Lo encontró la siembra de la muestra.
  test "en Inicial la familia lee la valoración, no «Pendiente»" do
    esc, madre = una_familia_de(:preescolar)
    con_el_colegio(esc.colegio) do
      MomentGrade.create!(enrollment: esc.inscripcion, subject: esc.materia, evaluation_moment: esc.lapso(1),
                          descripcion: "Cuenta hasta diez señalando cada objeto.")
    end

    sign_in madre
    get hijo_representante_path(esc.alumno)

    assert_response :success
    assert_select ".portal-valoracion", text: "Cuenta hasta diez señalando cada objeto."
    assert_select ".portal-pendiente", count: 0
    assert_select "h2", text: /Valoraciones de lapso 1/
  end

  test "y si la maestra todavía no la escribió, dice «Pendiente»" do
    esc, madre = una_familia_de(:preescolar)

    sign_in madre
    get hijo_representante_path(esc.alumno)

    assert_select ".portal-pendiente", text: "Pendiente"
    assert_select ".portal-valoracion", count: 0
  end

  # En el año completo no hay nada «pendiente»: en Inicial no existe esa nota.
  test "en Inicial el año completo no promete una calificación" do
    esc, madre = una_familia_de(:preescolar)

    sign_in madre
    get hijo_representante_path(esc.alumno, lapso: "anual")

    assert_select "h2", text: /Valoraciones del año/
    assert_select ".portal-pendiente", count: 0
    assert_match(/no hay una calificación del año/, response.body)
  end

  test "fuera de Inicial siguen siendo calificaciones" do
    sign_in @madre
    get hijo_representante_path(@a.alumno)

    assert_select "h2", text: /Calificaciones de lapso 1/
    assert_select ".portal-valoracion", count: 0
  end

  # ── Los boletines de los años anteriores ──────────────────────────────────

  # ⚠️ Solo se listaban los de la inscripción vigente. En octubre —el primer
  # lapso cierra en diciembre— la lista estaba vacía, con el boletín final de
  # julio emitido y descargable: existía, y no había por dónde llegar a él.
  test "ve también los boletines liberados de un año anterior, con su año escrito" do
    viejo = ano_escolar_viejo(@a.escenario, nombre: "2023-2024")
    de_antes = con_el_colegio(@a.colegio) do
      seccion = Section.find_by!(academic_period: viejo)
      inscripcion = Enrollment.create!(student: @a.alumno, section: seccion, enrollment_date: Date.new(2023, 9, 20))
      boletin = ReportCard.create!(enrollment: inscripcion, issued_by: @a.director,
                                   evaluation_moment: EvaluationMoment.find_by!(academic_period: viejo, name: "Lapso 3"),
                                   snapshot: {})
      boletin.liberar!(por: @a.director)
      boletin
    end
    con_el_colegio(@a.colegio) { @a.boletin.liberar!(por: @a.director) }

    sign_in @madre
    get hijo_representante_path(@a.alumno)

    assert_select ".portal-boletin-codigo", text: de_antes.code
    assert_select ".portal-boletines li", text: /Lapso 3\s*· 2023-2024/
    # El del año que corre NO lleva el año: «Lapso 1» a secas es el de ahora.
    assert_select ".portal-boletines li", text: /Lapso 1/ do |filas|
      assert_no_match(/2025-2026/, filas.first.text)
    end
  end

  test "y no ve el de un año anterior que nunca se liberó" do
    viejo = ano_escolar_viejo(@a.escenario, nombre: "2023-2024")
    sin_liberar = con_el_colegio(@a.colegio) do
      inscripcion = Enrollment.create!(student: @a.alumno, section: Section.find_by!(academic_period: viejo),
                                       enrollment_date: Date.new(2023, 9, 20))
      ReportCard.create!(enrollment: inscripcion, issued_by: @a.director, snapshot: {},
                         evaluation_moment: EvaluationMoment.find_by!(academic_period: viejo, name: "Lapso 3"))
    end

    sign_in @madre
    get hijo_representante_path(@a.alumno)

    assert_no_match(/#{sin_liberar.code}/, response.body)
  end

  # La pantalla le habla de usted a una madre (`CLAUDE.md`).
  test "el aviso de la falta sin justificar trata de usted" do
    con_el_colegio(@a.colegio) do
      Attendance.create!(enrollment: @a.inscripcion, date: Date.current - 1, status: :ausente, recorded_by: @a.profesor)
    end

    sign_in @madre
    get hijo_representante_path(@a.alumno)

    assert_match(/Si ya entregó el justificativo, avísele a la/, response.body)
    assert_no_match(/entregaste|avísale/, response.body)
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
      patch evaluation_activity_nota_path(@a.actividad, @a.alumno),
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

  # Un colegio de ese nivel, con un alumno y su madre ya vinculada.
  def una_familia_de(nivel)
    esc = escenario_academico(nombre: "Colegio de #{nivel}", nivel: nivel)
    madre = User.create!(first_name: "Rosa", last_name: "Medina", password: "123123",
                         email: "rosa.#{esc.colegio.id}@portal.test", document: "V-#{90_000_000 + esc.colegio.id}")
    con_el_colegio(esc.colegio) do
      rep = Representative.create!(user: madre, school: esc.colegio, phone: "0414-1112233")
      StudentRepresentative.create!(representative: rep, student: esc.alumno, parentesco: :madre)
    end
    [ esc, madre ]
  end
end
