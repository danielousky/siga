require "test_helper"

# La versión del producto (`Siga::VERSION`).
#
# ## Por qué se prueba una constante
#
# Porque tiene que coincidir con TRES cosas que viven aparte: el CHANGELOG, el
# tag de git y lo que se ve en pantalla. Subir el número y olvidar la entrada
# —o al revés— no rompe nada: deja un colegio reportando «la 0.9.0» sin que
# nadie sepa qué había dentro.
class VersionTest < ActionDispatch::IntegrationTest
  CAMBIOS = Rails.root.join("CHANGELOG.md")

  test "la versión tiene la forma de SemVer" do
    assert_match(/\A\d+\.\d+\.\d+\z/, Siga::VERSION,
                 "es MAYOR.MENOR.PARCHE, sin sufijos ni v delante")
  end

  # ⚠️ Lo que impide que el número y la lista se separen. Es la única manera de
  # que «la 0.9.0» signifique algo cuando un colegio la nombre.
  test "el CHANGELOG tiene la entrada de esta versión" do
    assert_match(/^## #{Regexp.escape(Siga::VERSION)} — /, CAMBIOS.read,
                 "falta «## #{Siga::VERSION} — <fecha>» en el CHANGELOG")
  end

  # ⚠️ A la vista, no escondida: cuando un colegio reporta algo, lo primero que
  # hay que saber es qué versión estaba mirando.
  test "la versión se ve en el pie de la portada" do
    get root_path

    assert_select ".portada-pie-version", "v#{Siga::VERSION}"
  end

  # ⚠️ DOS versiones, y no son lo mismo: `version` es qué producto es y
  # `revision` es qué build corre. Con una sola, una versión son cuarenta
  # builds distintos y un reporte no se puede atar a un commit.
  test "salud devuelve la del producto y la del build por separado" do
    get salud_path

    datos = JSON.parse(response.body)
    assert_equal Siga::VERSION, datos["version"]
    assert datos.key?("revision"), "falta la revisión del build"
  end
end
