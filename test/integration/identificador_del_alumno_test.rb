require "test_helper"

# UN campo para las DOS cédulas, en el alta de alumno.
#
#     12345678       ──►  cédula de identidad
#     V-12.345.678   ──►  cédula de identidad, y la V queda en `document_type`
#     V20140000012   ──►  cédula escolar, la que asigna el MPPE
#
# ## ⚠️ Por qué se fusionan
#
# Son dos columnas porque son dos documentos, y eso no cambia. Pero quien carga
# un alumno no piensa en dos: piensa «con qué se identifica este niño». Pedirlas
# por separado obliga a leer dos rótulos, entender la diferencia y elegir, para
# escribir UN número.
#
# ⚠️ Y solo el formulario del ALUMNO las pide las dos. Profesor, administrador y
# representante tienen cédula y punto: ahí no hay nada que fusionar.
class IdentificadorDelAlumnoTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    sign_in @a.director
  end

  def registrar(identificador)
    post students_path, params: { student: { user_attributes: {
      first_name: "ÁLVARO", last_name: "LÓPEZ", identificador: identificador
    } } }
    con_el_colegio(@a.colegio) { Student.order(:id).last.user }
  end

  # ── El campo ──────────────────────────────────────────────────────────────

  test "el alta de alumno pide UN identificador, no dos cédulas" do
    get new_student_path

    assert_response :success
    assert_select "input[name='student[user_attributes][identificador]']"
    # Y las dos que reemplaza ya no están.
    assert_select "input[name='student[user_attributes][document]']", count: 0
    assert_select "input[name='student[user_attributes][cedula_escolar]']", count: 0
  end

  # ⚠️ Profesor y administrador NO se tocan: ahí nunca hubo dos campos.
  test "el alta de profesor conserva su cédula de siempre" do
    get new_teacher_path

    assert_select "input[name='teacher[user_attributes][document]']"
    assert_select "input[name='teacher[user_attributes][identificador]']", count: 0
  end

  # ── Lo que decide el formato ──────────────────────────────────────────────

  test "ocho dígitos son cédula de identidad" do
    persona = registrar("12345678")

    assert_equal "12345678", persona.document
    assert_nil persona.cedula_escolar
  end

  test "la sigla de adelante queda en el tipo de documento" do
    persona = registrar("E-8765432")

    assert_equal "8765432", persona.document
    assert_equal "cedula_e", persona.document_type
  end

  # ⚠️ Es el LARGO lo que distingue, no la letra: «V-12345678» y «V20140000012»
  # empiezan igual.
  test "doce caracteres son cédula escolar" do
    persona = registrar("V20140000012")

    assert_equal "V20140000012", persona.cedula_escolar
    assert_nil persona.document
  end

  # ⚠️ NO es opcional, y la pantalla no puede decir que lo es: el modelo exige
  # una de las dos (`tiene_algun_identificador`). La escolar existe justamente
  # para el alumno que todavía no tiene cédula, así que siempre hay una.
  test "vacío no se guarda, y el campo no se ofrece como opcional" do
    assert_no_difference -> { con_el_colegio(@a.colegio) { Student.count } } do
      registrar("")
    end

    get new_student_path
    assert_select "input[name='student[user_attributes][identificador]'][required]"
  end

  # ── Corregir ──────────────────────────────────────────────────────────────

  # ⚠️ Quien ya tiene las DOS ve los DOS campos: con uno solo no habría cómo
  # corregir la que no se está mostrando, y la escolar NO se borra cuando llega
  # la de identidad.
  test "con las dos cargadas, el formulario vuelve a mostrar las dos" do
    alumno = @a.escenario.alumno
    con_el_colegio(@a.colegio) do
      alumno.user.update!(document: "28123456", document_type: :cedula_v,
                          cedula_escolar: "V20140000099")
    end

    get edit_student_path(alumno)

    assert_select "input[name='student[user_attributes][document]']"
    assert_select "input[name='student[user_attributes][cedula_escolar]']"
    assert_select "input[name='student[user_attributes][identificador]']", count: 0
  end

  # ⚠️ Escribir una cédula escolar no puede borrar la de identidad que ya
  # estaba: son dos documentos, no dos formas del mismo.
  test "guardar la escolar no pisa la de identidad" do
    persona = registrar("12345678")
    persona.identificador = "V20140000077"

    assert_equal "12345678", persona.document
    assert_equal "V20140000077", persona.cedula_escolar
  end
end
