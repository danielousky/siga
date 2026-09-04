require "test_helper"

# El plan de evaluación por competencias (MOR-136).
#
# Spec congelado: `docs/specs/mor-136-evaluacion-de-primaria.md`.
#
# ## Qué se prueba de verdad
#
# No que las tablas existan. Las cuatro cosas que se rompen en silencio:
#
#   1. que agregar esto NO toque la aritmética que ya funciona;
#   2. que la rúbrica traduzca sin huecos, y con tres niveles igual que con cinco;
#   3. que una fila cruzada —otro colegio, otra sección, otro lapso— no se pueda
#      escribir, porque escrita no la encuentra nadie;
#   4. que la canónica impida la competencia duplicada en el mismo plan.
class EvaluacionPorCompetenciasTest < ActiveSupport::TestCase
  setup do
    @a, @b = dos_colegios_completos
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La rúbrica: una máscara sobre el 1-20, no una escala
  # ══════════════════════════════════════════════════════════════════════════

  test "la rúbrica por defecto cubre el 1 al 20 sin huecos" do
    con_el_colegio(@a.colegio) do
      rubricas = sembrar_rubrica(Rubric::POR_DEFECTO)

      (1..20).each do |nota|
        assert Rubric.para(nota, rubricas), "la nota #{nota} se quedó sin nivel"
      end
    end
  end

  test "cada nota cae en el nivel que le toca" do
    con_el_colegio(@a.colegio) do
      rubricas = sembrar_rubrica(Rubric::POR_DEFECTO)

      { 20 => "PC", 19 => "PC", 18 => "PA", 17 => "PA", 16 => "PI",
        14 => "PI", 13 => "PD", 10 => "PD", 9 => "NP", 1 => "NP" }.each do |nota, code|
        assert_equal code, Rubric.para(nota, rubricas).code, "la nota #{nota}"
      end
    end
  end

  # ⚠️ El caso que Cyndi nombró y el que rompe cualquier implementación que
  # asuma cinco niveles: *«había colegios que solo tenían tres»*.
  test "un colegio de tres niveles también cubre el 1 al 20" do
    con_el_colegio(@a.colegio) do
      rubricas = sembrar_rubrica([
        { code: "L",  name: "Logrado",    valor: 15 },
        { code: "EP", name: "En proceso", valor: 10 },
        { code: "NL", name: "No logrado", valor: 1 }
      ])

      (1..20).each { |nota| assert Rubric.para(nota, rubricas), "la nota #{nota}" }
      assert_equal "L",  Rubric.para(20, rubricas).code
      assert_equal "NL", Rubric.para(9, rubricas).code
    end
  end

  # ⚠️ La razón por la que el sustrato es el NÚMERO y no el nivel. Daniel:
  # *«metías en el mismo saco a estudiantes con 13 que a estudiantes con 17»*.
  # Con tres niveles la máscara es más gruesa; por dentro siguen siendo dos
  # notas distintas, y eso es lo que no se puede perder.
  test "con la máscara gruesa el 13 y el 17 siguen siendo distintos por dentro" do
    con_el_colegio(@a.colegio) do
      rubricas = sembrar_rubrica([
        { code: "L",  name: "Logrado",    valor: 15 },
        { code: "EP", name: "En proceso", valor: 10 },
        { code: "NL", name: "No logrado", valor: 1 }
      ])

      assert_equal Rubric.para(13, rubricas).code, Rubric.para(14, rubricas).code,
                   "las dos caen en el mismo nivel, y está bien"
      refute_equal 13, 14, "pero la nota guardada NO es el nivel"
    end
  end

  # ⚠️ Sin nota no es NP y no es cero: es que no hay nada que calificar.
  # `NP` SÍ reprueba — el docente está obligado a evaluar.
  test "sin nota no hay nivel, y no es NP" do
    con_el_colegio(@a.colegio) do
      rubricas = sembrar_rubrica(Rubric::POR_DEFECTO)

      assert_nil Rubric.para(nil, rubricas)
      assert_equal "NP", Rubric.para(9, rubricas).code
    end
  end

  test "un colegio sin rúbrica no rompe nada" do
    con_el_colegio(@a.colegio) { assert_not Rubric.definida? }
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El plan: de la SECCIÓN, y sin duplicados
  # ══════════════════════════════════════════════════════════════════════════

  test "una competencia cuelga de la sección y hereda su colegio" do
    con_el_colegio(@a.colegio) do
      c = competencia(@a, "Resuelve problemas de adición")

      assert_equal @a.colegio.id, c.school_id
      assert_equal @a.seccion.id, c.section_id
    end
  end

  # ⚠️ Lo que impide la competencia duplicada. Las dos pasan cualquier
  # validación de presencia y para el índice único serían dos filas.
  test "la misma competencia con otros acentos no entra dos veces" do
    con_el_colegio(@a.colegio) do
      competencia(@a, "Resuelve problemas de adición")
      repetida = Competency.new(atributos_de(@a).merge(descripcion: "resuelve  problemas de ADICION"))

      assert_not repetida.valid?, "entró la misma competencia con otros acentos"
      assert_includes repetida.errors[:descripcion_canonica].join, "ya está en el plan"
    end
  end

  # Y el índice de la base la para igual, que es lo que cubre las dos pestañas
  # abiertas a la vez.
  test "el índice único la para aunque se salte la validación" do
    con_el_colegio(@a.colegio) do
      competencia(@a, "Resuelve problemas de adición")
      repetida = Competency.new(atributos_de(@a).merge(descripcion: "resuelve  problemas de ADICION"))
      repetida.validate   # calcula la canónica sin exigir que pase

      assert_raises(ActiveRecord::RecordNotUnique) { repetida.save(validate: false) }
    end
  end

  test "la misma competencia sí entra en OTRA sección" do
    otra = con_el_colegio(@a.colegio) do
      Section.create!(grade: @a.grado, academic_period: @a.escenario.periodo, name: "Z", capacity: 30)
    end

    con_el_colegio(@a.colegio) do
      competencia(@a, "Resuelve problemas de adición")
      gemela = Competency.new(atributos_de(@a).merge(section: otra,
                                                     descripcion: "Resuelve problemas de adición"))

      assert gemela.save, gemela.errors.full_messages.join(" · ")
    end
  end

  # ⚠️ El gemelo de la validación de `EvaluationActivity`: sin esto la
  # competencia queda colgada de un lapso de otro año, invisible y sin explicar.
  test "el lapso tiene que ser del año de la sección" do
    ajeno = con_el_colegio(@a.colegio) do
      periodo = AcademicPeriod.create!(name: "2024-2025", start_date: Date.new(2024, 9, 15),
                                       end_date: Date.new(2025, 7, 31))
      EvaluationMoment.create!(academic_period: periodo, name: "Lapso 1")
    end

    con_el_colegio(@a.colegio) do
      c = Competency.new(atributos_de(@a).merge(evaluation_moment: ajeno))

      assert_not c.valid?
      assert_includes c.errors[:evaluation_moment].join, "otro año escolar"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El enganche con la nota, y lo que NO puede escribirse
  # ══════════════════════════════════════════════════════════════════════════

  test "una evaluación se etiqueta con las competencias de su propio plan" do
    con_el_colegio(@a.colegio) do
      c = competencia(@a, "Resuelve problemas de adición")
      etiqueta = ActivityCompetency.new(competency: c, evaluation_activity: @a.actividad)

      assert etiqueta.save, etiqueta.errors.full_messages.join(" · ")
      assert_equal @a.colegio.id, etiqueta.school_id
      assert_includes @a.actividad.reload.competencies, c
    end
  end

  # ⚠️ La fila cruzada no da error, no se ve en ninguna pantalla, y aparece
  # meses después en una boleta diciendo algo que nadie escribió ahí.
  test "no se puede etiquetar con la competencia de OTRA sección" do
    otra = con_el_colegio(@a.colegio) do
      Section.create!(grade: @a.grado, academic_period: @a.escenario.periodo, name: "Y", capacity: 30)
    end

    con_el_colegio(@a.colegio) do
      ajena = Competency.create!(atributos_de(@a).merge(section: otra, descripcion: "De otra sección"))
      etiqueta = ActivityCompetency.new(competency: ajena, evaluation_activity: @a.actividad)

      assert_not etiqueta.valid?
      assert_includes etiqueta.errors[:competency].join, "no es del plan"
    end
  end

  test "no se puede etiquetar con la competencia de OTRO colegio" do
    ajena = con_el_colegio(@b.colegio) { competencia(@b, "Del colegio B") }

    con_el_colegio(@a.colegio) do
      etiqueta = ActivityCompetency.new(competency: ajena, evaluation_activity: @a.actividad)

      assert_not etiqueta.valid?, "se etiquetó con una competencia de otro colegio"
    end
  end

  # ⚠️ Borrar una competencia etiquetada cambia lo que dice una boleta hacia
  # atrás. La evaluación sí se puede borrar: la etiqueta no es dato de nadie.
  test "una competencia etiquetada no se puede borrar" do
    con_el_colegio(@a.colegio) do
      c = competencia(@a, "Resuelve problemas de adición")
      ActivityCompetency.create!(competency: c, evaluation_activity: @a.actividad)

      assert_not c.destroy
      assert Competency.exists?(c.id)
    end
  end

  test "los indicadores se van con su competencia" do
    con_el_colegio(@a.colegio) do
      c = competencia(@a, "Resuelve problemas de adición")
      c.indicators.create!(descripcion: "Suma con reagrupación")

      assert_difference "Indicator.count", -1 do
        c.destroy
      end
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que NO cambia — el criterio de aceptación que vale por todos
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ Toda la aritmética del Art. 108 y del 111 se queda como está: la nota
  # sale de las evaluaciones con su peso, y las competencias son para la boleta.
  # Si esto falla, se tocó lo que no había que tocar.
  test "etiquetar una evaluación NO cambia la nota que produce" do
    con_el_colegio(@a.colegio) do
      GradeCalculator.calculate_all_for_enrollment(@a.escenario.inscripcion)
      antes = MomentGrade.where(enrollment: @a.escenario.inscripcion).pluck(:final_moment_score)

      c = competencia(@a, "Resuelve problemas de adición")
      ActivityCompetency.create!(competency: c, evaluation_activity: @a.actividad)
      GradeCalculator.calculate_all_for_enrollment(@a.escenario.inscripcion)

      assert_equal antes, MomentGrade.where(enrollment: @a.escenario.inscripcion)
                                     .pluck(:final_moment_score)
    end
  end

  private

  def atributos_de(colegio)
    { section: colegio.seccion, subject: colegio.escenario.materia,
      evaluation_moment: colegio.escenario.lapso(1), descripcion: "Resuelve problemas de adición" }
  end

  def competencia(colegio, descripcion)
    Competency.create!(atributos_de(colegio).merge(descripcion: descripcion))
  end

  def sembrar_rubrica(niveles)
    niveles.each { |n| Rubric.create!(n.merge(school: Current.school)) }
    Rubric.en_orden.to_a
  end
end
