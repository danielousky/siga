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
    @lapso = @a.escenario.lapso(1)
  end

  test "el profesor ve el plan de la sección que dicta" do
    sign_in @a.profesor
    get competencies_path(asignacion: @asignacion, lapso: @lapso.id)
    follow_redirect! while response.redirect?

    assert_response :success
    # ⚠️ El título es el de la SECCIÓN: el plan vive en su pestaña, y ahí lo que
    # hay que confirmar de un vistazo es dónde estoy parado.
    assert_select "h1", /#{@a.seccion.grade.name}/
    assert_select ".pestana.activa", text: "Planificar"
  end

  test "escribe una competencia con sus indicadores, uno por línea" do
    sign_in @a.profesor

    assert_difference [ "Competency.count" ], 1 do
      assert_difference "Indicator.count", 3 do
        post competencies_path(asignacion: @asignacion, lapso: @lapso.id), params: {
          competency: { descripcion: "Resuelve problemas de adición y sustracción",
                        indicadores: "Suma con reagrupación\nResuelve problemas de dos pasos\n\nEstima antes de calcular" }
        }
      end
    end

    assert_redirected_to planificar_section_path(@a.seccion, area: @a.escenario.materia.id,
                                                 lapso: @lapso.id)
    con_el_colegio(@a.colegio) do
      assert_equal [ "Suma con reagrupación", "Resuelve problemas de dos pasos", "Estima antes de calcular" ],
                   Competency.last.indicators.en_orden.map(&:descripcion),
                   "la línea en blanco tiene que ignorarse, no crear un indicador vacío"
    end
  end

  # ⚠️ Al editar, los indicadores se REEMPLAZAN. La maestra ve la lista
  # completa: si borra una línea, esa línea desaparece — no quedan seis.
  test "editar reemplaza los indicadores, no los suma" do
    c = con_el_colegio(@a.colegio) { competencia_con(2) }
    sign_in @a.profesor

    patch competency_path(c, asignacion: @asignacion, lapso: @lapso.id), params: {
      competency: { descripcion: c.descripcion, indicadores: "Solo este" }
    }

    con_el_colegio(@a.colegio) do
      assert_equal [ "Solo este" ], c.reload.indicators.map(&:descripcion)
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
      assert_equal del_ano_pasado.indicators.map(&:descripcion), traida.indicators.map(&:descripcion)
      # ⚠️ Se COPIA el texto, no se referencia: corregirlo este año no puede
      # reescribir la boleta que ya salió.
      assert_not_equal del_ano_pasado.id, traida.id
    end
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
    c = con_el_colegio(@a.colegio) do
      comp = competencia_con(0)
      ActivityCompetency.create!(competency: comp, evaluation_activity: @a.actividad)
      comp
    end
    sign_in @a.profesor

    delete competency_path(c, asignacion: @asignacion, lapso: @lapso.id)

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
  def plan_viejo
    periodo = AcademicPeriod.create!(name: "2024-2025", start_date: Date.new(2024, 9, 15),
                                     end_date: Date.new(2025, 7, 31))
    lapso   = EvaluationMoment.create!(academic_period: periodo, name: @lapso.name)
    seccion = Section.create!(grade: @a.grado, academic_period: periodo, name: "A", capacity: 30)
    c = Competency.create!(section: seccion, subject: @a.escenario.materia,
                           evaluation_moment: lapso, descripcion: "Competencia del año pasado")
    c.indicators.create!(descripcion: "Su indicador", orden: 0)
    c
  end
end
