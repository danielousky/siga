require "test_helper"

# En Educación Media, «Planificar» es la MISMA pantalla sin competencias.
#
# Decía «las competencias son de primaria, lo tuyo se arma en Calificar» y
# mandaba allá — donde el botón de alta se retiró el 10 de septiembre, a pedido
# de Daniel: *«este botón no va, ya quedaría todo en la pestaña de
# planificación»*. Las dos pestañas se mandaban la una a la otra, y un profesor
# de bachillerato no tenía NINGUNA forma de crear una evaluación.
#
# ⚠️ Y el mensaje era falso de por sí: en Media hay plan de evaluación —las
# evaluaciones, su peso y su fecha, el 70/30 del Artículo 111— y es justamente
# lo que esa pantalla arma. Lo único que no hay son competencias.
class PlanDeMediaTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :secundaria)
    @lapso = @a.escenario.lapso(2)   # el 1 ya trae el 100 % repartido
    sign_in @a.profesor
  end

  def plan
    get planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
  end

  test "la pestaña ya no rebota a Calificar" do
    plan

    assert_response :success
    assert_no_match(/competencias son de primaria/, response.body)
    assert_select "a", { text: "Ir a calificar", count: 0 },
                  "las dos pestañas se mandaban la una a la otra"
    # Y el vacío enseña por dónde empezar EN MEDIA: por las evaluaciones.
    assert_select ".empty-state p", /Empieza por las evaluaciones/
  end

  test "se puede agregar una evaluación desde Planificar" do
    plan

    assert_select "a[href*=?]", "/evaluaciones/new"
  end

  # ⚠️ Lo que NO se ofrece: en Media no hay competencias que agregar.
  test "no se ofrece agregar competencias" do
    plan

    assert_select "a[href*=?]", "/competencias/new", count: 0
    # El rótulo de competencias no va donde no las hay.
    assert_select ".plan-rotulo", text: "Competencias", count: 0
  end

  # ⚠️ Sin competencias, TODAS las evaluaciones están «sueltas» por definición:
  # pintar ese bloque en ámbar le decía a un profesor de bachillerato que su
  # plan entero está mal hecho.
  test "las evaluaciones no se marcan como «sin competencia»" do
    con_el_colegio(@a.colegio) { actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen") }

    plan

    assert_select ".plan-sueltas--normal"
    assert_no_match(/sin competencia/, response.body)
    assert_no_match(/no mide ninguna competencia/, response.body)
  end

  test "la ponderación se ve igual que en primaria" do
    con_el_colegio(@a.colegio) { actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen") }

    plan

    assert_select ".plan-ponderacion-cuenta"
    assert_select ".plan-evaluacion-peso-campo"
  end

  # Y en primaria nada de esto cambia.
  test "primaria sigue con sus competencias" do
    b, = dos_colegios_completos(nivel: :primaria)
    sign_in b.profesor

    get planificar_section_path(b.seccion, area: b.escenario.materia.id,
                                lapso: b.escenario.lapso(1).id)

    assert_select "a[href*=?]", "/competencias/new"
  end
end
