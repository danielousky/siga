require "test_helper"

# Qué se puede cambiar de una inscripción, y qué no (MOR-182).
#
# Daniel: *«¿encuentras sentido en editar una inscripción? Lo que veo es el
# cambio de estado o de sección. Nunca el cambio de estudiante»*.
#
# Tiene razón, y no es una preferencia de pantalla: una inscripción ES «este
# alumno en esta sección». Cambiarle el alumno no la corrige, **la convierte en
# otra** — y se lleva consigo las notas, la asistencia y los boletines que
# colgaban de ella, que son de la persona anterior.
class EditarInscripcionTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    @otra_seccion = con_el_colegio(@a.colegio) do
      Section.create!(grade: @a.grado, academic_period: @a.periodo, name: "Z", capacity: 30)
    end
    sign_in @a.director
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que sí
  # ══════════════════════════════════════════════════════════════════════════

  test "se cambia de sección" do
    patch enrollment_path(@a.inscripcion), params: { enrollment: { section_id: @otra_seccion.id } }

    assert_equal @otra_seccion.id, con_el_colegio(@a.colegio) { @a.inscripcion.reload.section_id }
  end

  test "y se cambia el estado" do
    patch enrollment_path(@a.inscripcion), params: { enrollment: { status: "retirado" } }

    assert con_el_colegio(@a.colegio) { @a.inscripcion.reload.retirado? }
  end

  # El estado son dos opciones: botones, no un desplegable que hay que abrir.
  test "el estado son botones" do
    get edit_enrollment_path(@a.inscripcion)

    assert_select "select[name*='[status]']", count: 0
    assert_select ".opcion-boton input[type=radio][name*='[status]']", 2
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que NO
  # ══════════════════════════════════════════════════════════════════════════

  test "el alumno no se puede cambiar, ni mandándolo por HTTP" do
    otro = con_el_colegio(@a.colegio) { Student.where.not(id: @a.alumno.id).first }
    assert otro, "hacen falta dos alumnos para probar esto"

    patch enrollment_path(@a.inscripcion), params: { enrollment: { student_id: otro.id } }

    assert_equal @a.alumno.id, con_el_colegio(@a.colegio) { @a.inscripcion.reload.student_id },
                 "cambiar el alumno se lleva sus notas y su asistencia a otra persona"
  end

  test "la fecha tampoco: es un hecho, no una preferencia" do
    original = con_el_colegio(@a.colegio) { @a.inscripcion.enrollment_date }

    patch enrollment_path(@a.inscripcion), params: { enrollment: { enrollment_date: Date.new(2000, 1, 1) } }

    assert_equal original, con_el_colegio(@a.colegio) { @a.inscripcion.reload.enrollment_date }
  end

  test "y la pantalla no los ofrece: el alumno se muestra como dato" do
    get edit_enrollment_path(@a.inscripcion)

    assert_select "select[name*='[student_id]']", count: 0
    assert_select "input[name*='[enrollment_date]']", count: 0
    assert_match(/#{Regexp.escape(@a.alumno.user.apellidos_y_nombres)}/, response.body)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # ⚠️ El bug que había en el alta
  # ══════════════════════════════════════════════════════════════════════════
  #
  # El desplegable mandaba `s.user_id` donde `enrollments.student_id` espera el
  # id del ALUMNO: dos tablas distintas, dos numeraciones distintas. La
  # inscripción quedaba apuntando a otra persona —o a ninguna— sin que nada
  # avisara. Es el mismo error que tenía el conteo del panel (MOR-180).

  # ⚠️ El alta dejó de ser un `<select>` de trescientos: ahora es un buscador
  # con un botón por alumno (`enrollments/new`). El invariante no cambió —lo que
  # viaja tiene que ser el id del ALUMNO— pero ahora viaja en el `value` del
  # botón que se toca.
  test "el alta ofrece el id del alumno, no el de su usuario" do
    # ⚠️ Uno SIN inscribir: los del escenario ya lo están, y a esos la pantalla
    # les muestra dónde en vez de un botón — que es lo que evita inscribirlos
    # dos veces.
    nuevo = con_el_colegio(@a.colegio) do
      usuario = User.create!(first_name: "SIN", last_name: "INSCRIBIR",
                             cedula_escolar: "V#{@a.colegio.id}90000001")
      Student.create!(user: usuario, school: @a.colegio, school_card: "SI-#{@a.colegio.id}")
    end

    get new_enrollment_path

    boton = css_select("button[name='enrollment[student_id]']").first

    assert_equal nuevo.id.to_s, boton["value"],
                 "el botón manda el id del usuario donde va el del alumno"
    assert_not_equal nuevo.user_id.to_s, boton["value"]
  end

  # ⚠️ Y quien YA está inscrito se lista igual, con su sección y sin botón. Es
  # lo que evita el error de septiembre: inscribir dos veces al mismo niño
  # porque no se sabía que ya estaba.
  test "el alta muestra a los ya inscritos, apagados y con dónde" do
    get new_enrollment_path

    assert_select ".inscribir-alumno--ya", 2
    assert_select ".inscribir-detalle", /ya inscrito en #{@a.seccion.grade.name}/
  end

  test "y por eso el alta inscribe a quien se eligió" do
    otro = con_el_colegio(@a.colegio) { Student.where.not(id: @a.alumno.id).first }

    post enrollments_path, params: { enrollment: {
      student_id: otro.id, section_id: @otra_seccion.id,
      enrollment_date: Date.current, status: "regular"
    } }

    creada = Current.sin_aislamiento { Enrollment.unscoped.order(:id).last }
    assert_equal otro.id, creada.student_id
  end
end
