require "test_helper"

# ⚠️ No confundir con `puesta_en_marcha_test.rb`, que prueba el PLAN: que los
# pasos se pongan en verde, que un paso bloqueado ofrezca el camino, que la
# franja aparezca. Este recorre el camino de verdad, creando los datos, y
# prueba que las ocho pantallas encajen EN ORDEN.
#
# La puesta en marcha completa, de punta a punta, como la vive un director que
# acaba de registrar su colegio en `/registrarse`.
#
# ## Por qué este test y no otro
#
# Es el único camino que **todo** cliente recorre, y el único donde un error
# cuesta el cliente entero: quien se traba el primer día no vuelve. Los demás
# tests prueban una pantalla; este prueba que las ocho encajen **en orden**, con
# los datos que la anterior dejó.
#
# El QA de Daniel del 31/8 y el 1/9 encontró tres cosas acá —los lapsos sin
# sembrar, el departamento obligatorio, los listados sin estado vacío— y las tres
# eran de encaje entre pasos, no de una pantalla sola.
class ArranqueDePuntaAPuntaTest < ActionDispatch::IntegrationTest
  # El director llega sin nada: ni colegio, ni rol. Es el estado exacto en el
  # que `/registrarse` deja a una persona (MOR-158).
  setup do
    @director = User.create!(first_name: "Rosa", last_name: "Directora",
                             email: "rosa@colegionuevo.test", password: "123123",
                             document: "V-19283746", document_type: :cedula_v)
    sign_in @director
  end

  test "un colegio nuevo llega hasta poder calificar, sin trabarse" do
    # ── 1. El colegio ────────────────────────────────────────────────────────
    post mi_colegio_path, params: { school: {
      name: "U.E. Colegio Nuevo", dea_code: "PD00000001", location: "Caracas",
      entidad_federal: "Distrito Capital", municipio_libre: "Libertador",
      parroquia_libre: "El Recreo", direccion: "Av. Principal", telefono: "0212-5551234"
    } }
    colegio = Current.sin_aislamiento { School.find_by(dea_code: "PD00000001") }
    assert colegio, "no se pudo registrar el colegio"
    assert_equal @director.id, Current.sin_aislamiento { Admin.unscoped.find_by(school_id: colegio.id) }&.user_id,
                 "quien registra tiene que quedar como director de su colegio"

    # ── 2. Los niveles → los grados ──────────────────────────────────────────
    #
    # Tres casillas en vez de catorce formularios. Es el corazón del arranque.
    get niveles_del_colegio_path
    assert_response :success

    patch niveles_del_colegio_path, params: { niveles: [ "primaria" ] }
    grados = con_el_colegio(colegio) { Grade.count }
    assert_equal 6, grados, "marcar «primaria» tiene que sembrar los seis grados"

    # ── 3. El año escolar → sus tres lapsos ──────────────────────────────────
    #
    # Un número, y de ahí sale todo: el nombre, las dos fechas y los lapsos.
    post academic_periods_path, params: { anio: 2026 }
    periodo, lapsos = con_el_colegio(colegio) do
      p = AcademicPeriod.order(:id).last
      [ p, p&.evaluation_moments&.pluck(:name) ]
    end
    assert_equal "2026-2027", periodo.name
    assert_equal [ "1er Lapso", "2do Lapso", "3er Lapso" ], lapsos,
                 "el año escolar tiene que nacer con sus tres lapsos (MOR-163)"

    # ── 4. Las materias, SIN departamento ────────────────────────────────────
    #
    # ⚠️ Acá se trababa: el departamento era obligatorio y el plan lo presenta
    # como opcional. Un colegio de 150 alumnos no tiene departamentos.
    post subjects_path, params: { subject: { code: "MAT", name: "Matemática" } }
    post subjects_path, params: { subject: { code: "LEN", name: "Castellano y Literatura" } }
    assert_equal 2, con_el_colegio(colegio) { Subject.count },
                 "no se pudieron cargar las materias sin crear departamentos primero"

    # ── 5. La sección ────────────────────────────────────────────────────────
    #
    # El año escolar NO se pregunta: sale de la sesión (MOR-165).
    primer_grado = con_el_colegio(colegio) { Grade.en_orden.first }
    post sections_path, params: { section: { name: "A", grade_id: primer_grado.id, capacity: 30 } }
    seccion = con_el_colegio(colegio) { Section.order(:id).last }
    assert seccion, "no se pudo crear la sección"
    assert_equal periodo.id, seccion.academic_period_id,
                 "la sección nació en un año escolar distinto al de la sesión"

    # ── 6. El profesor ───────────────────────────────────────────────────────
    post teachers_path, params: { teacher: { user_attributes: {
      first_name: "Carlos", last_name: "García", document: "V-12345678",
      document_type: "cedula_v", email: "carlos@colegionuevo.test"
    } } }
    profesor = con_el_colegio(colegio) { Teacher.order(:id).last }
    assert profesor, "no se pudo cargar el profesor"

    # ── 7. El alumno ─────────────────────────────────────────────────────────
    #
    # Sin correo ni cédula: es un niño de primaria (MOR-142).
    post students_path, params: { student: { user_attributes: {
      first_name: "Ana", last_name: "Pérez", cedula_escolar: "PD-000001"
    } } }
    alumno = con_el_colegio(colegio) { Student.order(:id).last }
    assert alumno, "no se pudo cargar el alumno sin correo ni cédula"

    # ── 8. La inscripción ────────────────────────────────────────────────────
    post enrollments_path, params: { enrollment: {
      student_id: alumno.id, section_id: seccion.id, enrollment_date: Date.current, status: "regular"
    } }
    assert_equal 1, con_el_colegio(colegio) { Enrollment.count },
                 "el alumno no quedó inscrito en su sección"

    # ── 9. Y el colegio ya puede trabajar ────────────────────────────────────
    get dashboards_administrador_path
    assert_response :success
    assert_select ".contexto-colegio-nombre", text: "U.E. Colegio Nuevo"

    get report_cards_path
    assert_response :success, "con la matrícula cargada, la emisión de boletines tiene que abrir"
  end

  # ⚠️ El plan tiene que reflejar lo hecho, paso a paso. Es lo que le dice al
  # director que va avanzando — y `PasosDeArranque` DEDUCE el progreso de los
  # datos, no lo guarda. Si la deducción se rompe, el director ve su colegio
  # cargado y un plan que dice que no empezó.
  test "el plan refleja lo que se va cargando, sin guardar ninguna bandera" do
    post mi_colegio_path, params: { school: {
      name: "U.E. Del Plan", dea_code: "PD00000002", location: "Caracas",
      entidad_federal: "Miranda", municipio_libre: "Sucre", parroquia_libre: "Petare"
    } }
    colegio = Current.sin_aislamiento { School.find_by(dea_code: "PD00000002") }

    listos = ->(*) { con_el_colegio(colegio) { PasosDeArranque.new(colegio).pasos.select(&:listo).map(&:clave) } }

    assert_empty listos.call - [ :identidad ], "un colegio recién creado no tiene ningún paso hecho"

    patch niveles_del_colegio_path, params: { niveles: [ "primaria" ] }
    assert_includes listos.call, :niveles

    post academic_periods_path, params: { anio: 2026 }
    assert_includes listos.call, :ano_escolar

    # ⚠️ El paso del pensum necesita las DOS mitades: una materia sin nadie que
    # la dicte no deja cargar una nota.
    post subjects_path, params: { subject: { code: "MAT", name: "Matemática" } }
    assert_not_includes listos.call, :materias, "con materias y sin profesores todavía falta"

    post teachers_path, params: { teacher: { user_attributes: {
      first_name: "Carlos", last_name: "García", document: "V-12345678",
      document_type: "cedula_v", email: "carlos@delplan.test"
    } } }
    assert_includes listos.call, :materias
  end
end
