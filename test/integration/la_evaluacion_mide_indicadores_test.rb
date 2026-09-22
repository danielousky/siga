require "test_helper"

# Qué INDICADORES mide una evaluación (MOR-136, segunda mitad).
#
# ## De dónde sale
#
# Daniel: *«la idea es que la profesora, a una nueva evaluación, pueda asignarle
# competencias ya creadas y a su vez agregar también otros indicadores»*. Y
# después, la frase que decide la forma del modelo:
#
#   > *«los indicadores no se repiten entre evaluaciones»*
#
# Por eso es una COLUMNA en `indicators` y no una tabla intermedia: si un
# indicador lo mide una sola evaluación, la relación es 1:N.
#
#     Resuelve problemas de adición
#       ∘ Suma con reagrupación      ──►  Examen del lapso   40 %
#       ∘ Estima antes de calcular   ──►  Examen del lapso
#       ∘ Resuelve en dos pasos      ──►  Taller en equipo   30 %
#       ∘ Compara dos estrategias    ──►  libre
#
# La competencia se repite entre evaluaciones; el indicador la REPARTE.
class LaEvaluacionMideIndicadoresTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos(nivel: :primaria)
    @asignacion = "#{@a.seccion.id}:#{@a.escenario.materia.id}"
    # ⚠️ El SEGUNDO lapso: el escenario ya gastó el 100 % del primero.
    @lapso = @a.escenario.lapso(2)
    @competencia = con_el_colegio(@a.colegio) { competencia_con(3, lapso: @lapso) }
  end

  # ── La regla, en el modelo ────────────────────────────────────────────────

  test "una evaluación de primaria no se crea sin competencia ni indicador" do
    con_el_colegio(@a.colegio) do
      sin_nada = EvaluationActivity.new(section: @a.seccion, subject: @a.escenario.materia,
                                        evaluation_moment: @lapso, description: "Suelta",
                                        weight_percentage: 10, date_scheduled: Date.new(2025, 11, 5))

      assert_not sin_nada.valid?
      assert_match(/competencia que mide/, sin_nada.errors.full_messages.to_sentence)
      assert_match(/al menos un indicador/, sin_nada.errors.full_messages.to_sentence)
    end
  end

  # ⚠️ En bachillerato NO hay plan por competencias, así que la regla no aplica.
  # Sin esta guarda, la validación dejaría a todos sus profesores sin poder
  # crear una evaluación — la misma trampa que `Grade#por_competencias?` existe
  # para evitar.
  test "en bachillerato la evaluación no mide competencias, y eso está bien" do
    media, = dos_colegios_completos(nivel: :secundaria)

    con_el_colegio(media.colegio) do
      suelta = EvaluationActivity.new(section: media.seccion, subject: media.escenario.materia,
                                      evaluation_moment: media.lapso(2), description: "Examen",
                                      weight_percentage: 100, date_scheduled: Date.new(2025, 11, 5))
      assert suelta.valid?, suelta.errors.full_messages.to_sentence
    end
  end

  # ⚠️ Un indicador no se reparte entre dos evaluaciones: la columna guarda UNA.
  test "el indicador que una evaluación mide deja de estar libre" do
    con_el_colegio(@a.colegio) do
      primero = @competencia.indicators.first
      actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen", mide: @competencia)

      assert_equal 2, @competencia.indicators.reload.libres.count
      assert_not_includes @competencia.indicators.libres, primero.reload
      assert_equal "Examen", primero.evaluation_activity.description
    end
  end

  # ⚠️ Borrar la evaluación SUELTA sus indicadores, no se los lleva. El texto lo
  # escribió la maestra en el plan; la evaluación solo decía cuál medía.
  test "borrar la evaluación devuelve sus indicadores al plan" do
    con_el_colegio(@a.colegio) do
      examen = actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen",
                         mide: @competencia)
      assert_equal 2, @competencia.indicators.reload.libres.count

      examen.destroy

      assert_equal 3, @competencia.indicators.reload.count, "se borró un indicador del plan"
      assert_equal 3, @competencia.indicators.libres.count
    end
  end

  # ⚠️ La boleta imprimiría un indicador bajo una competencia que esa evaluación
  # nunca midió. Es el gemelo de `ActivityCompetency#la_competencia_es_del_mismo_plan`,
  # un escalón más adentro.
  test "un indicador de una competencia que no mide se rechaza" do
    con_el_colegio(@a.colegio) do
      otra = competencia_con(1, "Interpreta gráficos", lapso: @lapso)
      examen = actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen",
                         mide: @competencia)

      intruso = otra.indicators.first
      intruso.evaluation_activity = examen

      assert_not intruso.valid?
      assert_match(/competencia que esa evaluación no mide/, intruso.errors.full_messages.to_sentence)
    end
  end

  # ── El alta, desde el plan ────────────────────────────────────────────────

  test "el alta ofrece los indicadores libres y nombra a quien tiene los demás" do
    con_el_colegio(@a.colegio) do
      actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen", mide: @competencia)
    end
    sign_in @a.profesor

    # ⚠️ En el frame del PLAN: el alta se despliega bajo el botón de la
    # competencia, y ese frame es el que trae el panel corto. Sin la cabecera,
    # `new` devuelve el formulario completo, que es otra pantalla.
    get new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id,
                                     competencia: @competencia.id),
        headers: { "Turbo-Frame" => "alta_evaluacion_#{@competencia.id}" }

    assert_response :success
    # Los dos que quedan libres se pueden marcar…
    assert_select "input[name=?][type=checkbox]", "evaluation_activity[indicator_ids][]", 2
    # …y el que ya mide el examen se ve, sin casilla y diciendo quién.
    assert_select ".alta-mide-tomados li", 1
    assert_select ".alta-mide-quien", /lo mide «Examen»/
    # Y siempre hay dónde escribir otros.
    assert_select "textarea[name=?]", "evaluation_activity[indicadores_nuevos][#{@competencia.id}]"
  end

  test "crear la evaluación con los indicadores marcados los deja midiéndolos" do
    libres = con_el_colegio(@a.colegio) { @competencia.indicators.libres.pluck(:id).first(2) }
    sign_in @a.profesor

    post evaluation_activities_path(asignacion: @asignacion, lapso: @lapso.id), params: {
      evaluation_activity: {
        asignacion: @asignacion, evaluation_moment_id: @lapso.id,
        description: "Taller en equipo", weight_percentage: 30,
        date_scheduled: Date.new(2025, 11, 12),
        competency_ids: [ @competencia.id ], indicator_ids: libres
      }
    }

    con_el_colegio(@a.colegio) do
      taller = EvaluationActivity.find_by(description: "Taller en equipo")
      assert_equal libres.sort, taller.indicator_ids.sort
      assert_equal 1, @competencia.indicators.reload.libres.count, "el tercero sigue libre"
    end
  end

  # ⚠️ Nacen en la COMPETENCIA, no en la evaluación: quedan en el plan y la
  # próxima evaluación los ve en la lista. Si colgaran de la evaluación habría
  # que reescribirlos en cada una, que es el trabajo que MOR-136 vino a quitar.
  test "los indicadores escritos en el alta quedan en la competencia" do
    sign_in @a.profesor

    assert_difference -> { cantidad(Indicator) }, 2 do
      post evaluation_activities_path(asignacion: @asignacion, lapso: @lapso.id), params: {
        evaluation_activity: {
          asignacion: @asignacion, evaluation_moment_id: @lapso.id,
          description: "Taller", weight_percentage: 30, date_scheduled: Date.new(2025, 11, 12),
          competency_ids: [ @competencia.id ],
          indicadores_nuevos: { @competencia.id.to_s => "Resuelve en dos pasos\n\nCompara dos estrategias" }
        }
      }
    end

    con_el_colegio(@a.colegio) do
      taller = EvaluationActivity.find_by(description: "Taller")
      assert_equal [ "Resuelve en dos pasos", "Compara dos estrategias" ],
                   taller.indicators.order(:orden).map(&:descripcion)
      assert_equal @competencia.id, taller.indicators.first.competency_id,
                   "el indicador cuelga de la competencia, no de la evaluación"
      assert_equal 5, @competencia.indicators.reload.count, "los tres de antes siguen ahí"
    end
  end

  # ⚠️ Tomar uno que otra ya mide se lo QUITARÍA, y callado: la columna admite
  # un solo dueño y el último gana. El filtro es una lista que no incluye lo
  # ajeno, como el de las competencias.
  test "no se puede robar el indicador que otra evaluación mide" do
    tomado = con_el_colegio(@a.colegio) do
      examen = actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen",
                         mide: @competencia)
      examen.indicators.first
    end
    sign_in @a.profesor

    post evaluation_activities_path(asignacion: @asignacion, lapso: @lapso.id), params: {
      evaluation_activity: {
        asignacion: @asignacion, evaluation_moment_id: @lapso.id,
        description: "Taller", weight_percentage: 30, date_scheduled: Date.new(2025, 11, 12),
        competency_ids: [ @competencia.id ],
        indicator_ids: [ tomado.id ] + con_el_colegio(@a.colegio) { @competencia.indicators.libres.pluck(:id).first(1) }
      }
    }

    con_el_colegio(@a.colegio) do
      assert_equal "Examen", tomado.reload.evaluation_activity.description,
                   "el indicador cambió de dueño sin que nadie lo pidiera"
    end
  end

  # ── Y se VE en el plan ────────────────────────────────────────────────────

  # ⚠️ Los indicadores se DIBUJAN DENTRO de su evaluación (21 de septiembre).
  #
  # Daniel: *«los componentes, luego evaluaciones dentro del componente
  # respectivo, y finalmente los indicadores sobre cada evaluación»*. Antes
  # colgaban de la competencia y decían al margen qué evaluación los medía; con
  # la jerarquía puesta ese renglón sobra —la posición ya lo dice— y `.plan-
  # indicador-mide` se retiró con él.
  test "el plan dibuja los indicadores DENTRO de su evaluación" do
    con_el_colegio(@a.colegio) do
      actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen", mide: @competencia)
    end
    sign_in @a.profesor

    get planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)

    assert_response :success
    # El bloque cuelga de la evaluación, y el indicador que mide va adentro.
    assert_select ".plan-evaluacion .plan-evaluacion-mide .plan-indicador", 2,
                  "el que mide, más el campo vacío para escribir el siguiente"
    assert_select ".plan-evaluacion-mide .plan-rotulo--indicadores", "Indicadores que mide"
    # ⚠️ Y el campo nuevo manda la EVALUACIÓN: es lo que impide que nazca suelto.
    assert_select "form[action*=?]", "evaluacion=", true,
                  "el alta del indicador tiene que llevar su evaluación"

    # Los otros dos quedaron sueltos: el bloque ámbar los hace visibles, porque
    # no salen en la boleta y sin él no se verían en ninguna parte.
    assert_select ".plan-indicadores--huerfanos .plan-indicador", 2
  end
end
