require "test_helper"

# Qué materias vio un alumno ESE año, y no las de hoy (MOR-152).
#
# ## El error, en una frase
#
# `grade_subjects` une grado y materia **sin período**: un grado tiene un solo
# pensum para toda su historia. El colegio agrega Francés en 2026 y le aparece
# a un alumno que se graduó en 2021, en su boletín, como una materia más.
#
# ## La solución NO agregó una columna
#
# El dato que distingue un año de otro ya existía: **quién dicta qué**, que
# cuelga de la sección, que cuelga del período. Nadie lo estaba leyendo.
#
# ⚠️ Y por eso el boletín une DOS cosas. Derivando solo de quién dicta, todo
# boletín importado saldría vacío: `CargaDeHistorial` escribe notas y NO crea
# `teacher_sections` —no sabe quién dictó Biología en 2019—. Una nota es prueba
# de que esa materia se vio, así que también cuenta.
class MateriasDelPeriodoTest < ActiveSupport::TestCase
  setup do
    @esc = escenario_academico(nombre: "Colegio del Pensum")
    @viejo = ano_escolar_viejo(@esc, nombre: "2021-2022")
  end

  # El caso exacto de la carta: agregar una materia hoy no puede reescribir el
  # pasado.
  test "una materia agregada hoy NO aparece en el boletín de un año anterior" do
    seccion_vieja, inscripcion_vieja = con_el_colegio(@esc.colegio) do
      seccion = Section.find_by!(academic_period: @viejo)
      alumno = @esc.alumno
      inscripcion = Enrollment.create!(student: alumno, section: seccion,
                                       enrollment_date: Date.new(2021, 9, 20))
      # Lo que hace el importador de historial: la nota, y nada más.
      MomentGrade.create!(enrollment: inscripcion, subject: @esc.materia,
                          evaluation_moment: EvaluationMoment.find_by!(academic_period: @viejo, name: "Lapso 1"),
                          final_moment_score: 16, origen: :importada)
      [ seccion, inscripcion ]
    end

    frances = con_el_colegio(@esc.colegio) do
      materia = Subject.create!(department: @esc.materia.department, code: "FRA", name: "Francés")
      GradeSubject.create!(grade: @esc.grado, subject: materia)
      materia
    end

    con_el_colegio(@esc.colegio) do
      assert_includes @esc.grado.subjects, frances,
                      "el pensum del grado sí la tiene: es lo que hace peligroso leerlo"

      assert_not_includes inscripcion_vieja.materias_del_boletin, frances,
                          "Francés se agregó en 2026 y salió en el boletín de 2021: " \
                          "ese alumno nunca la vio"
      assert_not_includes seccion_vieja.materias_dictadas, frances
    end
  end

  # La otra mitad, que es la que se rompe si alguien «simplifica» esto.
  test "un boletín importado conserva sus materias aunque nadie las dicte" do
    con_el_colegio(@esc.colegio) do
      seccion = Section.find_by!(academic_period: @viejo)
      inscripcion = Enrollment.create!(student: @esc.alumno, section: seccion,
                                       enrollment_date: Date.new(2021, 9, 20))
      MomentGrade.create!(enrollment: inscripcion, subject: @esc.materia,
                          evaluation_moment: EvaluationMoment.find_by!(academic_period: @viejo, name: "Lapso 1"),
                          final_moment_score: 16, origen: :importada)

      assert_empty seccion.teacher_sections,
                   "el importador no crea asignaciones: si las creara, este test no probaría nada"

      assert_includes inscripcion.materias_del_boletin, @esc.materia,
                      "la materia tiene nota importada y desapareció del boletín: " \
                      "diez años de historial se verían en blanco"
    end
  end

  # Una materia sin profesor asignado igual se dicta si tiene evaluaciones: la
  # asignación puede llegar tarde y el alumno ya está siendo evaluado. Por eso
  # `materias_dictadas` mira las dos cosas y no solo `teacher_sections`.
  test "una materia con evaluaciones cuenta aunque no tenga profesor asignado" do
    con_el_colegio(@esc.colegio) do
      actividad(@esc, lapso: @esc.lapso(1), peso: 100)

      assert_empty TeacherSection.where(section: @esc.seccion, subject: @esc.materia),
                   "el escenario no asigna profesor: es justo el caso que se prueba"

      assert_includes @esc.seccion.materias_dictadas, @esc.materia
    end
  end

  test "una materia con profesor asignado cuenta aunque no haya evaluaciones todavía" do
    con_el_colegio(@esc.colegio) do
      persona = User.create!(first_name: "Profe", last_name: "DePensum",
                             email: "profe.pensum@aislamiento.test", password: "123123",
                             document: "V-55443322", document_type: :cedula_v)
      docente = Teacher.create!(user: persona, school: @esc.colegio)
      TeacherSection.create!(teacher: docente, section: @esc.seccion, subject: @esc.materia)

      assert_includes @esc.seccion.materias_dictadas, @esc.materia,
                      "en plena planificación el profesor ya está asignado y todavía no " \
                      "cargó ninguna evaluación: la materia se dicta igual"
    end
  end

  # ⚠️ Una sección sin profesor asignado y sin evaluaciones NO dicta nada, y eso
  # es correcto aunque suene raro: es una sección recién creada en la etapa de
  # planificación. Lo que no puede pasar es que herede el pensum histórico del
  # grado, que era el error.
  test "una sección recién creada no dicta nada todavía" do
    con_el_colegio(@esc.colegio) do
      assert_empty @esc.seccion.materias_dictadas
      assert_includes @esc.grado.subjects, @esc.materia,
                      "el grado sí la tiene: la diferencia entre las dos cosas es el bug"
    end
  end
end
