require "test_helper"

# El RIF del docente, que es lo que el colegio necesita para pagarle.
#
#     CÉDULA   V-12345678      identifica a la persona · la verifica el SAIME
#     RIF      V-12345678-9    la nómina y el recibo   · lo emite el SENIAT
#
# ⚠️ No son dos formas de decir lo mismo: un profesor tiene los dos, y meter el
# RIF en el enum de `document_type` obligaría a elegir cuál guardar.
#
# ⚠️ Y vive en `users`, no en `teachers`: la misma maestra que da clase en dos
# colegios tiene UN solo RIF (`MOR-138`).
class RifDelDocenteTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @docente = @a.registro_de_profesor
    sign_in @a.director
  end

  def corregir(rif)
    patch teacher_path(@docente), params: { teacher: { user_attributes: {
      id: @docente.user_id, first_name: @docente.user.first_name, rif: rif
    } } }
  end

  # ── El campo ──────────────────────────────────────────────────────────────

  test "el formulario del docente lo pide" do
    get edit_teacher_path(@docente)

    assert_response :success
    assert_select "input[name='teacher[user_attributes][rif]']"
  end

  # ⚠️ A un alumno no se le pide: es el número de quien COBRA, no un dato de
  # identidad. Y su formulario ya es largo.
  test "el formulario del alumno no lo pide" do
    get new_student_path

    assert_select "input[name*=rif]", count: 0
  end

  # ── Guardar ───────────────────────────────────────────────────────────────

  test "se guarda sin guiones y se muestra con ellos" do
    corregir "V-12.345.678-9"

    assert_equal "V123456789", @docente.user.reload.rif
    assert_equal "V-12345678-9", @docente.user.rif_con_guiones

    get teacher_path(@docente)
    assert_select ".detail-value", text: "V-12345678-9"
  end

  test "un RIF mal escrito no se guarda en silencio" do
    corregir "12345"

    assert_response :unprocessable_entity
    assert_nil @docente.user.reload.rif
    assert_match(/una letra y nueve dígitos/, response.body)
  end

  test "vaciarlo lo borra, no lo deja en blanco" do
    corregir "V123456789"
    corregir ""

    # ⚠️ `nil` y no `""`: el índice único es parcial —`WHERE rif IS NOT NULL`—
    # así que la segunda persona sin RIF chocaría contra la primera.
    assert_nil @docente.user.reload.rif
  end

  test "dos personas no pueden tener el mismo RIF" do
    corregir "V123456789"

    otro = con_el_colegio(@a.colegio) { Teacher.where.not(id: @docente.id).first }
    otro ||= con_el_colegio(@a.colegio) do
      usuario = User.create!(first_name: "Otro", last_name: "Docente",
                             email: "otro.#{@a.colegio.id}@t.test", password: "123123",
                             document: "V-#{@a.colegio.id}99", document_type: :cedula_v)
      Teacher.create!(user: usuario, school: @a.colegio)
    end

    patch teacher_path(otro), params: { teacher: { user_attributes: {
      id: otro.user_id, first_name: otro.user.first_name, rif: "V123456789"
    } } }

    assert_response :unprocessable_entity
  end
end
