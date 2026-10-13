require "test_helper"

# El plan de evaluación de una sección (MOR-136).
#
# Lo que se prueba es lo que el issue promete: que una competencia se escriba
# **una vez** y se pueda reutilizar. Y las tres cosas que se rompen en silencio:
# que el plan ajeno no aparezca, que traer el del año pasado no duplique, y que
# copiar a otra sección no ate las dos.
# ⚠️ LOS TESTS DE LA ESCALERA SE RETIRARON con la pantalla (etapa ③).
#
# Grado → área → sección → lapso existía para que el profesor eligiera de qué
# plan hablaba. Desde que entra por el árbol del menú —que ya trae las cuatro
# cosas— `/competencias` dejó de ser su destino, y al ir a arreglarlo apareció
# la razón de fondo: esa escalera se alimenta de `mis_asignaciones`, vacía para
# la dirección. La pantalla **solo funcionaba para profesores**, así que sin
# ellos no le servía a nadie.
#
# Daniel: *«esa vista ya no debe estar»*. Lo que queda de `/competencias` es un
# redirector, y eso se prueba en `menu_del_profesor_test`.
#
# El PLAN sigue probándose acá, en la pestaña donde ahora vive.
class PlanDeEvaluacionTest < ActionDispatch::IntegrationTest
  setup do
    # ⚠️ PRIMARIA: la evaluación por competencias es de primaria, y en
    # bachillerato la pantalla dice justamente que no aplica.
    @a, @b = dos_colegios_completos(nivel: :primaria)
    @asignacion = "#{@a.seccion.id}:#{@a.escenario.materia.id}"
    # ⚠️ El SEGUNDO lapso, y no el primero: el escenario arma su evaluación en
    # el primero, y desde `MOR-136` una evaluación de primaria mide una
    # competencia — o sea que el primer lapso ya NO tiene el plan vacío. Media
    # docena de estos tests hablan justamente de un lapso sin plan: «ofrece
    # duplicar el del año pasado», «copiar a la hermana», «no hay pestañas».
    @lapso = @a.escenario.lapso(2)
  end

  test "el profesor ve el plan de la sección que dicta" do
    sign_in @a.profesor
    get competencies_path(asignacion: @asignacion, lapso: @lapso.id)
    follow_redirect! while response.redirect?

    assert_response :success
    # ⚠️ El título es el de la SECCIÓN: el plan vive en su pestaña, y ahí lo que
    # hay que confirmar de un vistazo es dónde estoy parado.
    assert_select "h1", /#{@a.seccion.grade.name}/
    assert_select ".pestana.activa", text: "Plan de Evaluación"
  end

  # ⚠️ El formulario ya NO recibe indicadores, y los dos tests que lo probaban
  # —«uno por línea» y «editar los reemplaza»— se retiraron con el campo.
  #
  # Desde el 21 de septiembre un indicador cuelga de la EVALUACIÓN que lo mide.
  # Lo que naciera en el formulario de la competencia quedaría sin evaluación:
  # sin salir en la boleta —solo se imprimen los medidos— y sin aparecer en el
  # plan, que los dibuja dentro de su evaluación. Un segundo lugar donde
  # escribirlos era un segundo lugar donde perderlos.
  #
  # El alta y la edición uno por uno se prueban en `indicadores_test`.
  test "la competencia se escribe sola, sin pedir indicadores" do
    sign_in @a.profesor

    assert_difference -> { cantidad(Competency) }, 1 do
      assert_no_difference -> { cantidad(Indicator) } do
        post competencies_path(asignacion: @asignacion, lapso: @lapso.id), params: {
          competency: { descripcion: "Resuelve problemas de adición y sustracción" }
        }
      end
    end

    assert_redirected_to planificar_section_path(@a.seccion, area: @a.escenario.materia.id,
                                                 lapso: @lapso.id)
  end

  # ⚠️ La competencia nueva va AL FINAL del plan.
  #
  # `competencies.orden` tiene `DEFAULT 0` y el alta no lo mandaba, así que toda
  # nueva nacía con cero y `order(:orden, :id)` la metía entre las que ya tenían
  # 0 y las que tenían 1. Daniel lo vio al agregar la tercera y aparecer de
  # segunda: *«el orden de las competencias debe ser por creación, supongo»*.
  test "la competencia nueva se agrega al final, no en el medio" do
    con_el_colegio(@a.colegio) do
      competencia_con(0, "La primera", lapso: @lapso)
      competencia_con(0, "La segunda", lapso: @lapso).update!(orden: 1)
    end
    sign_in @a.profesor

    post competencies_path(asignacion: @asignacion, lapso: @lapso.id),
         params: { competency: { descripcion: "La tercera" } }

    con_el_colegio(@a.colegio) do
      assert_equal [ "La primera", "La segunda", "La tercera" ],
                   Competency.del_plan(@a.seccion.id, @a.escenario.materia.id, @lapso.id)
                             .map(&:descripcion)
    end
  end

  # ⚠️ Y editarla no toca los suyos: había un `destroy_all` para el textarea, y
  # borrarlos ahora sería tirar el trabajo de tres evaluaciones por una tilde.
  test "editar la competencia no toca sus indicadores" do
    c = con_el_colegio(@a.colegio) { competencia_con(2) }
    sign_in @a.profesor

    patch competency_path(c, asignacion: @asignacion, lapso: @lapso.id), params: {
      competency: { descripcion: "Con otro nombre" }
    }

    con_el_colegio(@a.colegio) do
      assert_equal 2, c.reload.indicators.count
      assert_equal "Con otro nombre", c.descripcion
    end
  end

  # ⚠️ Lo que el issue promete: no volver a escribir lo que el colegio ya
  # escribió.
  test "trae el plan del año pasado del mismo grado y materia" do
    del_ano_pasado = con_el_colegio(@a.colegio) { plan_viejo }
    sign_in @a.profesor

    post traer_competencies_path(asignacion: @asignacion, lapso: @lapso.id)

    con_el_colegio(@a.colegio) do
      traida = Competency.del_plan(@a.seccion.id, @a.escenario.materia.id, @lapso.id).last
      assert_equal del_ano_pasado.descripcion, traida.descripcion
      # ⚠️ SIN indicadores: `plan_viejo` no trae evaluaciones —lo dictó otro
      # profesor— y desde el 22 de septiembre un indicador viaja con la suya.
      assert_empty traida.indicators
      # ⚠️ Se COPIA el texto, no se referencia: corregirlo este año no puede
      # reescribir la boleta que ya salió.
      assert_not_equal del_ano_pasado.id, traida.id
    end
  end

  # ── Qué viene, y qué no ───────────────────────────────────────────────────
  #
  # Daniel, 17 de septiembre: *«cuando se trae la planificación del año
  # anterior, solo debería traer las competencias e indicadores; las
  # evaluaciones no. Esas deben ser agregadas nuevas, a menos que sea el mismo
  # profe, en ese caso se deben clonar para que haga el ajuste directamente
  # él»*.
  #
  # **Una evaluación es una decisión pedagógica de quien evalúa** —el peso, la
  # fecha, qué mide— y heredarla de otro le pone al profesor nuevo un criterio
  # ajeno que además no va a revisar, porque vino puesto. La competencia sí se
  # hereda: describe qué enseña el grado.
  test "de otro profesor vienen las competencias, no sus evaluaciones" do
    con_el_colegio(@a.colegio) { plan_viejo(con_evaluacion: true) }
    sign_in @a.profesor

    get planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
    assert_select ".plan-sugerido .nota-ayuda", /la dictó otro profesor/

    post traer_competencies_path(asignacion: @asignacion, lapso: @lapso.id)

    con_el_colegio(@a.colegio) do
      assert_equal 1, Competency.del_plan(@a.seccion.id, @a.escenario.materia.id, @lapso.id).count
      assert_empty EvaluationActivity.where(section_id: @a.seccion.id,
                                            subject_id: @a.escenario.materia.id,
                                            evaluation_moment_id: @lapso.id),
                   "el peso y la fecha del examen de otro profesor no son un plan que heredar"
    end
  end

  test "del MISMO profesor vienen también sus evaluaciones, con la fecha corrida" do
    con_el_colegio(@a.colegio) do
      vieja = plan_viejo(con_evaluacion: true)
      # Lo que cambia todo: ESA sección de ese año la dictaba él.
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: vieja.section,
                             subject: @a.escenario.materia)
    end
    sign_in @a.profesor

    get planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
    assert_select ".plan-sugerido .nota-ayuda", /lo dictó usted/

    post traer_competencies_path(asignacion: @asignacion, lapso: @lapso.id)

    con_el_colegio(@a.colegio) do
      copiada = EvaluationActivity.find_by(section_id: @a.seccion.id,
                                           subject_id: @a.escenario.materia.id,
                                           evaluation_moment_id: @lapso.id)
      assert copiada, "la evaluación del año pasado tiene que clonarse para que él la ajuste"
      assert_equal 40, copiada.weight_percentage
      # Mismo día y mes, el año que corresponde: 8 nov 2024 → 8 nov 2025.
      assert_equal Date.new(2025, 11, 8), copiada.date_scheduled
      assert_equal [ "Su indicador" ], copiada.indicators.map(&:descripcion)
    end
  end

  # ⚠️ LOS TRES QUE FALTABAN, y por eso el botón desapareció sin que nadie se
  # enterara: los de arriba prueban el POST —que siempre funcionó— y ninguno
  # probaba que la pantalla OFRECIERA tocarlo.
  #
  # `@sugerido` lo llenaba `CompetenciesController#index`; cuando el índice se
  # volvió un redirector, la asignación se fue con él y la vista quedó
  # preguntando por una variable que ya no escribía nadie. `nil&.any?` no falla,
  # no avisa y no rompe nada — la tarjeta simplemente dejó de dibujarse.
  test "la tarjeta del año pasado se OFRECE en la pestaña, no solo funciona el POST" do
    con_el_colegio(@a.colegio) { plan_viejo }
    sign_in @a.profesor

    get planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)

    assert_response :success
    assert_select ".plan-sugerido", 1, "sin esta tarjeta, traer el plan del año pasado no tiene puerta"
    assert_select ".plan-sugerido-titulo", /Hay un plan del año pasado/
    # ⚠️ El `action` lleva el contexto pegado —`?asignacion=…&lapso=…`—, que es
    # lo que impide que traer el plan te expulse de la sección. Se compara el
    # comienzo, no la URL entera.
    assert_select ".plan-sugerido form" do |formularios|
      assert formularios.any? { |f| f["action"].start_with?(traer_competencies_path) },
             "el botón tiene que hacer POST a #{traer_competencies_path}"
    end
  end

  # ⚠️ Ofrecer duplicar sobre un plan ya escrito es ruido: la maestra ya hizo el
  # trabajo, y la tarjeta le sugiere mezclarle otro año encima.
  test "la tarjeta desaparece cuando el lapso ya tiene su plan" do
    con_el_colegio(@a.colegio) do
      plan_viejo
      competencia_con(1)
    end
    sign_in @a.profesor

    get planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)

    assert_select ".plan-sugerido", 0
  end

  # ⚠️ El botón hace POST a `traer_competencies`, que exige `require_profesor!`.
  # A la dirección le saldría un control que la rebota — que es la manera de
  # enseñar que los controles de este sistema a veces no funcionan.
  test "la dirección ve el plan pero no el botón de duplicar" do
    con_el_colegio(@a.colegio) { plan_viejo }
    sign_in @a.director

    get planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)

    assert_response :success
    assert_select ".plan-sugerido", 0
  end

  # ⚠️ Una sección de OTRO año escolar: `asignacion` se busca entre las del año
  # de la sesión, así que ahí es nil mientras la sección y el área no lo son.
  #
  # La tarjeta salía igual —el plan cuelga de la sección, no de la asignación— y
  # la vista le pedía la materia a `asignacion`: la pantalla entera reventaba con
  # «undefined method 'subject' for nil». Y el profesor no tiene selector de año
  # justamente para no planificar en el año equivocado, así que tampoco debía
  # salirle.
  test "una sección de otro año escolar no revienta ni ofrece duplicar" do
    del_otro_ano = con_el_colegio(@a.colegio) do
      plan_viejo   # deja un plan en 2024-2025, que es lo que se va a sugerir
      # ⚠️ Un TERCER año: el destino tiene que estar vacío y ser de un año
      # distinto al del plan, o `para_sugerir` no lo propone.
      otro = AcademicPeriod.create!(name: "2023-2024", start_date: Date.new(2023, 9, 15),
                                    end_date: Date.new(2024, 7, 31))
      EvaluationMoment.create!(academic_period: otro, name: @lapso.name)
      seccion = Section.create!(grade: @a.grado, academic_period: otro, name: "A", capacity: 30)
      # ⚠️ CON la asignación: sin ella la autorización lo rebota antes de
      # dibujar nada, y el error no se reproduce. El bug es justamente el del
      # profesor que tiene la sección, pero en otro año que el de su sesión.
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: seccion,
                             subject: @a.escenario.materia)
      seccion
    end
    sign_in @a.profesor

    get planificar_section_path(del_otro_ano, area: @a.escenario.materia.id)

    assert_response :success
    assert_select ".plan-sugerido", 0
  end

  # ⚠️ Idempotente, como `CopiarLaEstructura`: traerlo dos veces no duplica.
  test "traerlo dos veces no duplica nada" do
    con_el_colegio(@a.colegio) { plan_viejo }
    sign_in @a.profesor

    post traer_competencies_path(asignacion: @asignacion, lapso: @lapso.id)
    assert_no_difference "Competency.count" do
      post traer_competencies_path(asignacion: @asignacion, lapso: @lapso.id)
    end
  end

  # ⚠️ Copiar es un ATAJO, no un vínculo.
  test "copiar a otra sección no ata las dos" do
    otra = con_el_colegio(@a.colegio) do
      s = Section.create!(grade: @a.grado, academic_period: @a.escenario.periodo, name: "W", capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: s, subject: @a.escenario.materia)
      s
    end
    original = con_el_colegio(@a.colegio) { competencia_con(1) }
    sign_in @a.profesor

    post copiar_a_competencies_path(asignacion: @asignacion, lapso: @lapso.id)

    con_el_colegio(@a.colegio) do
      copia = Competency.del_plan(otra.id, @a.escenario.materia.id, @lapso.id).first
      assert_equal original.descripcion, copia.descripcion

      original.update!(descripcion: "Otra cosa completamente distinta")
      assert_not_equal original.reload.descripcion, copia.reload.descripcion,
                       "copiar ató las dos secciones"
    end
  end

  # ⚠️ Copiar es a las HERMANAS: mismo grado, misma materia.
  #
  # Ofrecía las diecinueve secciones donde el profesor dicta la materia, de 1er
  # a 5to Año — y una competencia de 1er Año en 5to es basura que después
  # alguien borra a mano. En pantalla se leía «Copiar a mis otras 19 secciones».
  test "copiar no alcanza a una sección de otro grado" do
    otro_grado, hermana = con_el_colegio(@a.colegio) do
      g = Grade.create!(name: "3er Grado", school: @a.colegio)
      lejana = Section.create!(grade: g, academic_period: @a.escenario.periodo, name: "U", capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: lejana, subject: @a.escenario.materia)

      h = Section.create!(grade: @a.grado, academic_period: @a.escenario.periodo, name: "W", capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: h, subject: @a.escenario.materia)
      [ lejana, h ]
    end
    con_el_colegio(@a.colegio) { competencia_con(1) }
    sign_in @a.profesor

    post copiar_a_competencies_path(asignacion: @asignacion, lapso: @lapso.id)

    con_el_colegio(@a.colegio) do
      assert Competency.del_plan(hermana.id, @a.escenario.materia.id, @lapso.id).exists?,
             "la sección hermana —mismo grado, misma materia— sí tenía que recibir la copia"
      assert_empty Competency.del_plan(otro_grado.id, @a.escenario.materia.id, @lapso.id),
                   "una sección de OTRO grado no puede recibir el plan de este"
    end
  end

  # ⚠️ Un colegio que ya copió su estructura al año siguiente tiene la MISMA
  # sección dos veces —«1er Año B» de 2025-2026 y «1er Año B» de 2026-2027— y
  # sin filtrar por año salían las dos: «Copiar a 1er Año A, B y B».
  #
  # Lo cosmético era lo de menos: copiar hacia el año anterior escribe un plan
  # en un lapso cerrado, y el profesor no tiene selector de año para notarlo.
  test "copiar no alcanza a la misma sección de otro año escolar" do
    del_ano_pasado = con_el_colegio(@a.colegio) do
      viejo = ano_escolar_viejo(@a.escenario, nombre: "2023-2024", seccion: "B")
      s = Section.find_by(academic_period: viejo, name: "B")
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: s, subject: @a.escenario.materia)
      s
    end
    con_el_colegio(@a.colegio) { competencia_con(1) }
    sign_in @a.profesor

    get competencies_path(asignacion: @asignacion, lapso: @lapso.id)
    follow_redirect! while response.redirect?
    assert_select ".plan-acciones", false,
                  "sin secciones hermanas EN ESTE AÑO no hay nada que ofrecer copiar"

    post copiar_a_competencies_path(asignacion: @asignacion, lapso: @lapso.id)

    con_el_colegio(@a.colegio) do
      assert_empty Competency.unscoped.where(section_id: del_ano_pasado.id),
                   "el plan de este año no puede caer en una sección del año pasado"
    end
  end

  # ⚠️ Cambió el 10 de septiembre: en Educación Media «Planificar» ya NO rebota
  # a Calificar. Es la misma pantalla sin competencias — las evaluaciones, su
  # peso y su fecha, que es lo que el Artículo 111 llama plan de evaluación.
  #
  # Rebotaba, y allá el botón de alta se había retirado ese mismo día: las dos
  # pestañas se mandaban la una a la otra y un profesor de bachillerato no podía
  # crear ninguna evaluación. Lo cubre entero `plan_de_media_test`.
  test "un profesor de bachillerato planifica SIN competencias" do
    media, = dos_colegios_completos(nivel: :secundaria)
    sign_in media.profesor

    get planificar_section_path(media.seccion, area: media.escenario.materia.id)

    assert_response :success
    assert_no_match(/competencias son de primaria/i, response.body)
    assert_select "a[href*=?]", "/competencias/new", count: 0
    assert_select "a[href*=?]", "/evaluaciones/new"
  end

  # ⚠️ El plan ajeno no aparece: pedirlo por id da 404, no 403 — no se confirma
  # que exista.
  test "no se llega al plan de otro profesor" do
    ajena = con_el_colegio(@b.colegio) do
      Competency.create!(section: @b.seccion, subject: @b.escenario.materia,
                         evaluation_moment: @b.escenario.lapso(1), descripcion: "Del colegio B")
    end
    sign_in @a.profesor

    get edit_competency_path(ajena, asignacion: @asignacion, lapso: @lapso.id)

    assert_response :not_found, "el plan ajeno tiene que dar 404, no 403: no se confirma que exista"
  end

  # ⚠️ Borrar una competencia etiquetada cambiaría lo que dice una boleta hacia
  # atrás.
  test "no se borra una competencia que ya etiqueta una evaluación" do
    # ⚠️ La del ESCENARIO, que ya la mide su evaluación: desde `MOR-136` toda
    # evaluación de primaria etiqueta una, así que no hace falta —ni se puede—
    # engancharle otra a mano.
    primer_lapso = @a.escenario.lapso(1)
    c = con_el_colegio(@a.colegio) { @a.actividad.competencies.first }
    sign_in @a.profesor

    delete competency_path(c, asignacion: @asignacion, lapso: primer_lapso.id)

    # ⚠️ Se comprueba que la FILA siga ahí, no un conteo: `Competency.count` es
    # `SchoolScoped`, y antes de la petición `Current.school` todavía es nil —
    # los dos conteos se miden en contextos de inquilino distintos y la
    # diferencia no significa nada.
    assert Current.sin_aislamiento { Competency.unscoped.exists?(c.id) },
           "se borró una competencia que ya etiqueta una evaluación"
    assert flash[:alert].present?, "y hay que decir por qué no se pudo"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El QA de Daniel del 7 de septiembre
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ Con UNA sola sección no hay pestañas: un control de una opción no decide
  # nada. Misma regla que el área, el nivel y el año escolar.
  test "con una sola sección no aparecen las pestañas" do
    con_el_colegio(@a.colegio) { competencia_con(0) }
    sign_in @a.profesor
    get competencies_path(asignacion: @asignacion, lapso: @lapso.id)
    follow_redirect! while response.redirect?

    etiquetas = css_select(".pastillas-etiqueta").map { |e| e.text.strip }
    assert_not_includes etiquetas, "Sección"
  end

  # ⚠️ Daniel: *«si la sección ya tiene competencia, se deshabilita esta opción
  # con mensaje indicativo»*. Copiar dos veces no duplicaba nada —es
  # idempotente— pero el botón seguía ahí ofreciendo algo que no hacía nada.
  test "copiar desaparece cuando la hermana ya tiene su plan" do
    hermana = con_el_colegio(@a.colegio) do
      s = Section.create!(grade: @a.grado, academic_period: @a.escenario.periodo,
                          name: "B", capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: s,
                             subject: @a.escenario.materia)
      s
    end
    con_el_colegio(@a.colegio) { competencia_con(1) }
    sign_in @a.profesor

    get competencies_path(asignacion: @asignacion, lapso: @lapso.id)
    follow_redirect! while response.redirect?
    assert_select ".plan-acciones form", 1, "con la hermana vacía, copiar tiene sentido"

    post copiar_a_competencies_path(asignacion: @asignacion, lapso: @lapso.id)
    get competencies_path(asignacion: @asignacion, lapso: @lapso.id)
    follow_redirect! while response.redirect?

    assert_select ".plan-acciones form", 0
    # ⚠️ Empieza con «La», sin número delante: `contar` antepone el conteo
    # —«1 La otra sección»— y acá la frase ya trae su artículo.
    assert_select ".plan-ya-copiado", /\ALa otra sección de .* ya tiene su plan/
    assert hermana.present?
  end

  private

  # El mismo grado y la misma materia, un año antes.
  # `con_evaluacion:` agrega una evaluación que mide esa competencia: es lo que
  # separa los dos casos de «traer el plan del año pasado» —el mismo profesor se
  # la lleva, otro no—.
  def plan_viejo(con_evaluacion: false)
    periodo = AcademicPeriod.create!(name: "2024-2025", start_date: Date.new(2024, 9, 15),
                                     end_date: Date.new(2025, 7, 31))
    lapso   = EvaluationMoment.create!(academic_period: periodo, name: @lapso.name)
    seccion = Section.create!(grade: @a.grado, academic_period: periodo, name: "A", capacity: 30)
    c = Competency.create!(section: seccion, subject: @a.escenario.materia,
                           evaluation_moment: lapso, descripcion: "Competencia del año pasado")
    c.indicators.create!(descripcion: "Su indicador", orden: 0)
    return c unless con_evaluacion

    e = EvaluationActivity.new(section: seccion, subject: @a.escenario.materia,
                               evaluation_moment: lapso, description: "Examen del año pasado",
                               weight_percentage: 40, date_scheduled: Date.new(2024, 11, 8))
    e.competency_ids = [ c.id ]
    e.indicators     = c.indicators.to_a
    e.save!
    c
  end
end
