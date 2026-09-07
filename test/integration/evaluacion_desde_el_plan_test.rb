require "test_helper"

# Registrar una evaluación CON el contexto ya puesto (QA del 7 de septiembre).
#
# Daniel, marcando con una equis los dos primeros desplegables del formulario:
# *«vienen del enlace»* — *«este enlace puede llevar ya todas estas
# características, ¿para qué repedírselas al usuario si vengo de una
# especificación?»*.
#
# Es «no preguntemos lo deducible» en su forma más literal: quien llega desde el
# plan de «1er Grado B · Matemática · 1er Lapso» ya eligió las tres cosas.
# Repreguntárselas no es prudencia — es hacerle repetir, y darle la oportunidad
# de crear la evaluación en otra sección.
class EvaluacionDesdeElPlanTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos(nivel: :primaria)
    @asignacion = "#{@a.seccion.id}:#{@a.escenario.materia.id}"
    @lapso = @a.escenario.lapso(2)   # el 1 ya tiene una actividad de peso 100
    @competencia = con_el_colegio(@a.colegio) { competencia_con(1, lapso: @lapso) }
    sign_in @a.profesor
  end

  test "con el contexto en la URL, la sección y el lapso no se preguntan" do
    get new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id)

    # Se muestran, no se eligen.
    assert_select ".contexto-del-enlace", /#{@a.seccion.grade.name}/
    assert_select ".contexto-del-enlace", /#{@lapso.name}/
    assert_select "select[name='evaluation_activity[asignacion]']", count: 0
    assert_select "select[name='evaluation_activity[evaluation_moment_id]']", count: 0

    # Pero viajan igual, o el formulario no sabría qué está creando.
    assert_select "input[type=hidden][name='evaluation_activity[asignacion]'][value=?]", @asignacion
    assert_select "input[type=hidden][name='evaluation_activity[evaluation_moment_id]'][value=?]",
                  @lapso.id.to_s
  end

  # ⚠️ Mostrar el contexto no puede volverlo una jaula.
  test "hay una salida para cambiar de sección" do
    get new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id)

    assert_select "a.contexto-del-enlace-cambiar[href=?]", new_evaluation_activity_path
  end

  # Sin contexto en la URL, el formulario sigue siendo el de siempre.
  test "sin contexto, los desplegables siguen ahí" do
    get new_evaluation_activity_path

    assert_select ".contexto-del-enlace", count: 0
    assert_select "select[name='evaluation_activity[asignacion]']"
    assert_select "select[name='evaluation_activity[evaluation_moment_id]']"
  end

  # ⚠️ Quien llega desde «+ Registrar una evaluación» de UNA competencia viene a
  # medir ESA. Que llegue desmarcada le pide buscarla en una lista donde ya sabe
  # cuál es — y si se olvida, la evaluación no mide nada.
  test "la competencia del enlace llega marcada" do
    get new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id,
                                     competencia: @competencia.id)

    assert_select "form[data-que-evalua-marcadas-value=?]", [ @competencia.id ].to_json
  end

  # ── Lo que NO se acepta ────────────────────────────────────────────────────
  #
  # El contexto llega por la URL, así que es un parámetro: se valida como
  # cualquier otro y se busca ENTRE LAS ASIGNACIONES DE ESTE PROFESOR.

  test "la sección de otro profesor no se acepta: el formulario vuelve a preguntar" do
    ajena = "#{@b.seccion.id}:#{@b.escenario.materia.id}"

    get new_evaluation_activity_path(asignacion: ajena, lapso: @b.escenario.lapso(1).id)

    assert_response :success
    assert_select ".contexto-del-enlace", count: 0
    assert_select "select[name='evaluation_activity[asignacion]']"
  end

  # ⚠️ El lapso se valida contra el AÑO ESCOLAR de esa sección, no contra los
  # del colegio: un lapso de otro año sobre esta sección crearía una evaluación
  # que no existe para nadie.
  test "un lapso de otro año escolar no se acepta" do
    otro_anio = con_el_colegio(@a.colegio) do
      periodo = AcademicPeriod.create!(name: "2099-2100", start_date: Date.new(2099, 9, 1),
                                       end_date: Date.new(2100, 7, 31))
      EvaluationMoment.create!(academic_period: periodo, name: "1er Lapso",
                               starts_on: periodo.start_date, ends_on: periodo.end_date)
    end

    get new_evaluation_activity_path(asignacion: @asignacion, lapso: otro_anio.id)

    assert_response :success
    assert_select ".contexto-del-enlace", count: 0
  end

  # ⚠️ Y la competencia también se filtra contra el plan real: marcar la de otro
  # dejaría una evaluación midiendo algo que su sección no tiene.
  test "la competencia de otro no llega marcada" do
    ajena = con_el_colegio(@b.colegio) do
      Competency.create!(section: @b.seccion, subject: @b.escenario.materia,
                         evaluation_moment: @b.escenario.lapso(1), descripcion: "Ajena")
    end

    get new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id,
                                     competencia: ajena.id)

    assert_select "form[data-que-evalua-marcadas-value=?]", [].to_json
  end

  # ── Y de punta a punta ─────────────────────────────────────────────────────

  test "se crea la evaluación con el contexto que trajo el enlace" do
    get new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id,
                                     competencia: @competencia.id)

    assert_difference "con_el_colegio(@a.colegio) { EvaluationActivity.count }", 1 do
      post evaluation_activities_path, params: {
        evaluation_activity: {
          asignacion: @asignacion, evaluation_moment_id: @lapso.id,
          description: "Examen del plan", weight_percentage: 40,
          date_scheduled: Date.new(2025, 11, 10),
          competency_ids: [ @competencia.id ]
        }
      }
    end

    creada = con_el_colegio(@a.colegio) { EvaluationActivity.order(:id).last }
    assert_equal @a.seccion.id, creada.section_id
    assert_equal @lapso.id, creada.evaluation_moment_id
    assert_equal [ @competencia.id ], con_el_colegio(@a.colegio) { creada.competency_ids }
  end
end
