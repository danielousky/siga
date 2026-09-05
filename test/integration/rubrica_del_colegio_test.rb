require "test_helper"

# La rúbrica del colegio (MOR-136).
#
# Lo que se prueba es la promesa que hace la pantalla en su primer renglón:
# **cambiar la rúbrica no cambia ninguna nota**. Si eso no fuera cierto, el
# control no podría ser configurable.
class RubricaDelColegioTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos(nivel: :primaria)
  end

  test "un colegio sin rúbrica ve la propuesta, sin que se guarde sola" do
    sign_in @a.director
    get rubrica_path

    assert_response :success
    assert_select ".rubrica-propuesta"
    Rubric::POR_DEFECTO.each { |datos| assert_select "input[value=?]", datos[:code] }

    assert_equal 0, Current.en_el_colegio(@a.colegio) { Rubric.count },
                 "la propuesta se MUESTRA; guardarla es una decisión del colegio"
  end

  test "guarda los cinco niveles de una vez" do
    sign_in @a.director

    patch rubrica_path, params: { school: { rubrics_attributes: atributos_por_defecto } }

    assert_redirected_to rubrica_path
    con_el_colegio(@a.colegio) do
      assert_equal %w[PC PA PI PD NP], Rubric.en_orden.map(&:code)
      assert_equal [ 19, 17, 14, 10, 1 ], Rubric.en_orden.map(&:valor)
    end
  end

  # ⚠️ La promesa de la pantalla, y la que hace que la rúbrica pueda ser
  # configurable: es una MÁSCARA. Si cambiarla reescribiera notas, este control
  # sería una bomba en manos de un director.
  test "cambiar la rúbrica no toca una sola nota" do
    con_el_colegio(@a.colegio) { @a.colegio.restablecer_la_rubrica! }
    antes = con_el_colegio(@a.colegio) { ActivityGrade.order(:id).pluck(:id, :score) }
    assert antes.any?, "el escenario tiene que traer notas o el test no prueba nada"

    sign_in @a.director
    tres = [
      { code: "L", name: "Logrado",      valor: 15 },
      { code: "P", name: "En proceso",   valor: 10 },
      { code: "I", name: "Iniciado",     valor: 1 }
    ]
    patch rubrica_path, params: { school: { rubrics_attributes: tres.each_with_index.to_h { |d, i| [ i.to_s, d ] } } }

    con_el_colegio(@a.colegio) do
      assert_equal antes, ActivityGrade.order(:id).pluck(:id, :score),
                   "cambiar cómo se LEE una nota no puede cambiar la nota"
    end
  end

  # El colegio de tres niveles es un caso real, y era la queja de Cyndi: con
  # tres bandas el 13 y el 17 se leen igual, pero por dentro siguen siendo
  # distintos.
  test "un colegio puede quedarse con tres niveles" do
    con_el_colegio(@a.colegio) { @a.colegio.restablecer_la_rubrica! }
    sign_in @a.director

    atributos = con_el_colegio(@a.colegio) do
      Rubric.en_orden.each_with_index.to_h do |r, i|
        [ i.to_s, { id: r.id, code: r.code, name: r.name, valor: r.valor,
                    _destroy: %w[PA PD].include?(r.code) ? "1" : "0" } ]
      end
    end
    patch rubrica_path, params: { school: { rubrics_attributes: atributos } }

    con_el_colegio(@a.colegio) do
      assert_equal %w[PC PI NP], Rubric.en_orden.map(&:code)
      assert_equal "PI", Rubric.para(17)&.code, "con tres bandas, el 17 y el 14 se leen igual"
      assert_equal "PI", Rubric.para(14)&.code
    end
  end

  # ⚠️ Las bandas son CONTIGUAS por construcción, y es el único argumento a
  # favor de guardar el piso y no el tope: ningún colegio puede dejar un hueco.
  test "ninguna nota del 1 al 20 se queda sin nivel" do
    con_el_colegio(@a.colegio) do
      @a.colegio.restablecer_la_rubrica!
      rubricas = Rubric.en_orden.to_a

      (1..20).each do |nota|
        assert_not_nil Rubric.para(nota, rubricas), "la nota #{nota} quedó sin nivel"
      end
    end
  end

  # ⚠️ Sin nota NO es NP y no es cero: es que nadie evaluó. `NP` reprueba —
  # «el docente está obligado a evaluar»— y confundirlos reprueba a un niño al
  # que nadie le puso nada.
  test "sin nota no hay nivel, y no es el más bajo" do
    con_el_colegio(@a.colegio) do
      @a.colegio.restablecer_la_rubrica!
      assert_nil Rubric.para(nil)
      assert_equal "NP", Rubric.para(1)&.code
    end
  end

  test "restablecer vuelve a los cinco de SIGA" do
    con_el_colegio(@a.colegio) do
      Rubric.create!(code: "X", name: "Lo que sea", valor: 5)
    end
    sign_in @a.director

    post restablecer_rubrica_path

    con_el_colegio(@a.colegio) do
      assert_equal Rubric::POR_DEFECTO.map { |d| d[:code] }, Rubric.en_orden.map(&:code)
    end
  end

  # ⚠️ La rúbrica es del COLEGIO: la de uno no puede leerse desde el otro.
  test "la rúbrica de otro colegio no se ve ni se toca" do
    con_el_colegio(@b.colegio) { @b.colegio.restablecer_la_rubrica! }
    sign_in @a.director

    get rubrica_path

    # ⚠️ El segundo argumento de `assert_select` es el TEXTO esperado, no un
    # mensaje de fallo: la aserción va aparte.
    assert_select ".rubrica-propuesta"
    assert_equal 0, Current.en_el_colegio(@a.colegio) { Rubric.count },
                 "el colegio A no tiene rúbrica: la de B no puede contar como suya"
  end

  test "un profesor no entra a configurar la rúbrica" do
    sign_in @a.profesor
    get rubrica_path

    assert_response :redirect
  end

  private

  def atributos_por_defecto
    Rubric::POR_DEFECTO.each_with_index.to_h { |datos, i| [ i.to_s, datos ] }
  end
end
