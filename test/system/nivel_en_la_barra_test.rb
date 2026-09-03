require "application_system_test_case"

# El selector de nivel se envía SOLO al cambiar.
#
# ## Por qué esto necesita un navegador de verdad
#
# El formulario no tiene botón: lo manda `auto-envio`, un controlador de
# Stimulus. Y Stimulus ya falló en silencio en este proyecto por dos motivos
# distintos —un target fuera del elemento del controlador, y un `pin` que
# faltaba en el importmap— que **no se ven leyendo el HTML**: el marcado sale
# perfecto, el `data-controller` está puesto, y no pasa nada al tocarlo.
#
# Un test de integración haría el POST a mano y pasaría con el JavaScript roto.
class NivelEnLaBarraTest < ApplicationSystemTestCase
  setup do
    @a, _b = dos_colegios_completos
    con_el_colegio(@a.colegio) { Grade.create!(school: @a.colegio, name: "6to Grado") }
    entrar_como(@a.director)
  end

  test "elegir un nivel recarga la pantalla filtrada, sin tocar ningún botón" do
    visit grades_path
    assert_text @a.grado.name
    assert_text "6to Grado"

    select "Primaria", from: "nivel"

    # Si el auto-envío no dispara, la página no cambia y esto falla.
    assert_text "6to Grado"
    assert_no_text @a.grado.name
    assert_selector ".listado-escala-nivel", text: "de Primaria"
  end

  test "volver a «Todos los niveles» devuelve todo" do
    visit grades_path
    select "Primaria", from: "nivel"
    assert_no_text @a.grado.name

    select "Todos los niveles", from: "nivel"
    assert_text @a.grado.name
    assert_text "6to Grado"
  end
end
