require "test_helper"

# El informe descriptivo del docente (MOR-216).
#
# Es lo que hace que una boleta de primaria se lea como un boletín y no como una
# factura: un «PA» dice en qué banda cayó el niño; esto dice que lee mejor que
# en octubre.
class InformeDescriptivoTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(1)
    # ⚠️ El guía de la sección es quien escribe. El escenario no asigna ninguno.
    con_el_colegio(@a.colegio) { @a.seccion.update!(leader_teacher: @a.registro_de_profesor) }
  end

  # ── Dónde vive la pantalla (QA de Cyndi) ──────────────────────────────────
  #
  # ⚠️ Es una PESTAÑA de la sección, no un botón en la cabecera de «Calificar».
  # El informe se escribe junto con las notas, en el mismo lapso y la misma
  # sección: es otro sitio donde trabajar, y eso es lo que dice una pestaña. Un
  # botón en la cabecera se lee como una acción sobre lo que ya está en pantalla.
  test "el informe es una pestaña de la sección, y llega marcada" do
    sign_in @a.profesor

    get section_informes_path(@a.seccion, lapso: @lapso.id)

    assert_response :success
    assert_select ".pestana.activa", text: "Informes"
    # Y las otras siguen ahí: es la misma sección vista de otro ángulo.
    assert_select ".pestana", text: "Calificar"
    assert_select ".pestana", text: "Alumnos"
  end

  # ⚠️ Dos puertas a lo mismo es como se llegó a siete formas de título: el
  # botón de la cabecera se retiró al volverse pestaña.
  test "ya no hay botón de informes en la cabecera de calificar" do
    sign_in @a.profesor

    get section_path(@a.seccion, area: @a.escenario.materia.id)

    assert_response :success
    assert_select "a", { text: "Informes descriptivos", count: 0 },
                  "el botón se retiró: ahora es una pestaña"
    assert_select ".pestana", text: "Informes"
  end

  # ⚠️ Un profesor que NO es guía no ve la pestaña, igual que no entra a la
  # pantalla. Ofrecérsela y después negársela enseña a desconfiar del menú.
  test "el que no es guía no ve la pestaña" do
    otro = con_el_colegio(@a.colegio) do
      usuario = User.create!(first_name: "Otro", last_name: "Docente",
                             email: "otro.docente@bolivar.test", password: "123123")
      registro = Teacher.create!(user: usuario, school: @a.colegio)
      # ⚠️ OTRA materia: el par sección–materia es único, y la del escenario ya
      # la dicta el guía.
      otra = Subject.create!(department: @a.escenario.materia.department,
                             code: "LEN", name: "Castellano")
      GradeSubject.create!(grade: @a.grado, subject: otra)
      TeacherSection.create!(teacher: registro, section: @a.seccion, subject: otra)
      [ usuario, otra ]
    end
    usuario, area = otro
    sign_in usuario

    get section_path(@a.seccion, area: area.id)

    assert_response :success
    assert_select ".pestana", { text: "Informes", count: 0 }
  end

  test "el guía escribe el informe de un alumno y se guarda solo" do
    sign_in @a.profesor

    assert_difference "Current.sin_aislamiento { Informe.unscoped.count }", 1 do
      patch section_informe_path(@a.seccion, @a.escenario.inscripcion, lapso: @lapso.id),
            params: { cuerpo: "Luis mejoró mucho su lectura en voz alta este lapso." },
            as: :json
    end

    assert_response :success
    con_el_colegio(@a.colegio) do
      informe = Informe.para(@a.escenario.inscripcion.id, @lapso.id)
      assert_equal "Luis mejoró mucho su lectura en voz alta este lapso.", informe.cuerpo
      assert_equal @a.profesor.id, informe.escrito_por_id, "queda quién lo escribió"
    end
  end

  # ⚠️ Vaciar BORRA. El alumno vuelve a «sin informe», que no es un informe en
  # blanco: la boleta no tiene que imprimir un renglón vacío.
  test "vaciar el campo borra el informe" do
    con_el_colegio(@a.colegio) do
      Informe.create!(enrollment: @a.escenario.inscripcion, evaluation_moment: @lapso,
                      escrito_por: @a.profesor, cuerpo: "Algo escrito")
    end
    sign_in @a.profesor

    assert_difference "Current.sin_aislamiento { Informe.unscoped.count }", -1 do
      patch section_informe_path(@a.seccion, @a.escenario.inscripcion, lapso: @lapso.id),
            params: { cuerpo: "   " }, as: :json
    end
  end

  # ⚠️ UNO por alumno y lapso: dos pestañas abiertas no pueden escribir dos.
  test "escribir dos veces actualiza, no duplica" do
    sign_in @a.profesor

    2.times do |i|
      patch section_informe_path(@a.seccion, @a.escenario.inscripcion, lapso: @lapso.id),
            params: { cuerpo: "Versión #{i + 1}" }, as: :json
    end

    con_el_colegio(@a.colegio) do
      assert_equal 1, Informe.where(enrollment_id: @a.escenario.inscripcion.id).count
      assert_equal "Versión 2", Informe.para(@a.escenario.inscripcion.id, @lapso.id).cuerpo
    end
  end

  # ⚠️ Lo escribe el GUÍA, no cualquiera que dicte ahí. Es un juicio sobre el
  # alumno entero, y el profesor de Educación Física no lo tiene.
  test "un profesor que no es guía no entra" do
    otro = con_el_colegio(@a.colegio) do
      usuario = User.create!(first_name: "Otro", last_name: "Docente",
                             email: "otro.docente@informe.test", password: "123123",
                             document: "V-71000333", document_type: :cedula_v)
      docente = Teacher.create!(user: usuario, school: @a.colegio)
      # ⚠️ Otra MATERIA: la del escenario ya la dicta el profesor principal, y
      # `teacher_sections` es única por (sección, materia).
      otra = Subject.create!(department: @a.escenario.materia.department,
                             code: "EDF", name: "Educación Física")
      GradeSubject.create!(grade: @a.grado, subject: otra)
      TeacherSection.create!(teacher: docente, section: @a.seccion, subject: otra)
      usuario
    end
    sign_in otro

    get section_informes_path(@a.seccion)
    assert_response :redirect
  end

  # ⚠️ La dirección SÍ entra: una sección puede no tener guía —el cargo es
  # opcional— y sin esto esos alumnos se quedarían sin informe para siempre.
  test "la dirección entra aunque la sección no tenga guía" do
    con_el_colegio(@a.colegio) { @a.seccion.update!(leader_teacher: nil) }
    sign_in @a.director

    get section_informes_path(@a.seccion)

    assert_response :success
    assert_select ".informe-campo"
  end

  test "el informe de otro colegio no se toca" do
    sign_in @a.profesor

    patch section_informe_path(@b.seccion, @b.escenario.inscripcion, lapso: @b.escenario.lapso(1).id),
          params: { cuerpo: "Del colegio ajeno" }, as: :json

    assert_response :not_found
    assert_equal 0, Current.sin_aislamiento { Informe.unscoped.count }
  end

  # ⚠️ Un lapso de otro año escolar dejaría el informe colgando de una fecha que
  # no existe para ese alumno.
  test "no se escribe un informe en un lapso de otro año" do
    ajeno = con_el_colegio(@a.colegio) do
      periodo = AcademicPeriod.create!(name: "2024-2025", start_date: Date.new(2024, 9, 15),
                                       end_date: Date.new(2025, 7, 31))
      EvaluationMoment.create!(academic_period: periodo, name: "1er Lapso")
    end

    con_el_colegio(@a.colegio) do
      informe = Informe.new(enrollment: @a.escenario.inscripcion, evaluation_moment: ajeno,
                            escrito_por: @a.profesor, cuerpo: "De otro año")
      assert_not informe.valid?
      assert_includes informe.errors[:evaluation_moment].to_sentence, "año escolar"
    end
  end

  # ⚠️ El informe entra al SNAPSHOT: corregirlo después no cambia el papel que
  # la familia ya se llevó.
  test "el boletín congela el informe" do
    boletin = con_el_colegio(@a.colegio) do
      Informe.create!(enrollment: @a.escenario.inscripcion, evaluation_moment: @lapso,
                      escrito_por: @a.profesor, cuerpo: "Lo que se dijo en diciembre")

      ReportCard.create!(
        enrollment: @a.escenario.inscripcion, evaluation_moment: @lapso, issued_by: @a.director,
        snapshot: ReportCardData.para(enrollment: @a.escenario.inscripcion, evaluation_moment: @lapso)
      )
    end

    con_el_colegio(@a.colegio) do
      Informe.para(@a.escenario.inscripcion.id, @lapso.id).update!(cuerpo: "Corregido en marzo")

      assert_equal "Lo que se dijo en diciembre", boletin.reload.snapshot["informe"],
                   "el papel que la familia tiene en la mano no puede cambiar"
    end
  end

  # ⚠️ El ANUAL no lleva informe: habla «del lapso», y el anual cruza tres.
  test "el boletín anual no trae informe de lapso" do
    con_el_colegio(@a.colegio) do
      Informe.create!(enrollment: @a.escenario.inscripcion, evaluation_moment: @lapso,
                      escrito_por: @a.profesor, cuerpo: "Del primer lapso")

      datos = ReportCardData.para(enrollment: @a.escenario.inscripcion)
      assert_nil datos["informe"],
                 "el anual cruza tres lapsos: el informe de uno no lo describe"
    end
  end

  test "la familia lo lee en su portal" do
    representante = con_el_colegio(@a.colegio) do
      Informe.create!(enrollment: @a.escenario.inscripcion, evaluation_moment: @lapso,
                      escrito_por: @a.profesor, cuerpo: "Avanzó mucho en lectura este lapso.")

      usuario = User.create!(first_name: "Carmen", last_name: "López",
                             email: "carmen.informe@familia.test", password: "123123",
                             document: "V-71000444", document_type: :cedula_v)
      rep = Representative.create!(user: usuario, school: @a.colegio, phone: "0414-1112233")
      StudentRepresentative.create!(representative: rep, student: @a.escenario.alumno,
                                    parentesco: :madre, principal: true)
      usuario
    end
    sign_in representante

    get hijo_representante_path(@a.escenario.alumno, lapso: @lapso.id)

    assert_response :success
    assert_select ".informe-descriptivo-cuerpo", text: /Avanzó mucho en lectura/
  end
end
