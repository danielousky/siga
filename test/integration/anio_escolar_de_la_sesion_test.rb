require "test_helper"

# El año escolar de la sesión (MOR-165).
#
# Daniel, haciendo QA: *«vamos a implementar la figura de año escolar de la
# sesión, arriba, donde está la sesión. Ese lo vamos a tomar como pivote para
# filtrar todo lo que sea filtrable»*.
#
# ## Qué se está probando de verdad
#
# No que el desplegable se pinte —eso no prueba nada— sino las tres cosas que se
# rompen en silencio:
#
#   1. que elegir un año CAMBIE lo que devuelven las consultas,
#   2. que el profesor NO pueda elegir, porque elegir mal es cargar notas en el
#      año equivocado sin enterarse,
#   3. que un id guardado en la sesión no sea una puerta a otro colegio.
class AnioEscolarDeLaSesionTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos

    # Un segundo año en el colegio A, con su propia sección. Es la mitad del
    # test: sin dos años poblados, filtrar por uno no se distingue de no filtrar.
    @viejo, @seccion_vieja = con_el_colegio(@a.colegio) do
      periodo = AcademicPeriod.create!(name: "2024-2025",
                                       start_date: Date.new(2024, 9, 15),
                                       end_date: Date.new(2025, 7, 31))
      seccion = Section.create!(grade: @a.grado, academic_period: periodo, name: "Z", capacity: 30)
      [ periodo, seccion ]
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Elegir un año recorta lo que se ve
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ El año por defecto es el que TIENE ALUMNOS, no la fila más nueva.
  #
  # En agosto son distintos: la fila más nueva es el año que empieza en
  # septiembre, sin una sola sección. Arrancar ahí es abrir el panel de un
  # colegio lleno y leer «0 alumnos».
  test "por defecto se ve el año con clases, no el que todavía no empezó" do
    sin_alumnos = con_el_colegio(@a.colegio) do
      AcademicPeriod.create!(name: "2026-2027",
                             start_date: Date.new(2026, 9, 15), end_date: Date.new(2027, 7, 31))
    end

    sign_in @a.director
    get sections_path

    assert_select ".contexto-anio-select option[selected]", text: @a.periodo.name
    assert_select ".contexto-anio-select option", text: sin_alumnos.name,
                  message: "el año que viene tiene que estar en la lista, solo que no elegido"
  end

  test "por defecto se ve el año vigente, no el histórico" do
    sign_in @a.director

    get sections_path

    assert_select "td", text: @a.seccion.name
    assert_select "td", text: @seccion_vieja.name, count: 0,
                  message: "la sección de 2024-2025 no debería aparecer con 2025-2026 elegido"
  end

  test "elegir el año viejo cambia lo que devuelve el listado" do
    sign_in @a.director

    post cambiar_anio_escolar_path, params: { id: @viejo.id }
    get sections_path

    assert_select "td", text: @seccion_vieja.name
    assert_select "td", text: @a.seccion.name, count: 0,
                  message: "con 2024-2025 elegido no debería verse la sección del año vigente"
  end

  test "«todos los años» muestra los dos, y lo dice" do
    sign_in @a.director

    post cambiar_anio_escolar_path, params: { id: LlevaElAnioEscolar::TODOS }
    get sections_path

    assert_select "td", text: @a.seccion.name
    assert_select "td", text: @seccion_vieja.name
    # Y solo entonces vuelve la columna del año: con un año fijado repetía el
    # mismo texto en todas las filas (la lección de MOR-90).
    assert_select "th", text: "Año escolar"
  end

  test "la elección sobrevive a la siguiente petición" do
    sign_in @a.director
    post cambiar_anio_escolar_path, params: { id: @viejo.id }

    get enrollments_path
    get sections_path

    assert_select ".contexto-anio-select option[selected]", text: "2024-2025"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El profesor no elige
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Daniel: «los docentes no deberían necesitar ni siquiera ver algo anterior,
  # solo lo que están calificando». No es una cuestión de permisos: es que
  # darle el control es darle una manera de equivocarse de año en silencio.

  test "el profesor no ve el selector de año" do
    sign_in @a.profesor

    get dashboards_profesor_url

    assert_response :success
    assert_select ".contexto-anio-select", count: 0,
                  message: "el profesor no debe poder cambiar de año escolar"
  end

  test "y si lo intenta a mano, no pasa nada" do
    sign_in @a.profesor

    post cambiar_anio_escolar_path, params: { id: @viejo.id }
    get dashboards_profesor_url

    assert_select ".contexto-anio-select", count: 0
    assert_no_match(/2024-2025/, response.body,
                    "el profesor terminó viendo un año escolar que no le toca")
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El año se guarda en la sesión, así que hay que probarlo como una puerta
  # ══════════════════════════════════════════════════════════════════════════

  test "un año de OTRO colegio guardado en la sesión no abre nada" do
    ajeno = @b.periodo

    sign_in @a.director
    post cambiar_anio_escolar_path, params: { id: ajeno.id }
    get sections_path

    assert_response :success
    # Cae al año vigente del PROPIO colegio: el id ajeno no encuentra nada
    # porque `SchoolScoped` y el RLS lo filtran antes de llegar acá.
    assert_select ".contexto-anio-select option[selected]", text: "2025-2026"
    assert_no_match(/#{Regexp.escape(@b.colegio.name)}/, response.body)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que se CREA nace en el año de la sesión
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Es la mitad menos visible y la que más duele: una sección creada en el año
  # equivocado se descubre en diciembre, cuando no aparece en el boletín.

  test "una sección nueva nace en el año de la sesión, sin preguntarlo" do
    sign_in @a.director
    post cambiar_anio_escolar_path, params: { id: @viejo.id }

    assert_difference "Section.unscoped.count", 1 do
      post sections_path, params: { section: { name: "Q", grade_id: @a.grado.id, capacity: 25 } }
    end

    creada = Current.sin_aislamiento { Section.unscoped.order(:id).last }
    assert_equal @viejo.id, creada.academic_period_id,
                 "la sección se creó en un año distinto al de la sesión"
  end

  test "editar una sección NO le cambia el año, aunque lo manden en el formulario" do
    sign_in @a.director
    post cambiar_anio_escolar_path, params: { id: @viejo.id }

    patch section_path(@a.seccion),
          params: { section: { name: "A2", academic_period_id: @viejo.id } }

    @a.seccion.reload
    assert_equal "A2", @a.seccion.name, "el nombre sí se tenía que actualizar"
    assert_equal @a.periodo.id, @a.seccion.academic_period_id,
                 "mover una sección de año arrastraría sus notas y su asistencia"
  end

  test "un lapso nuevo nace en el año de la sesión" do
    sign_in @a.director
    post cambiar_anio_escolar_path, params: { id: @viejo.id }

    assert_difference "EvaluationMoment.unscoped.count", 1 do
      post evaluation_moments_path, params: { evaluation_moment: { name: "1er Lapso" } }
    end

    creado = Current.sin_aislamiento { EvaluationMoment.unscoped.order(:id).last }
    assert_equal @viejo.id, creado.academic_period_id
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El scope, sin pasar por HTTP
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Los tres caminos al año son distintos —columna propia, un join, dos joins—
  # y el que tiene dos es el que se rompe callado.

  test "el scope filtra igual con la columna propia, con un join y con dos" do
    con_el_colegio(@a.colegio) do
      Current.academic_period = @a.periodo

      assert_equal 1, Section.del_anio_de_la_sesion.count, "columna propia"
      # Dos, porque `colegio_completo` inscribe dos alumnos en esa sección.
      assert_equal 2, Enrollment.del_anio_de_la_sesion.count, "un join"
      assert_equal 1, ActivityGrade.del_anio_de_la_sesion.count, "dos joins"

      Current.academic_period = @viejo
      assert_equal 1, Section.del_anio_de_la_sesion.count, "la sección de 2024-2025"
      assert_equal 0, Enrollment.del_anio_de_la_sesion.count
      assert_equal 0, ActivityGrade.del_anio_de_la_sesion.count

      # ⚠️ Sin año elegido NO filtra nada — al revés que `SchoolScoped`, que sin
      # colegio devuelve cero. Acá «todos» es una respuesta legítima.
      Current.academic_period = nil
      assert_equal 2, Section.del_anio_de_la_sesion.count
      assert_equal 1, ActivityGrade.del_anio_de_la_sesion.count
    end
  end
end
