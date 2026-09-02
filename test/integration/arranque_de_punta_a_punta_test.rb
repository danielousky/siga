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
  # ⚠️ El colegio se crea REGISTRÁNDOSE, que desde `MOR-208` es un solo paso.
  # Antes había un usuario suelto y después `/mi-colegio`; esa pantalla ya no
  # existe, y el andamiaje viene sembrado con el alta.
  def registrar(nombre, dea, niveles: %w[primaria])
    post registrarse_path, params: {
      user: { first_name: "Rosa", last_name: "Directora",
              email: "rosa#{dea}@colegionuevo.test",
              password: "clave-larga-1", password_confirmation: "clave-larga-1" },
      school: { name: nombre, dea_code: dea }, niveles: niveles, cargo: "director"
    }
    # ⚠️ El correo se guarda en MINÚSCULA (`case_insensitive_keys` de Devise),
    # así que buscarlo tal como se escribió no lo encuentra.
    @director = User.find_by(email: "rosa#{dea}@colegionuevo.test".downcase)
    Current.sin_aislamiento { School.find_by(dea_code: dea) }
  end

  test "un colegio nuevo llega hasta poder calificar, sin trabarse" do
    # ── 1. El colegio, con su andamiaje ──────────────────────────────────────
    colegio = registrar("U.E. Colegio Nuevo", "PD00000001")
    assert colegio, "no se pudo registrar el colegio"
    assert_equal @director.id, Current.sin_aislamiento { Admin.unscoped.find_by(school_id: colegio.id) }&.user_id,
                 "quien registra tiene que quedar como director de su colegio"

    # ── 2. Los grados ya vienen puestos ──────────────────────────────────────
    #
    # Se marcaron al registrarse, así que acá no hay nada que hacer. La pantalla
    # sigue existiendo para el colegio que agrega un nivel después.
    get niveles_del_colegio_path
    assert_response :success
    grados = con_el_colegio(colegio) { Grade.count }
    assert_equal 6, grados, "marcar «primaria» tiene que sembrar los seis grados"

    # ── 3. Los años escolares tampoco se crean ───────────────────────────────
    #
    # Se sembraron al registrarse: el que corre y los cuatro anteriores, cada uno
    # con sus tres lapsos. Los anteriores están para poder subir el historial.
    # ⚠️ El año de la SESIÓN, no el más nuevo. Desde `MOR-208` se siembran cinco
    # años —el que corre y los cuatro anteriores— y la sesión elige el que está
    # en operación, no la fila más reciente. Comparar contra «el último creado»
    # es exactamente la trampa que `anio_por_defecto` existe para evitar.
    periodo, lapsos = con_el_colegio(colegio) do
      p = AcademicPeriod.en_operacion || AcademicPeriod.vigente
      [ p, p&.evaluation_moments&.pluck(:name) ]
    end
    assert periodo, "el año escolar tiene que venir sembrado"
    assert_equal [ "1er Lapso", "2do Lapso", "3er Lapso" ], lapsos,
                 "el año escolar tiene que nacer con sus tres lapsos (MOR-163)"

    assert_equal 5, con_el_colegio(colegio) { AcademicPeriod.count },
                 "el que corre y los cuatro anteriores, para poder subir el historial"

    # ── 4. Las materias ──────────────────────────────────────────────────────
    #
    # ⚠️ Las del pensum YA están: se sembraron al registrarse (`MOR-208`). Lo
    # que se prueba acá es que el colegio pueda agregar LA SUYA —la que ningún
    # ministerio propone— sin crear un departamento primero.
    #
    # Acá se trababa antes: el departamento era obligatorio y el plan lo
    # presenta como opcional. Un colegio de 150 alumnos no tiene departamentos.
    sembradas = con_el_colegio(colegio) { Subject.count }
    assert_operator sembradas, :>, 0, "el pensum tiene que venir sembrado"

    post subjects_path, params: { subject: { code: "COMP", name: "Computación" } }

    propia = con_el_colegio(colegio) { Subject.find_by(code: "COMP") }
    assert propia, "no se pudo cargar una materia sin crear departamentos primero"
    assert_nil propia.department_id

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
    assert_select ".contexto-colegio-nombre", text: "U.E. COLEGIO NUEVO"

    get report_cards_path
    assert_response :success, "con la matrícula cargada, la emisión de boletines tiene que abrir"
  end

  # ⚠️ El plan tiene que reflejar lo hecho, paso a paso. Es lo que le dice al
  # director que va avanzando — y `PasosDeArranque` DEDUCE el progreso de los
  # datos, no lo guarda. Si la deducción se rompe, el director ve su colegio
  # cargado y un plan que dice que no empezó.
  test "el plan refleja lo que se va cargando, sin guardar ninguna bandera" do
    colegio = registrar("U.E. Del Plan", "PD00000002")

    listos = ->(*) { con_el_colegio(colegio) { PasosDeArranque.new(colegio).pasos.select(&:listo).map(&:clave) } }

    # ⚠️ Desde `MOR-208` un colegio recién registrado YA tiene pasos hechos, y
    # ese es el punto del cambio: los niveles y el año escolar se sembraron al
    # registrarse. Lo que sigue sin estar es lo que solo el colegio sabe.
    assert_equal [ :niveles, :identidad, :ano_escolar ].to_set, listos.call.to_set,
                 "el andamiaje se siembra al registrarse"

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
