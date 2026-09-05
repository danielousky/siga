require "test_helper"

# Qué evalúa una evaluación (MOR-136).
#
# El enganche entre el PLAN y la NOTA. Es lo único que hace falta para que la
# boleta pueda decir «Resuelve situaciones con fracciones… PA» en vez de un 17
# pelado — y lo que se rompe en silencio es lo cruzado: etiquetar una prueba de
# Matemática con una competencia de Castellano no da error, no se ve en ninguna
# pantalla, y aparece meses después en una boleta.
class EtiquetarLaEvaluacionTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos(nivel: :primaria)
    @asignacion = "#{@a.seccion.id}:#{@a.escenario.materia.id}"
    @lapso = @a.escenario.lapso(1)
  end

  # ⚠️ En el LAPSO 2: el escenario ya trae una actividad de peso 100 en el
  # primero, y cualquier otra choca contra la validación de ponderación.
  test "crear una evaluación con lo que evalúa la deja etiquetada" do
    segundo = @a.escenario.lapso(2)
    competencia = con_el_colegio(@a.colegio) { competencia_con(2, lapso: segundo) }
    sign_in @a.profesor

    assert_difference "Current.sin_aislamiento { ActivityCompetency.unscoped.count }", 1 do
      post evaluation_activities_path, params: {
        evaluation_activity: {
          asignacion: @asignacion, evaluation_moment_id: segundo.id,
          description: "Prueba de fracciones", weight_percentage: 20,
          date_scheduled: Date.new(2025, 11, 5),
          competency_ids: [ competencia.id ]
        }
      }
    end

    con_el_colegio(@a.colegio) do
      assert_equal [ competencia.id ], EvaluationActivity.order(:id).last.competency_ids
    end
  end

  # ⚠️ Editar REEMPLAZA lo marcado, no lo suma: el profesor ve la lista completa
  # con lo suyo marcado, así que desmarcar tiene que quitar.
  test "editar reemplaza lo que evalúa" do
    una, otra = con_el_colegio(@a.colegio) { [ competencia_con(1), competencia_con(0, "Otra competencia") ] }
    sign_in @a.profesor

    patch evaluation_activity_path(@a.actividad), params: {
      evaluation_activity: {
        asignacion: @asignacion, evaluation_moment_id: @a.actividad.evaluation_moment_id,
        description: @a.actividad.description, weight_percentage: @a.actividad.weight_percentage,
        date_scheduled: @a.actividad.date_scheduled,
        competency_ids: [ una.id ]
      }
    }
    con_el_colegio(@a.colegio) { assert_equal [ una.id ], @a.actividad.reload.competency_ids }

    patch evaluation_activity_path(@a.actividad), params: {
      evaluation_activity: {
        asignacion: @asignacion, evaluation_moment_id: @a.actividad.evaluation_moment_id,
        description: @a.actividad.description, weight_percentage: @a.actividad.weight_percentage,
        date_scheduled: @a.actividad.date_scheduled,
        competency_ids: [ otra.id ]
      }
    }
    con_el_colegio(@a.colegio) do
      assert_equal [ otra.id ], @a.actividad.reload.competency_ids,
                   "desmarcar tiene que quitar la etiqueta, no dejarla puesta"
    end
  end

  # ⚠️ Lo que aparece meses después en una boleta diciendo algo que nadie
  # escribió ahí.
  test "una competencia de otro colegio no se puede etiquetar" do
    ajena = con_el_colegio(@b.colegio) do
      Competency.create!(section: @b.seccion, subject: @b.escenario.materia,
                         evaluation_moment: @b.escenario.lapso(1), descripcion: "Del colegio B")
    end
    sign_in @a.profesor

    assert_no_difference "Current.sin_aislamiento { ActivityCompetency.unscoped.count }" do
      patch evaluation_activity_path(@a.actividad), params: {
        evaluation_activity: {
          asignacion: @asignacion, evaluation_moment_id: @a.actividad.evaluation_moment_id,
          description: @a.actividad.description, weight_percentage: @a.actividad.weight_percentage,
          date_scheduled: @a.actividad.date_scheduled,
          competency_ids: [ ajena.id ]
        }
      }
    end
  end

  # Del mismo colegio pero de OTRO lapso: el modelo lo valida, y el controller
  # ni siquiera se lo ofrece.
  test "una competencia de otro lapso no se puede etiquetar" do
    de_otro_lapso = con_el_colegio(@a.colegio) do
      Competency.create!(section: @a.seccion, subject: @a.escenario.materia,
                         evaluation_moment: @a.escenario.lapso(2), descripcion: "Del segundo lapso")
    end
    sign_in @a.profesor

    patch evaluation_activity_path(@a.actividad), params: {
      evaluation_activity: {
        asignacion: @asignacion, evaluation_moment_id: @a.actividad.evaluation_moment_id,
        description: @a.actividad.description, weight_percentage: @a.actividad.weight_percentage,
        date_scheduled: @a.actividad.date_scheduled,
        competency_ids: [ de_otro_lapso.id ]
      }
    }

    con_el_colegio(@a.colegio) do
      assert_empty @a.actividad.reload.competency_ids,
                   "el plan del segundo lapso no puede etiquetar una evaluación del primero"
    end
  end

  # ⚠️ El formulario de un profesor de BACHILLERATO no trae el bloque: no hay
  # plan por competencias que ofrecerle.
  test "el formulario de bachillerato no ofrece competencias" do
    media, = dos_colegios_completos(nivel: :secundaria)
    sign_in media.profesor

    get new_evaluation_activity_path

    assert_response :success
    assert_select ".que-evalua", count: 0
  end

  test "el formulario de primaria trae el plan embebido" do
    con_el_colegio(@a.colegio) { competencia_con(1) }
    sign_in @a.profesor

    get new_evaluation_activity_path

    assert_select "form[data-que-evalua-planes-value]" do |formularios|
      planes = JSON.parse(formularios.first["data-que-evalua-planes-value"])
      clave = "#{@a.seccion.id}:#{@a.escenario.materia.id}:#{@lapso.id}"
      assert planes.key?(clave), "el plan de la sección tiene que viajar en el formulario"
      assert_equal 1, planes[clave].size
    end
  end

  # ⚠️ Borrar la evaluación se lleva sus etiquetas —son una relación, no un dato
  # de nadie— pero NO se puede borrar una evaluación con notas.
  test "borrar la evaluación se lleva sus etiquetas" do
    segundo = @a.escenario.lapso(2)
    sin_notas = con_el_colegio(@a.colegio) do
      competencia = competencia_con(0, lapso: segundo)
      actividad = EvaluationActivity.create!(
        section: @a.seccion, subject: @a.escenario.materia, evaluation_moment: segundo,
        description: "Sin notas", weight_percentage: 5, date_scheduled: Date.new(2025, 11, 6)
      )
      ActivityCompetency.create!(competency: competencia, evaluation_activity: actividad)
      actividad
    end
    sign_in @a.profesor

    assert_difference "Current.sin_aislamiento { ActivityCompetency.unscoped.count }", -1 do
      delete evaluation_activity_path(sin_notas)
    end
  end
end
