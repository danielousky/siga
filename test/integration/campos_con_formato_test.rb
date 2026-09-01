require "test_helper"

# Los campos que se escriben con una forma: teléfono y búsqueda sin acentos.
#
# ## Por qué un test que mira el HTML y no el comportamiento
#
# Las dos reglas viven en JavaScript —el filtrado se hace mientras se teclea, en
# el navegador— y esta suite no corre un navegador. Lo que sí se puede afirmar es
# que **el enganche está puesto**: que el campo declara su controlador y su
# acción. Si alguien agrega un teléfono nuevo y se olvida, esto lo dice.
#
# Es la misma clase de test que el de la regla de color: no comprueba cómo se ve,
# comprueba que la pieza correcta esté conectada.
class CamposConFormatoTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  # Daniel: «el teléfono también debería ser solo con el formato de teléfono
  # 04XX-0001122».
  test "todo campo de teléfono se formatea solo" do
    sueltos = { "representante" => new_representative_path,
                "identidad del colegio" => colegio_path }.filter_map do |quien, ruta|
      get ruta
      campos = css_select("input[type=tel]")
      next "#{quien}: no hay ningún campo de teléfono" if campos.empty?

      sin_formato = campos.reject { |c| c["data-controller"].to_s.include?("campo-telefono") }
      next if sin_formato.empty?

      "#{quien}: #{sin_formato.map { |c| c['name'] }.join(', ')}"
    end

    assert_empty sueltos, "teléfonos que se escriben a mano:\n  " + sueltos.join("\n  ")
  end

  # El ejemplo tiene que enseñar una forma que el campo ACEPTE. El del colegio
  # decía «0212-555-1234», con un guion de más.
  test "el ejemplo del teléfono tiene la forma que el campo produce" do
    malos = [ new_representative_path, colegio_path ].flat_map do |ruta|
      get ruta
      css_select("input[type=tel]").filter_map do |campo|
        ejemplo = campo["placeholder"]
        next if ejemplo.blank? || ejemplo.match?(/\A\d{4}-\d{7}\z/)

        "#{campo['name']}: «#{ejemplo}»"
      end
    end

    assert_empty malos, "el ejemplo enseña una forma que el campo no acepta:\n  " + malos.join("\n  ")
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Buscar sin acentos, también en el navegador
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Daniel: «el buscador de los representados no encuentra las coincidencias sin
  # acentos. Hay otro buscador que ya contemplaba ese tipo de coincidencias. Hay
  # que unificarlo».
  #
  # La regla estaba escrita —en Ruby, en `BusquedaSinAcentos`— pero solo del lado
  # del servidor. `lib/sin_acentos.js` es su mitad JavaScript.

  test "el filtro del navegador usa la misma regla que el del servidor" do
    filtro = Rails.root.join("app/javascript/controllers/filtro_local_controller.js").read

    assert_includes filtro, "lib/sin_acentos",
                    "el filtro local compara sin ignorar acentos: «sofia» no encuentra a Sofía"
    assert_not filtro.match?(/textContent\.toLowerCase\(\)\.includes/),
               "quedó la comparación vieja, que ignora mayúsculas pero no tildes"
  end

  # ⚠️ Sin el `pin`, el `import` falla EN SILENCIO en el navegador: el módulo no
  # se resuelve, Stimulus no conecta el controlador, y el filtro deja de andar
  # sin que ningún test del servidor se entere.
  test "el módulo compartido llega al navegador" do
    get new_representative_path

    mapa = response.body[/<script type="importmap"[^>]*>(.*?)<\/script>/m, 1]
    assert mapa, "la página no trae importmap"
    assert_includes JSON.parse(mapa)["imports"].keys, "lib/sin_acentos"
  end

  # Y la regla de Ruby sigue en pie: si alguien la afloja, la mitad JavaScript
  # queda comparando distinto que la otra.
  test "la regla del servidor sigue aplanando la eñe y las tildes" do
    con_el_colegio(@a.colegio) do
      condicion = BusquedaSinAcentos.condicion(%w[users.last_name], "nunez")

      assert condicion.first.include?("translate"),
             "sin `translate` en el SQL, «nunez» no encuentra a Núñez"
    end
  end
end
