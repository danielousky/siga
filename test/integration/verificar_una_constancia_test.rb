require "test_helper"

# El verificador, con las dos cosas que ahora puede comprobar.
#
# Daniel, tras la prueba de campo: *«la constancia debe poder ser validada como
# los boletines»* y *«el informe descriptivo no aparece en el verificador»*.
class VerificarUnaConstanciaTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(nombre: "Colegio Verificador", nivel: :primaria)
    @director = con_el_colegio(@esc.colegio) do
      u = usuario("dir", @esc.colegio.id)
      Admin.create!(user: u, school: @esc.colegio, role: :director)
      u
    end
  end

  # ── la constancia ─────────────────────────────────────────────────────────

  test "emitir una constancia deja su rastro con código" do
    sign_in @director

    assert_difference "con_el_colegio(@esc.colegio) { Constancia.count }", 1 do
      post constancias_path, params: { section_id: @esc.seccion.id,
                                       enrollment_id: @esc.inscripcion.id }
    end

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  # ⚠️ Sin sesión: quien verifica es una embajada o un banco, no alguien del
  # colegio.
  test "cualquiera comprueba una constancia con su código" do
    constancia = con_el_colegio(@esc.colegio) { Constancia.emitir!(@esc.inscripcion, por: @director) }

    get verificar_path(code: constancia.code)

    assert_response :success
    assert_select ".verificacion-sello", /Auténtica/
    assert_select ".detail-value", @esc.alumno.user.apellidos_y_nombres
  end

  # ⚠️ Lo que afirma NO es lo mismo que un boletín, y tiene que leerse: una
  # constancia refleja la situación del día en que se emitió. Callarlo invita a
  # leerla como «este alumno estudia aquí hoy», que un papel con fecha no puede
  # sostener.
  test "la constancia verificada dice que es del día en que se emitió" do
    constancia = con_el_colegio(@esc.colegio) { Constancia.emitir!(@esc.inscripcion, por: @director) }

    get verificar_path(code: constancia.code)

    assert_select ".nota-ayuda", /situación del día en que se emitió/
  end

  # ⚠️ Congelada: el colegio puede renombrar la sección después, y el papel
  # emitido tiene que seguir diciendo lo que decía.
  test "renombrar la sección no cambia lo que decía el papel" do
    constancia = con_el_colegio(@esc.colegio) do
      c = Constancia.emitir!(@esc.inscripcion, por: @director)
      @esc.seccion.update!(name: "Z")
      c
    end

    get verificar_path(code: constancia.code)

    assert_select ".detail-value", /–\s*A\z/
  end

  # ⚠️ UNA sola ruta para los dos documentos: quien tiene el papel teclea lo que
  # dice, sin saber si es boletín o constancia.
  test "el mismo verificador resuelve boletines y constancias" do
    boletin = con_el_colegio(@esc.colegio) do
      ReportCard.create!(enrollment: @esc.inscripcion, evaluation_moment: @esc.lapso(1),
                         issued_by: @director,
                         snapshot: ReportCardData.para(enrollment: @esc.inscripcion,
                                                       evaluation_moment: @esc.lapso(1)))
    end

    get verificar_path(code: boletin.code)
    assert_response :success
    assert_select ".verificacion-sello", /Auténtico/
  end

  test "un código inventado da 404" do
    get verificar_path(code: "CON-XXXX-YYYY")

    assert_response :not_found
  end

  # ── el informe descriptivo ────────────────────────────────────────────────

  # ⚠️ Estaba CONGELADO en el boletín desde el principio y el verificador no lo
  # dibujaba. En primaria es la mitad del documento: un boletín verificado que
  # lo calla no coincide con el papel que la familia tiene en la mano.
  test "el boletín verificado muestra el informe descriptivo" do
    boletin = con_el_colegio(@esc.colegio) do
      Informe.create!(enrollment: @esc.inscripcion, evaluation_moment: @esc.lapso(1),
                      escrito_por: @director,
                      cuerpo: "Avanzó mucho en la lectura este lapso.")
      ReportCard.create!(enrollment: @esc.inscripcion, evaluation_moment: @esc.lapso(1),
                         issued_by: @director,
                         snapshot: ReportCardData.para(enrollment: @esc.inscripcion,
                                                       evaluation_moment: @esc.lapso(1)))
    end

    get verificar_path(code: boletin.code)

    assert_select ".verificacion-informe", /Avanzó mucho en la lectura/
  end
end
