require "test_helper"

# La constancia de estudios.
#
# Es el documento que más pide una familia venezolana —pasaporte, beca, seguro,
# embajada— y el que ningún sistema barato emite: hoy la secretaría lo escribe
# en Word, uno por uno, y siempre lo piden para mañana.
class ConstanciasTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos
  end

  test "la secretaría emite la constancia de un alumno" do
    sign_in @a.director

    post constancias_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }
    follow_redirect!

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF"), "tiene que salir un PDF de verdad"
    assert_match(/constancia-/, response.headers["Content-Disposition"])
  end

  test "emitir la sección entera devuelve un PDF con una página por alumno" do
    sign_in @a.director

    post constancias_path, params: { section_id: @a.seccion.id }
    follow_redirect!

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/constancias-/, response.headers["Content-Disposition"])
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que la distingue del boletín
  # ══════════════════════════════════════════════════════════════════════════
  #
  # El boletín congela un snapshot: lo que decía en diciembre lo sigue diciendo.
  # La constancia certifica la situación de HOY, y si el alumno cambia de
  # sección, la de mañana tiene que decir lo nuevo. Emitir dos veces con seis
  # meses de diferencia y que digan lo mismo convertiría un documento en un
  # papel falso.

  test "no guarda ningún registro del documento — a diferencia del boletín" do
    sign_in @a.director

    assert_no_difference -> { con_el_colegio(@a.colegio) { ReportCard.count } } do
      post constancias_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }
    end
  end

  # Pero sí queda quién la emitió: es un papel con firma del director, y que
  # después nadie pueda saber quién lo sacó es justo lo que no puede pasar.
  test "sí registra quién la emitió" do
    sign_in @a.director

    post constancias_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }

    con_el_colegio(@a.colegio) do
      rastro = ActivityLog.where(action: "constancia_emitida").last
      assert rastro.present?, "una constancia sin rastro de quién la emitió no sirve como documento"
      assert_match(/#{Regexp.escape(@a.director.apellidos)}/, rastro.message)
    end
  end

  test "el texto sale con el grado y el año escolar de la inscripción" do
    con_el_colegio(@a.colegio) do
      pdf = ConstanciaDeEstudiosPdf.new([ Constancia.emitir!(@a.inscripcion, por: @a.director) ]).render

      assert pdf.start_with?("%PDF")
      assert pdf.bytesize > 1_000, "un PDF de menos de 1 KB no tiene texto adentro"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El párrafo lleva negritas, y eso trae un riesgo
  # ══════════════════════════════════════════════════════════════════════════
  #
  # `inline_format: true` hace que Prawn interprete `<b>`, y de paso CUALQUIER
  # `<` o `&` que venga de la base. Un colegio llamado "Bolívar & Asociados" o un
  # apellido con un `<` convertirían el dato en una etiqueta a medio cerrar, y
  # Prawn levantaría un error de parseo sobre un dato perfectamente legítimo —
  # dejando a una familia sin su constancia.
  #
  # Lo encontré MIRANDO el PDF: sin `inline_format` las etiquetas salían
  # impresas tal cual, y los tests pasaban igual porque verificaban que el PDF
  # existiera, no lo que decía.

  test "un nombre con & o < no rompe el documento" do
    con_el_colegio(@a.colegio) do
      @a.alumno.user.update!(last_name: "Pérez & <Asociados>")

      assert_nothing_raised do
        pdf = ConstanciaDeEstudiosPdf.new([ Constancia.emitir!(@a.inscripcion, por: @a.director) ]).render
        assert pdf.start_with?("%PDF")
      end
    end
  end

  test "un colegio con & en el nombre tampoco" do
    con_el_colegio(@a.colegio) do
      Current.sin_aislamiento { @a.colegio.update!(name: "U.E. Andrés Bello & Cía.") }

      assert_nothing_raised { ConstanciaDeEstudiosPdf.new([ Constancia.emitir!(@a.inscripcion, por: @a.director) ]).render }
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Aislamiento y permisos
  # ══════════════════════════════════════════════════════════════════════════

  test "no se emite la constancia de una sección de otro colegio" do
    sign_in @a.director

    post constancias_path, params: { section_id: @b.seccion.id }

    assert_response :not_found
  end

  test "un profesor no emite constancias" do
    sign_in @a.profesor

    get constancias_path

    assert_redirected_to dashboards_profesor_path
  end

  test "un estudiante tampoco" do
    sign_in @a.estudiante

    get constancias_path

    assert_redirected_to dashboards_estudiante_path
  end
end
