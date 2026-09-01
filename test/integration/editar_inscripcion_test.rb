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

  test "el alta ofrece el id del alumno, no el de su usuario" do
    get new_enrollment_path

    valores = css_select("select[name*='[student_id]'] option").map { |o| o["value"] }.compact_blank.map(&:to_i)
    ids_de_alumno = con_el_colegio(@a.colegio) { Student.pluck(:id) }

    assert_equal ids_de_alumno.sort, valores.sort,
                 "el desplegable manda el id del usuario donde va el del alumno"
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
