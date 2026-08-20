require "test_helper"

# La verificación pública. Va SIN sesión a propósito: quien verifica un boletín
# —la familia, otro colegio, una universidad— normalmente no tiene cuenta.
#
# Ver MOR-98.
class VerificacionesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(alumnos: 1)

    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @esc.lapso(1), peso: 100, descripcion: "Examen")
      nota(examen, @esc.alumno, 17)

      @boletin = ReportCard.create!(
        enrollment: @esc.inscripcion, evaluation_moment: @esc.lapso(1),
        snapshot: ReportCardData.para(enrollment: @esc.inscripcion, evaluation_moment: @esc.lapso(1))
      )
    end
  end

  test "cualquiera verifica un boletín sin iniciar sesión" do
    get verificar_url(code: @boletin.code)

    assert_response :success
    assert_match "Boletín verificado", response.body
    assert_match @esc.alumno.user.last_name, response.body
    assert_match ">17<", response.body
  end

  # El RLS deja en cero filas cualquier consulta sin colegio, y acá NO hay sesión
  # de la que sacarlo. Sin la excepción acotada del controller, la verificación no
  # funcionaría nunca.
  test "funciona aunque no haya contexto de colegio en la sesión" do
    Current.reset

    get verificar_url(code: @boletin.code)

    assert_response :success
    assert_match @esc.colegio.name, response.body
  end

  test "un código inventado da 404 y lo dice sin culpar a nadie" do
    get verificar_url(code: "BOL-XXXX-YYYY")

    assert_response :not_found
    assert_match "No encontramos ese boletín", response.body
  end

  test "el código no distingue mayúsculas" do
    get verificar_url(code: @boletin.code.downcase)

    assert_response :success
    assert_match "Boletín verificado", response.body
  end

  test "sin código muestra el formulario para escribirlo" do
    get verificar_url

    assert_response :success
    assert_match "Verificar un boletín", response.body
    assert_match "BOL-XXXX-XXXX", response.body
  end

  test "el código no lleva caracteres que se confundan al dictarlo" do
    # Sin 0/O ni 1/I/L: el código se dicta por teléfono y se teclea a mano.
    assert_no_match(/[01ILO]/, @boletin.code.delete("BOL-"))
  end

  test "muestra lo ARCHIVADO, no lo que diga la base ahora" do
    con_el_colegio(@esc.colegio) do
      ActivityGrade.find_by(student_id: @esc.alumno.id).update!(score: 3)
    end

    get verificar_url(code: @boletin.code)

    assert_match ">17<", response.body, "el papel decía 17 y la verificación tiene que coincidir con el papel"
    assert_no_match(/>3</, response.body)
  end
end
