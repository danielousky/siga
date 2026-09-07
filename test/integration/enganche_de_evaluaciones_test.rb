require "test_helper"

# Conectar una competencia con las evaluaciones que la miden (MOR-136).
#
# ## El enganche existía y no se descubría
#
# Al crear una evaluación se marca qué evalúa, y eso está desde el principio.
# Pero solo funciona en esa dirección, y **el orden real del trabajo es el
# contrario**: el profesor escribe su plan, arma sus evaluaciones, y si se
# olvidó de marcar no tenía forma de arreglarlo salvo editando una por una —sin
# saber siquiera cuáles le faltaban.
#
# Daniel: *«no sé cómo asociamos las evaluaciones con los indicadores. RECUERDA
# UX, debe ser un proceso fácil y fluido»*.
class EngancheDeEvaluacionesTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos(nivel: :primaria)
    @asignacion = "#{@a.seccion.id}:#{@a.escenario.materia.id}"
    @lapso = @a.escenario.lapso(2)   # el 1 ya tiene una actividad de peso 100
    @competencia = con_el_colegio(@a.colegio) { competencia_con(1, lapso: @lapso) }
  end

  test "el plan dice qué evaluaciones miden cada competencia" do
    con_el_colegio(@a.colegio) do
      examen = actividad(@a.escenario, lapso: @lapso, peso: 60, descripcion: "Examen")
      ActivityCompetency.create!(competency: @competencia, evaluation_activity: examen)
    end
    sign_in @a.profesor

    get competencies_path(asignacion: @asignacion, lapso: @lapso.id)

    assert_select ".plan-medida-chip", /Examen/
    assert_select ".plan-medida-vacio", count: 0
  end

  # ⚠️ «Ninguna todavía» y no un hueco: una competencia que no mide ninguna
  # evaluación sale en la boleta SIN nivel, y eso hay que verlo ANTES de
  # emitirla — no descubrirlo cuando la familia pregunta.
  test "una competencia sin evaluaciones lo dice, no lo calla" do
    con_el_colegio(@a.colegio) { actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Suelta") }
    sign_in @a.profesor

    get competencies_path(asignacion: @asignacion, lapso: @lapso.id)

    assert_select ".plan-medida-vacio", text: /Ninguna evaluación todavía/
  end

  test "conectar una evaluación desde el plan" do
    examen = con_el_colegio(@a.colegio) do
      actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Examen")
    end
    sign_in @a.profesor

    assert_difference "Current.sin_aislamiento { ActivityCompetency.unscoped.count }", 1 do
      patch competency_conectar_evaluaciones_path(@competencia, asignacion: @asignacion, lapso: @lapso.id),
            params: { evaluation_activity_ids: [ examen.id ] }
    end

    assert_redirected_to competencies_path(asignacion: @asignacion, lapso: @lapso.id)
    con_el_colegio(@a.colegio) do
      assert_equal [ examen.id ], @competencia.reload.evaluation_activity_ids
    end
  end

  # ⚠️ REEMPLAZA, no suma: la persona ve todas las casillas, así que desmarcar
  # tiene que quitar. Es lo mismo que hacen los indicadores al editar.
  test "desconectar todas deja la competencia sin evaluaciones" do
    con_el_colegio(@a.colegio) do
      examen = actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Examen")
      ActivityCompetency.create!(competency: @competencia, evaluation_activity: examen)
    end
    sign_in @a.profesor

    # El campo vacío es lo que manda el formulario cuando no hay ninguna
    # marcada: sin él, Rails no distingue «ninguna» de «no me preguntes».
    patch competency_conectar_evaluaciones_path(@competencia, asignacion: @asignacion, lapso: @lapso.id),
          params: { evaluation_activity_ids: [ "" ] }

    con_el_colegio(@a.colegio) do
      assert_empty @competencia.reload.evaluation_activity_ids
    end
  end

  # ⚠️ Solo las evaluaciones del MISMO plan: misma sección, misma área, mismo
  # lapso. Lo cruzado no da error, no se ve, y aparece meses después en una
  # boleta diciendo algo que nadie escribió ahí.
  test "no se puede conectar una evaluación de otro lapso" do
    de_otro_lapso = con_el_colegio(@a.colegio) do
      actividad(@a.escenario, lapso: @a.escenario.lapso(3), peso: 100, descripcion: "De otro lapso")
    end
    sign_in @a.profesor

    patch competency_conectar_evaluaciones_path(@competencia, asignacion: @asignacion, lapso: @lapso.id),
          params: { evaluation_activity_ids: [ de_otro_lapso.id ] }

    con_el_colegio(@a.colegio) do
      assert_empty @competencia.reload.evaluation_activity_ids
    end
  end

  test "ni una de otro colegio" do
    ajena = con_el_colegio(@b.colegio) { @b.actividad }
    sign_in @a.profesor

    patch competency_conectar_evaluaciones_path(@competencia, asignacion: @asignacion, lapso: @lapso.id),
          params: { evaluation_activity_ids: [ ajena.id ] }

    con_el_colegio(@a.colegio) { assert_empty @competencia.reload.evaluation_activity_ids }
  end

  # ⚠️ Sin evaluaciones en el lapso no hay nada que conectar, y un panel vacío
  # no explica nada: se dice qué falta y se ofrece el camino.
  test "sin evaluaciones en el lapso, se ofrece crear una" do
    sign_in @a.profesor
    get competencies_path(asignacion: @asignacion, lapso: @lapso.id)

    assert_select ".plan-conectar-panel", count: 0
    assert_select "a[href=?]", new_evaluation_activity_path
  end

  # La competencia de otro profesor no se toca: `set_competency` la busca
  # dentro de su alcance, así que pedirla por id da 404 y no 403.
  test "no se conecta la competencia de otro colegio" do
    ajena = con_el_colegio(@b.colegio) do
      Competency.create!(section: @b.seccion, subject: @b.escenario.materia,
                         evaluation_moment: @b.escenario.lapso(1), descripcion: "Del colegio B")
    end
    sign_in @a.profesor

    patch competency_conectar_evaluaciones_path(ajena, asignacion: @asignacion, lapso: @lapso.id),
          params: { evaluation_activity_ids: [] }

    assert_response :not_found
  end

  # ── La otra mitad: desde la libreta ────────────────────────────────────────
  #
  # ⚠️ La libreta era la única pantalla del profesor donde el plan no existía —
  # y es la que más mira. Ahora cada columna dice cuántas competencias mide.
  test "la libreta dice qué mide cada evaluación" do
    con_el_colegio(@a.colegio) do
      examen = actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Examen")
      ActivityCompetency.create!(competency: @competencia, evaluation_activity: examen)
      @a.seccion.update!(leader_teacher: @a.registro_de_profesor)
    end
    sign_in @a.profesor

    get section_path(@a.seccion, lapso: @lapso.id)

    assert_select ".libreta-columna-mide", text: /Mide 1/
    assert_select ".libreta-columna-mide[data-tooltip=?]", @competencia.descripcion
  end

  # Una evaluación que no mide ninguna competencia no lleva el indicador: un
  # «0» ahí sería ruido en todas las columnas de un colegio sin plan.
  test "sin competencias, la columna no muestra nada" do
    con_el_colegio(@a.colegio) do
      actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Suelta")
      @a.seccion.update!(leader_teacher: @a.registro_de_profesor)
    end
    sign_in @a.profesor

    get section_path(@a.seccion, lapso: @lapso.id)

    assert_select ".libreta-columna-nombre", /Suelta/
    assert_select ".libreta-columna-mide", count: 0
  end
end
