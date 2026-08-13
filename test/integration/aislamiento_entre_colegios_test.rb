require "test_helper"

# La red que impide que la fuga vuelva.
#
# El bug original no fue que alguien escribiera un filtro mal: fue que **nunca
# hubo un filtro** y nada lo señaló. Sin estos tests, el próximo controller
# repite la historia — y esa vez con colegios pagando.
#
# ## Cómo se falla al escribir esto
#
# El error clásico es probar desde adentro del colegio correcto: loguearse como
# admin de A, pedir datos de A, ver datos de A, pasar. **Eso pasaría igual con el
# aislamiento apagado.**
#
# Acá cada caso PIDE EXPLÍCITAMENTE LO AJENO: el id del recurso del otro colegio,
# y espera 404. No 403 — un 403 confirma que el registro existe.
#
# Ver MOR-90.
class AislamientoEntreColegiosTest < ActionDispatch::IntegrationTest
  # Un caso por recurso, en una tabla y no en veinte clases casi iguales.
  #
  # `actor` importa: quién pide define qué se espera. Un director puede MIRAR las
  # evaluaciones de su colegio pero no editarlas (MOR-94), así que para ese
  # recurso el actor tiene que ser el profesor.
  RECURSOS = {
    grades:                { registro: ->(c) { c.grado },        cambio: { name: "Colado" } },
    departments:           { registro: ->(c) { c.departamento }, cambio: { name: "Colado" } },
    subjects:              { registro: ->(c) { c.materia },      cambio: { name: "Colado" } },
    academic_periods:      { registro: ->(c) { c.periodo },      cambio: { name: "Colado" } },
    sections:              { registro: ->(c) { c.seccion },      cambio: { name: "Z" } },
    enrollments:           { registro: ->(c) { c.inscripcion },  cambio: { status: "retirado" } },
    students:              { registro: ->(c) { c.alumno },       cambio: { school_card: "COLADO" } },
    teachers:              { registro: ->(c) { c.registro_de_profesor } },
    admins:                { registro: ->(c) { c.registro_de_admin } },
    evaluation_moments:    { registro: ->(c) { c.lapso(1) },     cambio: { name: "Colado" } },
    evaluation_activities: { registro: ->(c) { c.actividad },    cambio: { description: "Colado" },
                             actor: :profesor }
  }.freeze

  setup do
    @a, @b = dos_colegios_completos
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Recurso por recurso: pedir lo del OTRO colegio
  # ══════════════════════════════════════════════════════════════════════════

  RECURSOS.each do |recurso, config|
    test "#{recurso} · GET del registro ajeno da 404" do
      entrar(config)

      get "/#{recurso}/#{ajeno(config).to_param}"

      assert_response :not_found, "#{recurso}: pedir un registro de otro colegio no puede devolver #{response.status}"
    end

    test "#{recurso} · el listado no muestra nada del otro colegio" do
      entrar(config)

      get "/#{recurso}"

      assert_response :success
      assert_no_match(/Colegio B/, response.body,
                      "#{recurso}: el listado del colegio A menciona al colegio B")
    end

    next unless config[:cambio]

    test "#{recurso} · PATCH al registro ajeno no lo modifica" do
      entrar(config)
      antes = ajeno(config).attributes.dup

      patch "/#{recurso}/#{ajeno(config).to_param}",
            params: { recurso.to_s.singularize => config[:cambio] }

      assert_response :not_found
      assert_equal antes, con_el_colegio(@b.colegio) { ajeno(config).reload.attributes },
                   "#{recurso}: el registro del otro colegio cambió"
    end

    test "#{recurso} · DELETE al registro ajeno no lo borra" do
      entrar(config)

      delete "/#{recurso}/#{ajeno(config).to_param}"

      assert_response :not_found
      assert con_el_colegio(@b.colegio) { ajeno(config).class.exists?(ajeno(config).id) },
             "#{recurso}: el registro del otro colegio se borró"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Los FORMULARIOS: ninguna opción del otro colegio
  # ══════════════════════════════════════════════════════════════════════════
  #
  # ⚠️ Este bloque faltaba, y es el que más caro salió de olvidar.
  #
  # El criterio del issue lo pedía —"selectores de formulario: ninguna opción de
  # B"— y la primera versión de esta suite no lo cubrió. Lo encontró Daniel
  # haciendo QA a mano: `/departments/new` mostraba un `<select>` con **los dos
  # colegios de la plataforma**, y cinco formularios más hacían lo mismo.
  #
  # Los tests de recursos no lo agarraban porque miran los LISTADOS y el `show`.
  # Un `School.all` en un formulario no pasa por ningún scope de inquilino:
  # `School` es la tabla de colegios, no un dato DE un colegio, así que
  # `SchoolScoped` no aplica y el RLS tampoco. Las dos capas estaban bien y el
  # formulario filtraba igual — un agujero que ninguna de las dos podía tapar.
  FORMULARIOS = %w[
    /departments/new /academic_periods/new /students/new /teachers/new /admins/new
    /grades/new /subjects/new /evaluation_moments/new
  ].freeze

  FORMULARIOS.each do |ruta|
    test "#{ruta} no ofrece ninguna opción del otro colegio" do
      sign_in @a.director

      get ruta

      assert_response :success
      assert_no_match(/Colegio B/, response.body,
                      "#{ruta}: el formulario nombra al otro colegio")
    end
  end

  # Y la raíz del problema: que el colegio no pueda venir del formulario.
  test "mandar el school_id de otro colegio en el formulario no sirve de nada" do
    sign_in @a.director

    post departments_url, params: { department: { name: "Colado", school_id: @b.colegio.id } }

    creado = Current.sin_aislamiento { Department.unscoped.find_by(name: "Colado") }
    assert_equal @a.colegio.id, creado.school_id,
                 "el school_id del request se ignoró y se usó el de la sesión"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Los datos de SIGA no son de ningún colegio
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Tercer caso del mismo hueco: `demo_requests` **no tiene `school_id`**. Es dato
  # de la plataforma, así que ni `SchoolScoped` ni el RLS lo alcanzan — y hasta
  # este commit cualquier `director` veía el pipeline comercial completo, con
  # colegios que compiten entre sí adentro.

  test "un director de colegio no ve las solicitudes de demo de SIGA" do
    sign_in @a.director

    get demo_requests_url

    assert_redirected_to dashboards_administrador_path
    assert_match(/administración de SIGA/, flash[:alert])
  end

  test "un director tampoco alcanza una solicitud suelta por su id" do
    solicitud = DemoRequest.create!(name: "Colegio Interesado", email: "info@otro.edu",
                                    institution: "U.E. Otro", current_system: :escritorio)
    sign_in @a.director

    get demo_request_url(solicitud)

    assert_redirected_to dashboards_administrador_path
  end

  # Tapar el controller no alcanzó: el PANEL seguía diciendo cuántas solicitudes
  # hay pendientes. El nombre y el correo no se veían, pero el tamaño del
  # pipeline comercial de SIGA sí — y con un botón que rebota, que además delata
  # que existe una sección a la que no se llega.
  #
  # Cuarto caso del mismo hueco, encontrado haciendo MOR-134. Ver MOR-133.
  test "el panel del director no delata cuántas solicitudes de demo hay" do
    3.times do |i|
      DemoRequest.create!(name: "Prospecto #{i}", email: "p#{i}@otro.edu",
                          institution: "U.E. Prospecto #{i}", current_system: :ninguno)
    end
    sign_in @a.director

    get dashboards_administrador_url

    assert_response :success
    assert_no_match(/Solicitudes de Demo/i, response.body)
    assert_select "a[href=?]", demo_requests_path, count: 0,
                  message: "el panel ofrece un enlace a una sección que le va a rebotar"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El IDOR que abrió la épica, con su test propio
  # ══════════════════════════════════════════════════════════════════════════

  test "GET /students/:id de otro colegio — el IDOR original" do
    sign_in @a.director

    get "/students/#{@b.alumno.to_param}"

    # Antes de MOR-86 esto devolvía 200 y permitía editar.
    assert_response :not_found
    assert_no_match(/#{@b.alumno.user.last_name}/, response.body)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Los tres roles, no solo el admin
  # ══════════════════════════════════════════════════════════════════════════

  test "el panel del director cuenta SU colegio, no la plataforma" do
    sign_in @a.director

    get dashboards_administrador_url

    assert_response :success
    # Dos alumnos por colegio: si contara la plataforma, diría 4.
    assert_match(/<h3>2<\/h3>/, response.body)
    assert_no_match(/<h3>4<\/h3>/, response.body)
  end

  test "un profesor no alcanza la planilla de notas del otro colegio" do
    sign_in @a.profesor

    get "/evaluation_activities/#{@b.actividad.id}/notas"

    assert_response :not_found
  end

  test "un profesor no le pone nota a un alumno del otro colegio" do
    sign_in @a.profesor

    assert_no_difference -> { cantidad(ActivityGrade) } do
      patch "/evaluation_activities/#{@a.actividad.id}/notas/#{@b.alumno.user_id}",
            params: { score: "20" }, as: :json
    end

    assert_response :not_found
  end

  test "un estudiante solo ve sus propias notas" do
    sign_in @a.estudiante

    get dashboards_notas_url

    assert_response :success
    assert_no_match(/Colegio B/, response.body)
    assert_no_match(/#{@b.alumno.user.last_name}/, response.body)
  end

  test "la auditoría de un colegio no muestra la actividad del otro" do
    sign_in @b.director   # deja un registro de login en B
    sign_out @b.director

    sign_in @a.director
    get dashboards_activity_logs_url

    assert_response :success
    assert_no_match(/#{@b.director.last_name}/, response.body)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Los boletines: el documento oficial no se cruza
  # ══════════════════════════════════════════════════════════════════════════

  test "el listado de boletines emitidos es solo del propio colegio" do
    sign_in @a.director

    get report_cards_url

    assert_response :success
    assert_match @a.boletin.code, response.body
    assert_no_match(/#{@b.boletin.code}/, response.body)
  end

  # La verificación pública SÍ cruza colegios a propósito: quien verifica no tiene
  # sesión, y el código de 8 caracteres es lo único que la autoriza. Es la única
  # excepción del sistema y conviene que un test la deje escrita, para que se vea
  # que es deliberada y no un olvido.
  test "la verificación pública alcanza cualquier boletín — y es a propósito" do
    get verificar_url(code: @b.boletin.code)

    assert_response :success
    assert_match "Boletín verificado", response.body
  end

  private

  def entrar(config)
    sign_in config[:actor] == :profesor ? @a.profesor : @a.director
  end

  def ajeno(config)
    config[:registro].call(@b)
  end
end
