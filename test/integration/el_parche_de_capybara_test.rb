require "test_helper"

# `ChromeSinComodin` (en `ApplicationSystemTestCase`) tapa un error de
# Capybara 3.40.0 con Chrome 158: le pasa "*" a `Storage.clearDataForOrigin`
# al terminar cada test, y Chrome ya no lo acepta.
#
# Está escrito para ESA versión. Una nueva puede traer el arreglo
# (teamcapybara/capybara#2865) o cambiar `reset!` por debajo, y el parche
# seguiría ahí sin que nadie supiera si hace falta. Este test obliga a
# mirarlo el día que se sube.
class ElParcheDeCapybaraTest < ActiveSupport::TestCase
  test "el parche de Chrome 158 es para la Capybara instalada" do
    assert_equal "3.40.0", Gem.loaded_specs.fetch("capybara").version.to_s, <<~MSG
      Subió Capybara. Si la nueva ya no le pasa "*" a Storage.clearDataForOrigin
      (teamcapybara/capybara#2865), borre ChromeSinComodin de
      test/application_system_test_case.rb y este test. Si todavía lo pasa,
      cambie aquí la versión.
    MSG
  end
end
