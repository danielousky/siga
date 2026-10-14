require "application_system_test_case"

# El botón «Buscar ⌘K» de la barra de arriba SE VE.
#
# Desde que la barra pasó a ser clara (MOR-184) hasta el 14 de octubre de 2026,
# el botón tuvo los colores de la barra oscura de antes: letra blanca
# translúcida sobre un fondo blanco. Estaba ahí y funcionaba —con ⌘K se abría—
# pero nadie lo veía, y el propio CSS decía que existía porque «un atajo
# invisible solo sirve a quien ya sabe que existe».
#
# ⚠️ No falla nada cuando pasa: el HTML es correcto, el botón responde y ningún
# test lo nota. Lo que se mide es lo que ve una persona: el contraste entre la
# letra y el fondo de la barra.
class ElBuscadorSeVeTest < ApplicationSystemTestCase
  test "la letra del buscador contrasta con la barra" do
    a, = dos_colegios_completos
    entrar_como(a.director)
    visit sections_path
    assert_selector ".buscador-disparador"

    contraste = page.evaluate_script(<<~JS)
      (() => {
        const rgb = (c) => c.match(/[\\d.]+/g).map(Number);
        const lum = ([r, g, b]) => {
          const canal = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
          return 0.2126 * canal(r) + 0.7152 * canal(g) + 0.0722 * canal(b);
        };
        // Cada capa se mezcla con la de abajo según su transparencia.
        const sobre = (frente, fondo) => {
          const a = frente[3] === undefined ? 1 : frente[3];
          return [0, 1, 2].map((i) => frente[i] * a + fondo[i] * (1 - a));
        };
        // ⚠️ La letra va sobre el fondo del BOTÓN, y el botón sobre la barra.
        // Contra la barra a secas, un botón oscuro con letra blanca —que se lee
        // perfecto— daría rojo.
        const barra = rgb(getComputedStyle(document.querySelector(".barra-superior")).backgroundColor);
        const estilo = getComputedStyle(document.querySelector(".buscador-disparador"));
        const fondo = sobre(rgb(estilo.backgroundColor), barra);
        const letra = sobre(rgb(estilo.color), fondo);
        const l1 = lum(letra), l2 = lum(fondo);
        return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
      })()
    JS

    # 4,5 es lo que pide WCAG para un texto de este tamaño.
    assert_operator contraste, :>=, 4.5, "la letra del buscador casi no se distingue de la barra (contraste #{contraste.round(2)})"
  end
end
