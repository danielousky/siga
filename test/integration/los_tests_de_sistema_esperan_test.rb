require "test_helper"

# Un test de sistema no CUENTA sin esperar.
#
# ## Por qué
#
# `all(…)` mira la página una sola vez, y solo ve lo visible. Lo que entra con
# una animación arranca en `opacity: 0` (`plan-aparece`), y en ese primer
# cuadro Capybara no lo ve:
#
#     assert_equal 3, all(".plan-indicador").size     ✗  ve 2 si mira en ese cuadro
#     assert_selector ".plan-indicador", count: 3     ✓  espera a que sean 3
#
# ⚠️ No falla en una máquina rápida. Falló en GitHub, dos corridas de cinco con
# el mismo código (5 de octubre de 2026), y un test que falla a veces es peor
# que uno que falla siempre: enseña a no mirar el rojo.
class LosTestsDeSistemaEsperanTest < ActiveSupport::TestCase
  CUENTA = /\.(?:size|count|length)\b/

  test "ningún test de sistema cuenta elementos sin esperar" do
    sin_esperar = Rails.root.glob("test/system/**/*_test.rb").flat_map do |archivo|
      lineas = archivo.readlines

      lineas.each_with_index.filter_map do |linea, indice|
        next if linea.lstrip.start_with?("#")

        "#{archivo.relative_path_from(Rails.root)}:#{indice + 1}  #{linea.strip}" if linea.match?(conteo_en(lineas))
      end
    end

    assert_empty sin_esperar,
                 "Un conteo que no espera ve el primer cuadro de una animación, donde lo nuevo " \
                 "todavía es transparente. Usa `assert_selector …, count: n`:\n  #{sin_esperar.join("\n  ")}"
  end

  private

  # `all(…).size`, y también el conteo sobre un ayudante que devuelve `all(…)`
  # —`def filas = all(".fila")` y, más abajo, `filas.size`—, que es la forma en
  # que el descuido se esconde.
  def conteo_en(lineas)
    ayudantes = lineas.filter_map { |linea| linea[/def (\w+)\s*=\s*(?:page\.)?all\(/, 1] }

    Regexp.union(/\ball\(.*\)#{CUENTA}/, *ayudantes.map { |nombre| /\b#{nombre}#{CUENTA}/ })
  end
end
