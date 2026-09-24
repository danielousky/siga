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

  # ⚠️ El INDICADOR dejó de exigirse el 23 de septiembre, y la competencia no.
  #
  # Daniel: *«si necesitas la evaluación para luego asociar los indicadores,
  # entonces pon solo el form de la eva y luego agregas sobre el guardado la
  # posibilidad de agregar indicadores»*. Exigirlo al crear obligaba a pedirlo
  # en un formulario aparte —un textarea de «uno por línea»— que era una segunda
  # manera de escribir lo que la fila del plan ya edita uno por uno.
  test "una evaluación de primaria no se crea sin competencia" do
    con_el_colegio(@a.colegio) do
      sin_nada = EvaluationActivity.new(section: @a.seccion, subject: @a.escenario.materia,
                                        evaluation_moment: @lapso, description: "Suelta",
                                        weight_percentage: 10, date_scheduled: Date.new(2025, 11, 5))

      assert_not sin_nada.valid?
      assert_match(/competencia que mide/, sin_nada.errors.full_messages.to_sentence)
    end
  end

  # ⚠️ Y SIN indicadores sí se crea: se le agregan después, en su fila.
  test "una evaluación nace sin indicadores, y se le agregan después" do
    con_el_colegio(@a.colegio) do
      nueva = EvaluationActivity.new(section: @a.seccion, subject: @a.escenario.materia,
                                     evaluation_moment: @lapso, description: "Examen",
                                     weight_percentage: 10, date_scheduled: Date.new(2025, 11, 5))
      nueva.competency_ids = [ @competencia.id ]

      assert nueva.save, nueva.errors.full_messages.to_sentence
      assert_empty nueva.indicators, "nace sin ninguno, que es el orden del trabajo"
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

  # ⚠️ Borrar la evaluación se lleva SUS indicadores, y es un cambio del 22 de
  # septiembre.
  #
  # Salió con `nullify` —«el texto lo escribió la maestra»— y Daniel lo
  # revirtió: *«no me parece que los indicadores queden sueltos; se le puede
  # indicar al usuario que al eliminar las evaluaciones se van los indicadores
  # respectivos»*. Es lo coherente con la jerarquía: uno suelto no se imprime en
  # la boleta ni se ve en el plan, o sea que «conservarlo» era guardar un dato
  # que nadie iba a volver a encontrar.
  test "borrar la evaluación se lleva sus indicadores" do
    con_el_colegio(@a.colegio) do
      examen = actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen",
                         mide: @competencia)
      suyo = examen.indicators.first.id

      examen.destroy

      assert_not Indicator.exists?(suyo), "el indicador de la evaluación se va con ella"
      assert_equal 2, @competencia.indicators.reload.count, "los otros dos no se tocan"
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

  # ⚠️ LOS TRES TESTS DEL PANEL DE ALTA se retiraron el 23 de septiembre.
  #
  # Probaban un formulario que ya no existe: el alta ofrecía los indicadores
  # libres con casilla, los tomados tachados, y un textarea de «uno por línea».
  # Daniel: *«¿te parece bien que haya 2 maneras distintas de hacer lo mismo?…
  # me apunto más porque el crear la evaluación sea como el de editarla»*.
  #
  # Ahora el alta es la MISMA fila de la edición, sin indicadores —la evaluación
  # todavía no existe— y se le agregan después con `IndicatorsController`, que
  # es lo que prueba `indicadores_test`.

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

    # ⚠️ Los otros dos NO se dibujan: no los mide ninguna evaluación, y desde
    # esta jerarquía el único sitio donde un indicador se ve es dentro de la
    # suya. Que existan es un dato viejo —ninguna pantalla los crea— y por eso
    # el bloque que los mostraba se retiró.
    assert_select ".plan-evaluacion-mide .plan-indicador-texto", 2,
                  "solo el que mide, más el campo vacío"
  end
end
