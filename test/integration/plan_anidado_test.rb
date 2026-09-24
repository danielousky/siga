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

  # ── El deslizador del peso (23 de septiembre) ─────────────────────────────
  #
  # Daniel: *«en el porcentaje podemos agregar un rango en la misma línea,
  # pequeño… que la persona deslice en lugar de escribir»*.
  #
  # ⚠️ Lo que este test cuida NO es que el rango exista: es que NO lleve `name`.
  # Con los dos controles enviando `weight_percentage`, el formulario mandaría
  # el peso dos veces y el servidor se quedaría con el último del marcado — o
  # sea, con el que el profesor no tocó. Es un fallo que no da error en ningún
  # lado: guarda, y guarda otro número.
  test "el peso se puede deslizar, y el deslizador no se envía" do
    con_el_colegio(@a.colegio) do
      competencia = competencia_con(0, lapso: @lapso)
      evaluacion  = actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen del lapso")
      evaluacion.competencies = [ competencia ]
    end

    plan

    assert_select ".plan-evaluacion-campo--peso input[type=range][value=?]", "40"
    assert_select ".plan-evaluacion-campo--peso input[type=range][name]", false,
                  "el deslizador no puede tener name: enviaría el peso dos veces"
    # Y el número sigue siendo el campo.
    assert_select ".plan-evaluacion-peso-campo[name=?]", "evaluation_activity[weight_percentage]"
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

  # ── Cuántas notas tiene ya cada evaluación (22 de septiembre) ────────────
  #
  # Daniel, después de que el plan le negara borrar una evaluación: *«me surgió
  # la necesidad de colocar un elemento que indique si ya tiene notas cargadas,
  # o cuántas de cuántos»*. Antes eso solo se sabía intentando borrarla y
  # leyendo el error — o pasando el ratón por el botón de borrar.
  test "la fila dice cuántas notas tiene, de cuántos alumnos" do
    con_el_colegio(@a.colegio) do
      c = competencia_con(1, lapso: @lapso)
      examen = actividad(@a.escenario, lapso: @lapso, peso: 50, descripcion: "Examen", mide: c)
      nota(examen, @a.escenario.alumno(1), 16)
      # El segundo alumno queda sin nota: es el caso que hay que poder ver.
      actividad(@a.escenario, lapso: @lapso, peso: 50, descripcion: "Taller", mide: c)
    end

    plan

    textos = css_select(".plan-evaluacion-avance").map { |e| e.text.squish }
    assert_includes textos, "1 de 2", "el examen tiene una nota de dos alumnos"
    assert_includes textos, "0 de 2", "el taller no tiene ninguna"

    # ⚠️ Es una PASTILLA con su icono, no un número al margen: Daniel no lo
    # encontraba entre el «40 %» y la fecha. Y el color va en el DATO
    # (`MOR-135`), con los estados que ya usa el resto de la app.
    assert_select ".plan-evaluacion-avance.pastilla-de-cobro.estado-en-revision", 1
    assert_select ".plan-evaluacion-avance.pastilla-de-cobro.estado-en-mora", 1
  end

  # ⚠️ Con notas cargadas, el botón de borrar se APAGA y dice por qué.
  #
  # Daniel, 22 de septiembre: *«una mejor UX es que el botón de eliminar esté
  # disabled si tiene notas, en lugar de intentar una acción que no va a poder
  # hacer. Lo que sí tenemos que indicarle es por qué está bloqueada la
  # eliminación»*. Antes se tocaba, el modelo lo rechazaba, y el error aparecía
  # arriba de la pantalla — lejos de la fila que lo produjo.
  test "con notas cargadas el botón de borrar se apaga y dice por qué" do
    con_el_colegio(@a.colegio) do
      c = competencia_con(1, lapso: @lapso)
      examen = actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Examen", mide: c)
      nota(examen, @a.escenario.alumno(1), 16)
    end

    plan

    # ⚠️ `aria-disabled` y no `disabled`: un botón deshabilitado de verdad no
    # recibe foco, y el tooltip aparece con `:hover` y con `:focus-visible`.
    assert_select "button[aria-disabled=?]", "true" do |botones|
      assert botones.any? { |b| b["data-tooltip"].to_s.match?(/no se puede borrar/i) },
             "el botón apagado tiene que decir POR QUÉ"
      assert botones.any? { |b| b["data-tooltip"].to_s.include?("1 nota cargada") },
             "y cuántas notas lo impiden"
    end
    # ⚠️ Y no queda un formulario de borrado que se pueda enviar igual.
    #
    # Se busca por el `aria-label` exacto: los otros dos botones de borrar de la
    # pantalla —«Borrar la competencia» y «Quitar este indicador»— sí siguen ahí
    # y tienen que seguir.
    assert_select "form button[aria-label=?]", "Borrar", 0,
                  "con notas, el borrado de la evaluación no se ofrece ni escondido"
  end

  # ⚠️ Sin notas se puede borrar, y el aviso dice que los INDICADORES se van con
  # la evaluación. Daniel: *«se le puede indicar al usuario que al eliminar las
  # evaluaciones se van los indicadores respectivos»*.
  test "sin notas se puede borrar, y el aviso dice que los indicadores se van" do
    con_el_colegio(@a.colegio) do
      c = competencia_con(1, lapso: @lapso)
      actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Examen", mide: c)
    end

    plan

    assert_select "form[data-turbo-confirm*=?]", "Se borran también", 1
    assert_select "button[aria-disabled=?]", "true", 0
  end

  # ⚠️ «0 de 0» en rojo diría que el profesor no hizo algo que no tenía que
  # hacer: sin alumnos inscritos no hay notas que cargar.
  test "sin alumnos inscritos, la fila no reclama notas" do
    vacia = con_el_colegio(@a.colegio) do
      s = Section.create!(grade: @a.grado, academic_period: @a.escenario.periodo,
                          name: "Z", capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: s,
                             subject: @a.escenario.materia)
      c = Competency.create!(section: s, subject: @a.escenario.materia,
                             evaluation_moment: @lapso, descripcion: "Sin alumnos")
      c.indicators.create!(descripcion: "El suyo", orden: 0)
      e = EvaluationActivity.new(section: s, subject: @a.escenario.materia,
                                 evaluation_moment: @lapso, description: "Examen",
                                 weight_percentage: 100, date_scheduled: Date.new(2025, 11, 5))
      e.competency_ids = [ c.id ]
      e.indicators = c.indicators.to_a
      e.save!
      s
    end
    sign_in @a.profesor

    get planificar_section_path(vacia, area: @a.escenario.materia.id, lapso: @lapso.id)

    assert_select ".plan-evaluacion-avance--sin-alumnos", text: "sin alumnos"
    assert_select ".libreta-avance--vacia", 0
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
