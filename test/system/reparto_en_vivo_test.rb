require "application_system_test_case"

# El 100 % del lapso, moviéndose como un todo (QA del 8 de septiembre).
#
# Daniel, sobre el deslizador del formulario: *«no me debería permitir pasar
# del porcentaje que supere los 100 %, eso es un error, debería poder jugar con
# lo que me queda»*. Y sobre el plan: *«ese porcentaje debería estar
# directamente aquí y moverse dinámicamente unos con otros, de modo que vea
# cuánto % llevo y cuánto % me queda… no ver el porcentaje aislado sino como un
# todo»*.
#
# ⚠️ Se prueba en un navegador de verdad: todo esto vive en Stimulus. Un test
# de integración ve el HTML inicial —que es correcto— y no ve nada de lo que
# pasa al escribir, que es justamente lo que se pidió.
class RepartoEnVivoSystemTest < ApplicationSystemTestCase
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)
    @taller, @examen = con_el_colegio(@a.colegio) do
      [ actividad(@a.escenario, lapso: @lapso, peso: 30, descripcion: "Taller"),
        actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen") ]
    end
    entrar_como @a.profesor
  end

  def ir_al_plan
    visit planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
  end

  def campo_de(evaluacion)
    find(".plan-evaluacion-peso-campo[data-id='#{evaluacion.id}']")
  end

  test "al escribir un peso, la cuenta y el hueco se mueven con él" do
    ir_al_plan
    assert_text "30 % sin repartir"

    campo_de(@taller).set("50")

    # 50 + 40 = 90: quedan 10.
    assert_text "10 % sin repartir"
    assert_selector ".plan-ponderacion-cuenta", text: "90 %"
  end

  test "cerrar en 100 lo dice, y ahí sí se puede guardar" do
    ir_al_plan
    campo_de(@taller).set("60")

    assert_text "cierra en 100 %"
    click_on "Guardar el reparto"

    assert_text "El lapso cierra en 100 %"
    assert_equal 60, con_el_colegio(@a.colegio) { @taller.reload.weight_percentage.to_i }
  end

  # ⚠️ El botón no está mientras nada cambió: uno que no tiene nada que guardar
  # invita a apretarlo para averiguar qué hace.
  test "el botón de guardar aparece solo cuando algo cambió" do
    ir_al_plan
    assert_no_selector "button", text: "Guardar el reparto"

    campo_de(@taller).set("35")
    assert_selector "button", text: "Guardar el reparto"
  end

  # Pasarse no se puede guardar, y se dice cuánto sobra: el profesor tiene que
  # poder VER el exceso para saber de dónde quitarlo.
  test "pasarse de 100 esconde el botón y dice cuánto sobra" do
    ir_al_plan
    campo_de(@taller).set("90")

    assert_text "se pasa por 30 %"
    assert_text "Quita 30 % de algún lado"
    assert_no_selector "button", text: "Guardar el reparto"
  end

  # ⚠️ El recorte va al SALIR del campo, no al escribir: recortando mientras se
  # teclea, escribir «40» en un hueco de 25 convierte el 4 en 25 → «254».
  test "al salir del campo, el exceso se recorta a lo que cabe" do
    ir_al_plan
    campo_de(@taller).set("95")
    find(".plan-ponderacion-titulo").click   # sacar el foco

    assert_equal "60", campo_de(@taller).value, "60 + 40 = 100"
  end

  # ── Y el deslizador del formulario ──────────────────────────────────────
  test "el deslizador no llega a proponer un reparto imposible" do
    visit new_evaluation_activity_path(asignacion: "#{@a.seccion.id}:#{@a.escenario.materia.id}",
                                       lapso: @lapso.id)

    # 30 + 40 comprometidos: el tope del deslizador es 30, no 100.
    assert_equal "30", find(".campo-rango-barra")[:max]
  end
end
