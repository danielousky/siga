require "test_helper"

# Dentro de un turbo_frame, TODO destino tiene que contener ese frame.
#
# ## Por qué existe este archivo
#
# Es la tercera vez que muerde lo mismo, y las tres veces el síntoma fue el
# mismo: la pantalla entera reemplazada por «Content missing».
#
#     1 · un enlace del plan que salía a otra pantalla   → `data-turbo-frame="_top"`
#     2 · `new` con el frame escrito a mano              → `frame_que_pregunta`
#     3 · el error de borrar redirigiendo al `show`      → volver al mismo sitio
#
# ⚠️ **Ninguna de las tres falla por ningún lado.** La petición devuelve 200, el
# HTML es válido, los tests de integración pasan en verde y el log no dice nada:
# Turbo pide un frame, la respuesta no lo trae, y escribe el hueco. Se ve
# mirando, y solo si alguien mira esa pantalla.
#
# Por eso la guarda pide como pide Turbo —con el encabezado `Turbo-Frame`— y
# sigue los redirects hasta el final, que es donde el frame tiene que aparecer.
class ElFrameSobreviveTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)
    @asignacion = "#{@a.seccion.id}:#{@a.escenario.materia.id}"
    @contexto = { asignacion: @asignacion, lapso: @lapso.id }
    sign_in @a.profesor
  end

  # Pide como pide Turbo, sigue los redirects, y exige el frame al final.
  def dentro_del_frame(frame, verbo, ruta, **opciones)
    send(verbo, ruta, headers: { "Turbo-Frame" => frame }, **opciones)
    follow_redirect! while response.redirect?

    assert_select "turbo-frame##{frame}", { minimum: 1 },
      "#{verbo.to_s.upcase} #{ruta} contestó sin el frame «#{frame}»: Turbo escribe " \
      "«Content missing» y se lleva la pantalla entera, sin error en ningún lado"
  end

  test "abrir el formulario de una evaluación, desde los dos lados" do
    dentro_del_frame "plan",    :get, new_evaluation_activity_path(**@contexto)
    dentro_del_frame "libreta", :get, new_evaluation_activity_path(**@contexto)
  end

  test "editar una evaluación, desde los dos lados" do
    evaluacion = con_el_colegio(@a.colegio) { actividad(@a.escenario, lapso: @lapso, peso: 40) }

    dentro_del_frame "plan",    :get, edit_evaluation_activity_path(evaluacion, **@contexto)
    dentro_del_frame "libreta", :get, edit_evaluation_activity_path(evaluacion, **@contexto)
  end

  # ⚠️ El caso que reportó Daniel: con notas cargadas el borrado se RECHAZA, y
  # el error se iba a una pantalla sin el frame.
  test "borrar una evaluación que NO se puede borrar" do
    evaluacion = con_el_colegio(@a.colegio) do
      e = actividad(@a.escenario, lapso: @lapso, peso: 40)
      ActivityGrade.create!(evaluation_activity: e, student: @a.seccion.enrollments.first.student, score: 15)
      e
    end

    dentro_del_frame "plan", :delete, evaluation_activity_path(evaluacion, **@contexto)
    assert EvaluationActivity.exists?(evaluacion.id), "no se borra: tiene notas"
  end

  test "borrar una evaluación que sí se puede borrar" do
    evaluacion = con_el_colegio(@a.colegio) { actividad(@a.escenario, lapso: @lapso, peso: 40) }

    dentro_del_frame "plan", :delete, evaluation_activity_path(evaluacion, **@contexto)
  end

  test "crear una evaluación, y también cuando el formulario se rechaza" do
    dentro_del_frame "plan", :post, evaluation_activities_path,
      params: { evaluation_activity: { asignacion: @asignacion, evaluation_moment_id: @lapso.id,
                                       description: "Taller", weight_percentage: 30,
                                       date_scheduled: Date.current } }

    # Sin descripción: el formulario vuelve con sus errores, dentro del frame.
    dentro_del_frame "plan", :post, evaluation_activities_path,
      params: { evaluation_activity: { asignacion: @asignacion, evaluation_moment_id: @lapso.id,
                                       description: "", weight_percentage: 10 } }
  end

  test "las competencias: alta, edición, borrado y el traer del año pasado" do
    competencia = con_el_colegio(@a.colegio) { competencia_con(1, lapso: @lapso) }

    dentro_del_frame "plan", :get,    new_competency_path(**@contexto)
    dentro_del_frame "plan", :get,    edit_competency_path(competencia, **@contexto)
    dentro_del_frame "plan", :patch,  competency_path(competencia, **@contexto),
      params: { competency: { descripcion: "Otra cosa distinta" } }
    dentro_del_frame "plan", :post,   traer_competencies_path(**@contexto)
    dentro_del_frame "plan", :delete, competency_path(competencia, **@contexto)
  end

  # Enganchar y desenganchar evaluaciones también contesta dentro del plan.
  test "conectar evaluaciones a una competencia" do
    competencia = con_el_colegio(@a.colegio) { competencia_con(1, lapso: @lapso) }
    evaluacion  = con_el_colegio(@a.colegio) { actividad(@a.escenario, lapso: @lapso, peso: 40) }

    dentro_del_frame "plan", :patch,
      competency_conectar_evaluaciones_path(competencia, **@contexto),
      params: { evaluation_activity_ids: [ evaluacion.id ] }
  end
end
