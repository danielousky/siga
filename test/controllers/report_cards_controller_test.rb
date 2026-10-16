require "test_helper"

# Un boletín es un documento oficial. Lo que se prueba acá: que diga las notas
# reales, que no imprima ceros falsos, que quede registrado quién lo emitió, y
# que la foto de las notas NO cambie si después alguien corrige una calificación.
#
# Ver MOR-98.
class ReportCardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(pesos: [30, 30, 40], alumnos: 3)

    con_el_colegio(@esc.colegio) do
      @examen = actividad(@esc, lapso: @esc.lapso(1), peso: 100, descripcion: "Examen")
      nota(@examen, @esc.alumno(1), 18)
      nota(@examen, @esc.alumno(2), 9)
      # El tercero queda SIN NOTA a propósito.

      @secretaria = usuario_admin(:secretaria)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Emitir
  # ══════════════════════════════════════════════════════════════════════════

  test "emitir la sección entera devuelve UN PDF con una página por alumno" do
    sign_in @secretaria

    assert_difference -> { cantidad(ReportCard) }, 3 do
      post report_cards_url, params: { section_id: @esc.seccion.id, evaluation_moment_id: @esc.lapso(1).id }
    end
    # El PDF está en la dirección de lo emitido (`EntregaDocumentos`).
    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF"), "la respuesta tiene que ser un PDF de verdad"
    assert_match(/boletines-1er-ano-a/, response.headers["Content-Disposition"])
  end

  test "emitir un solo alumno crea un solo boletín" do
    sign_in @secretaria

    assert_difference -> { cantidad(ReportCard) }, 1 do
      post report_cards_url, params: {
        section_id: @esc.seccion.id,
        evaluation_moment_id: @esc.lapso(1).id,
        enrollment_id: @esc.inscripcion(1).id
      }
    end
    follow_redirect!

    assert_equal "application/pdf", response.media_type
  end

  test "el boletín guarda las notas REALES del alumno" do
    sign_in @secretaria
    post report_cards_url, params: {
      section_id: @esc.seccion.id, evaluation_moment_id: @esc.lapso(1).id,
      enrollment_id: @esc.inscripcion(1).id
    }

    boletin = Current.sin_aislamiento { ReportCard.unscoped.order(:id).last }
    matematica = boletin.snapshot["materias"].find { |m| m["materia"] == "Matemática" }

    assert_equal 18, matematica["nota"]
    assert_equal 18, boletin.snapshot["promedio"]
    assert_equal "Matemática", matematica["materia"]
  end

  test "una materia sin nota se archiva como nil, NUNCA como cero" do
    sign_in @secretaria
    post report_cards_url, params: {
      section_id: @esc.seccion.id, evaluation_moment_id: @esc.lapso(1).id,
      enrollment_id: @esc.inscripcion(3).id   # el alumno sin notas
    }

    boletin = Current.sin_aislamiento { ReportCard.unscoped.order(:id).last }
    matematica = boletin.snapshot["materias"].find { |m| m["materia"] == "Matemática" }

    assert_nil matematica["nota"], "un cero acá es una reclamación en la dirección"
    assert_nil boletin.snapshot["promedio"]
  end

  test "el PDF escribe Sin nota en letras, no un número" do
    sign_in @secretaria
    post report_cards_url, params: {
      section_id: @esc.seccion.id, evaluation_moment_id: @esc.lapso(1).id,
      enrollment_id: @esc.inscripcion(3).id
    }

    # El texto de un PDF de Prawn va comprimido, así que se comprueba sobre el
    # documento antes de renderizar.
    boletin = Current.sin_aislamiento { ReportCard.unscoped.order(:id).last }
    assert_nothing_raised { ReportCardPdf.new(boletin).render }
    assert boletin.snapshot["materias"].all? { |m| m["nota"].nil? || m["nota"].positive? }
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El archivo: la foto no se mueve
  # ══════════════════════════════════════════════════════════════════════════

  test "corregir una nota después NO cambia el boletín ya emitido" do
    sign_in @secretaria
    post report_cards_url, params: {
      section_id: @esc.seccion.id, evaluation_moment_id: @esc.lapso(1).id,
      enrollment_id: @esc.inscripcion(1).id
    }
    boletin = Current.sin_aislamiento { ReportCard.unscoped.order(:id).last }

    con_el_colegio(@esc.colegio) do
      ActivityGrade.find_by(evaluation_activity: @examen, student_id: @esc.alumno(1).id).update!(score: 5)
    end

    matematica = Current.sin_aislamiento { boletin.reload }.snapshot["materias"].find { |m| m["materia"] == "Matemática" }
    assert_equal 18, matematica["nota"], "el papel que la familia se llevó decía 18"
  end

  test "reemitir crea una fila nueva con otro código, no pisa la anterior" do
    sign_in @secretaria
    2.times do
      post report_cards_url, params: {
        section_id: @esc.seccion.id, evaluation_moment_id: @esc.lapso(1).id,
        enrollment_id: @esc.inscripcion(1).id
      }
    end

    codigos = Current.sin_aislamiento { ReportCard.unscoped.pluck(:code) }
    assert_equal 2, codigos.size
    assert_equal 2, codigos.uniq.size
  end

  test "la emisión queda registrada en la auditoría" do
    sign_in @secretaria

    assert_difference -> { cantidad(ActivityLog) }, 1 do
      post report_cards_url, params: { section_id: @esc.seccion.id, evaluation_moment_id: @esc.lapso(1).id }
    end

    registro = Current.sin_aislamiento { ActivityLog.unscoped.order(:id).last }
    assert_equal "report_cards_issued", registro.action
    assert_match(/emitió 3 boletines/, registro.message)
    assert_equal 3, registro.metadata["codigos"].size
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Quién puede emitir
  # ══════════════════════════════════════════════════════════════════════════

  test "un profesor no emite boletines" do
    docente = con_el_colegio(@esc.colegio) do
      usuario = User.create!(first_name: "Prof", last_name: "Uno",
                             email: "prof.#{@esc.seccion.id}@test.edu", password: "123123",
                        document: "V-#{"prof.#{@esc.seccion.id}@test.edu".bytes.sum}")
      Teacher.create!(user: usuario, school: @esc.colegio)
      usuario
    end

    sign_in docente
    get report_cards_url

    assert_redirected_to dashboards_profesor_path
    assert_match(/dirección o la secretaría/, flash[:alert])
  end

  test "un estudiante no emite boletines" do
    sign_in @esc.alumno(1).user

    get report_cards_url
    assert_redirected_to dashboards_estudiante_path
  end

  private

  def usuario_admin(rol)
    usuario = User.create!(first_name: "Secre", last_name: "Taria",
                           email: "secre.#{@esc.colegio.id}@test.edu", password: "123123",
                        document: "V-#{"secre.#{@esc.colegio.id}@test.edu".bytes.sum}")
    Admin.create!(user: usuario, school: @esc.colegio, role: rol)
    usuario
  end
end
