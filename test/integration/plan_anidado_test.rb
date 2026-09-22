require "test_helper"

# Las evaluaciones cuelgan de la competencia que miden (QA del 8 de septiembre).
#
# Daniel: *«¿SERÁ QUE COLOCAMOS LAS COMPETENCIAS Y EVALUACIONES JUNTAS?»* — sí,
# y anidadas, de las tres formas que se le propusieron.
#
# Lo que se gana no es estética. Una competencia que ninguna evaluación mide
# sale SIN nivel en la boleta (`MOR-229`), y ese estado había que ir a buscarlo
# a la otra pantalla. Anidado, se ve solo — y Daniel lo pidió con esas palabras:
# *«tipo warning: no debe estar una competencia sin evaluaciones»*.
class PlanAnidadoTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)   # el 1 ya trae una actividad de peso 100
    @asignacion = "#{@a.seccion.id}:#{@a.escenario.materia.id}"
    sign_in @a.profesor
  end

  def plan(**extra)
    get planificar_section_path(@a.seccion, area: @a.escenario.materia.id,
                                lapso: @lapso.id, **extra)
  end

  test "la evaluación se dibuja DENTRO de la competencia que mide" do
    con_el_colegio(@a.colegio) do
      competencia = competencia_con(1, lapso: @lapso)
      evaluacion  = actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen del lapso")
      evaluacion.competencies = [ competencia ]
    end

    plan

    # Dentro: el selector exige que la evaluación esté BAJO la competencia y no
    # en cualquier parte de la página, que es justamente lo que cambió.
    # ⚠️ Sin `.plan-evaluaciones`: el `<ul>` se retiró el 21 de septiembre. Cada
    # evaluación es su propia tarjeta con los indicadores dentro, no un renglón
    # de una lista.
    assert_select ".plan-competencia .plan-evaluacion .plan-evaluacion-nombre-campo[value=?]",
                  "Examen del lapso"
    # ⚠️ «40», no «40.0»: el decimal donde nadie escribió un decimal fue lo que
    # hizo dudar a Daniel de que el campo fuera editable.
    assert_select ".plan-competencia .plan-evaluacion-peso-campo[value=?]", "40"
    assert_select ".plan-evaluacion-peso-campo[step=?]", "1"
  end

  test "una competencia sin evaluaciones avisa lo que le va a pasar en la boleta" do
    con_el_colegio(@a.colegio) { competencia_con(1, lapso: @lapso) }

    plan

    assert_select ".plan-competencia--sin-evaluar"
    # Dice la CONSECUENCIA, no el síntoma.
    assert_select ".plan-sin-evaluar", /sin nivel en la boleta/
  end

  # ⚠️ Ya no se puede CREAR una así en primaria —`MOR-136` exige competencia e
  # indicador— pero el bloque tiene que seguir existiendo: alcanza a lo escrito
  # antes de la regla, y es exactamente donde hay que verlo para arreglarlo.
  test "una evaluación que no mide nada sale aparte, con su aviso" do
    con_el_colegio(@a.colegio) do
      competencia_con(1, lapso: @lapso)
      suelta = actividad(@a.escenario, lapso: @lapso, peso: 20, descripcion: "Participación")
      suelta.activity_competencies.destroy_all
      suelta.indicators.update_all(evaluation_activity_id: nil)
    end

    plan

    assert_select ".plan-sueltas .plan-evaluacion-nombre-campo[value=?]", "Participación"
    assert_select ".plan-sueltas-titulo", /1 evaluación sin competencia/
  end

  # ⚠️ El peso se suma sobre las evaluaciones del lapso, NO sobre el anidado:
  # ahí una evaluación de dos competencias está dos veces y su 40 % contaría 80.
  test "la ponderación cuenta una vez la evaluación que mide dos competencias" do
    con_el_colegio(@a.colegio) do
      dos = [ competencia_con(1, "Resuelve problemas de adición", lapso: @lapso),
              competencia_con(1, "Interpreta gráficos de barras", lapso: @lapso) ]
      actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen").competencies = dos
    end

    plan

    # Dos veces en la lista —una bajo cada competencia— y una sola en la suma.
    assert_select ".plan-evaluacion-nombre-campo[value=?]", "Examen", count: 2
    assert_select ".plan-ponderacion-cuenta", /\A\s*40 %/
    assert_select ".plan-ponderacion-resto", /60 % sin repartir/
    # Un tramo por evaluación, no uno por aparición en el anidado.
    assert_select ".plan-ponderacion-tramo", count: 1
  end

  # ⚠️ El error que reportó Daniel: «content missing» donde iba el formulario.
  #
  # La vista escribía `turbo_frame_tag "libreta"` fijo, así que abierta desde el
  # plan la respuesta llegaba en un frame que ESA página no tiene. No falla por
  # ningún lado: la petición devuelve 200 y Turbo escribe el hueco.
  test "abierto desde el plan, el formulario contesta en el frame del plan" do
    get new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id),
        headers: { "Turbo-Frame" => "plan" }

    assert_select "turbo-frame#plan"
    assert_select "turbo-frame#libreta", count: 0
  end

  test "abierto desde la libreta, contesta en el frame de la libreta" do
    get new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id),
        headers: { "Turbo-Frame" => "libreta" }

    assert_select "turbo-frame#libreta"
  end

  # Un id de frame llegado del cliente no se copia a un atributo sin mirarlo.
  test "un frame inventado cae en el de siempre" do
    get new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id),
        headers: { "Turbo-Frame" => "<script>alert(1)</script>" }

    assert_select "turbo-frame#libreta"
  end

  # Creando desde el plan, lo que reemplaza el formulario es el PLAN con la
  # evaluación nueva colgada — no la libreta encima de la planificación.
  test "creada desde el plan, la vuelta es al plan" do
    competencia = con_el_colegio(@a.colegio) { competencia_con(1, lapso: @lapso) }

    post evaluation_activities_path,
         params: { evaluation_activity: { asignacion: @asignacion, evaluation_moment_id: @lapso.id,
                                          description: "Taller", weight_percentage: 30,
                                          date_scheduled: Date.current,
                                          competency_ids: [ competencia.id ],
                                          indicator_ids: indicadores_de(competencia) } },
         headers: { "Turbo-Frame" => "plan" }

    assert_redirected_to planificar_section_path(@a.seccion, area: @a.escenario.materia.id,
                                                 lapso: @lapso.id)
  end

  test "creada desde la libreta, la vuelta es a la libreta" do
    competencia = con_el_colegio(@a.colegio) { competencia_con(1, lapso: @lapso) }

    post evaluation_activities_path,
         params: { evaluation_activity: { asignacion: @asignacion, evaluation_moment_id: @lapso.id,
                                          description: "Taller", weight_percentage: 30,
                                          date_scheduled: Date.current,
                                          competency_ids: [ competencia.id ],
                                          indicator_ids: indicadores_de(competencia) } },
         headers: { "Turbo-Frame" => "libreta" }

    assert_redirected_to section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
  end

  private

  # ⚠️ Los ids se leen DENTRO del colegio: `Indicator` es `SchoolScoped` y sin
  # contexto de inquilino el RLS devuelve cero filas, no un error.
  def indicadores_de(competencia)
    con_el_colegio(@a.colegio) { competencia.indicators.libres.pluck(:id) }
  end
end
