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
      actividad(@a.escenario, lapso: @lapso, peso: 60, descripcion: "Examen", mide: @competencia)
    end
    sign_in @a.profesor

    get competencies_path(asignacion: @asignacion, lapso: @lapso.id)
    follow_redirect! while response.redirect?

    # ⚠️ DENTRO de la competencia. Desde el 8 de septiembre el plan va anidado
    # y las evaluaciones cuelgan de lo que miden; antes eran chips al lado.
    assert_select ".plan-competencia .plan-evaluacion-nombre-campo[value=?]", "Examen"
    assert_select ".plan-sin-evaluar", count: 0
  end

  # ⚠️ Se dice, y no se calla: una competencia que no mide ninguna evaluación
  # sale en la boleta SIN nivel, y eso hay que verlo ANTES de emitirla — no
  # descubrirlo cuando la familia pregunta.
  #
  # Y se dice la CONSECUENCIA, no el síntoma. «Ninguna evaluación todavía» —que
  # es lo que decía— no significa nada para quien está armando su plan.
  test "una competencia sin evaluaciones lo dice, no lo calla" do
    # ⚠️ La que queda sin evaluar es OTRA: desde `MOR-136` toda evaluación de
    # primaria mide alguna, así que ya no se puede armar el caso dejando la
    # evaluación suelta — hay que escribir una competencia que nadie mida, que
    # además es el caso real de septiembre.
    con_el_colegio(@a.colegio) do
      actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Suelta", mide: @competencia)
      competencia_con(1, "Nadie la mide todavía", lapso: @lapso)
    end
    sign_in @a.profesor

    get competencies_path(asignacion: @asignacion, lapso: @lapso.id)
    follow_redirect! while response.redirect?

    assert_select ".plan-competencia--sin-evaluar"
    assert_select ".plan-sin-evaluar", /sin nivel en la boleta/
  end

  # ── Enganchar, desde la evaluación ────────────────────────────────────────
  #
  # ⚠️ Cambió de puerta el 9 de septiembre. Antes se pedía desde la COMPETENCIA
  # (`PATCH /competencias/:id/evaluaciones`) y esa acción se retiró: preguntaba
  # al revés —de la competencia hacia las evaluaciones— cuando lo que uno mira
  # en el plan es la evaluación, con sus chips en la fila.
  #
  # Las reglas de dominio son las mismas y por eso los tests siguen: solo se
  # engancha lo del MISMO plan —misma sección, misma área, mismo lapso— y el
  # filtro es una lista que no incluye lo ajeno, no una excepción a mitad de un
  # guardado.
  def enganchar(evaluacion, competencias)
    patch evaluation_activity_path(evaluacion, asignacion: @asignacion, lapso: @lapso.id,
                                               en_linea: true),
          params: { evaluation_activity: { competency_ids: Array(competencias).map(&:to_s) + [ "" ] } },
          headers: { "Turbo-Frame" => "plan" }
  end

  def competencias_de(evaluacion)
    con_el_colegio(@a.colegio) { evaluacion.reload.competency_ids }
  end

  test "enganchar una evaluación a otra competencia" do
    # ⚠️ Se AGREGA una segunda, no se engancha la primera: desde `MOR-136` la
    # evaluación nace midiendo una, así que lo que queda por probar es que se
    # le pueda sumar otra — que es el caso del chip [+] del plan.
    examen, otra = con_el_colegio(@a.colegio) do
      [ actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Examen", mide: @competencia),
        competencia_con(1, "Interpreta gráficos", lapso: @lapso) ]
    end
    sign_in @a.profesor

    assert_difference "Current.sin_aislamiento { ActivityCompetency.unscoped.count }", 1 do
      enganchar(examen, [ @competencia.id, otra.id ])
    end

    assert_equal [ @competencia.id, otra.id ].sort, competencias_de(examen).sort
    # Vuelve al plan entero: el enganche MUEVE la fila de sitio.
    assert_redirected_to planificar_section_path(@a.seccion, area: @a.escenario.materia.id,
                                                 lapso: @lapso.id)
  end

  # ⚠️ Desenganchar TODAS se rechaza, y esto probaba lo contrario.
  #
  # Regla de Daniel: *«la evaluación debe tener al menos un indicador y una
  # competencia»*. Una evaluación sin competencia cuenta para el promedio del
  # lapso y la boleta no puede explicar qué midió — que es justo el estado que
  # `MOR-229` avisaba y que ahora, en primaria, ya no se puede crear.
  #
  # El chip del plan no llega acá —dibuja «las OTRAS», así que nunca ofrece
  # quitar la única— pero el formulario completo sí, desmarcando las casillas.
  test "desenganchar todas se rechaza: una evaluación de primaria mide algo" do
    examen = con_el_colegio(@a.colegio) do
      actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Examen", mide: @competencia)
    end
    sign_in @a.profesor

    enganchar(examen, [])

    assert_equal [ @competencia.id ], competencias_de(examen),
                 "quedarse sin competencias no es un resultado posible en primaria"
  end

  # ⚠️ El campo vacío es lo que permite desenganchar TODAS: sin él, un
  # formulario sin ninguna casilla no manda la clave y el controller no se
  # entera de que hay que desenganchar.
  test "sin la clave, el enganche no se toca" do
    examen = con_el_colegio(@a.colegio) do
      actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Examen", mide: @competencia)
    end
    sign_in @a.profesor

    patch evaluation_activity_path(examen, asignacion: @asignacion, lapso: @lapso.id, en_linea: true),
          params: { evaluation_activity: { description: "Otro nombre" } }

    assert_equal [ @competencia.id ], competencias_de(examen), "cambiar el nombre no desengancha"
  end

  test "no se engancha una competencia de otro lapso" do
    de_otro_lapso = con_el_colegio(@a.colegio) do
      Competency.create!(section: @a.seccion, subject: @a.escenario.materia,
                         evaluation_moment: @a.escenario.lapso(3), descripcion: "De otro lapso")
    end
    examen = con_el_colegio(@a.colegio) { actividad(@a.escenario, lapso: @lapso, peso: 100) }
    sign_in @a.profesor

    enganchar(examen, [ de_otro_lapso.id ])

    # ⚠️ Se comprueba que NO ESTÉ la ajena, no que la lista quede vacía: desde
    # `MOR-136` una petición cuyo único id se filtra se RECHAZA, y queda lo que
    # había. Exigir la lista vacía sería exigir justo lo que la regla prohíbe.
    assert_not_includes competencias_de(examen), de_otro_lapso.id
  end

  test "ni una de otro colegio" do
    ajena = con_el_colegio(@b.colegio) do
      Competency.create!(section: @b.seccion, subject: @b.escenario.materia,
                         evaluation_moment: @b.escenario.lapso(1), descripcion: "Del colegio B")
    end
    examen = con_el_colegio(@a.colegio) { actividad(@a.escenario, lapso: @lapso, peso: 100) }
    sign_in @a.profesor

    enganchar(examen, [ ajena.id ])

    assert_not_includes competencias_de(examen), ajena.id
  end

  test "no se toca una evaluación de otro colegio" do
    ajena = con_el_colegio(@b.colegio) { @b.actividad }
    sign_in @a.profesor

    enganchar(ajena, [ @competencia.id ])

    assert_response :not_found
  end

  # ── Lo que se ve en la fila ───────────────────────────────────────────────
  test "la fila ofrece las competencias que la evaluación TODAVÍA no mide" do
    con_el_colegio(@a.colegio) do
      competencia_con(1, "Interpreta gráficos de barras", lapso: @lapso)
      e = actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Examen")
      e.competencies = [ @competencia ]
    end
    sign_in @a.profesor

    get planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)

    # La que ya mide no se ofrece otra vez; la otra sí.
    assert_select ".plan-evaluacion-mas-opcion", "Interpreta gráficos de barras"
    assert_select ".plan-evaluacion-mas-opcion", { count: 1 }, "no se ofrece la que ya mide"
  end

  # ⚠️ El chip dice las OTRAS, no todas: en el anidado la evaluación ya está
  # DEBAJO de la que mide, y repetirlo es decir dos veces lo mismo.
  test "el chip nombra la otra competencia, no la de arriba" do
    otra = con_el_colegio(@a.colegio) { competencia_con(1, "Interpreta gráficos", lapso: @lapso) }
    con_el_colegio(@a.colegio) do
      e = actividad(@a.escenario, lapso: @lapso, peso: 100, descripcion: "Examen")
      e.competencies = [ @competencia, otra ]
    end
    sign_in @a.profesor

    get planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)

    # Sale dos veces —una bajo cada competencia— y cada una nombra a la otra.
    assert_select ".plan-evaluacion-chip", 2
    assert_select ".plan-evaluacion-chips-etiqueta", "también mide"
  end
end
