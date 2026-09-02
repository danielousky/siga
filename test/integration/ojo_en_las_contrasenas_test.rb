require "test_helper"

# Toda contraseña de la app se puede VER (MOR-176 · MOR-199).
#
# Daniel: «la contraseña (y confirmación) deben tener el toggle-eye», y meses
# después: «el form de la contraseña tampoco tiene el toggle-eye».
#
# La segunda vez fue porque el parcial existía y CUATRO formularios seguían
# escribiendo el campo a mano: el registro, recuperar la contraseña, la ficha de
# la cuenta y —la peor— la activación, que es donde una mamá elige su
# contraseña por primera vez desde el teléfono, sin nadie a quien preguntarle si
# la escribió bien.
class OjoEnLasContrasenasTest < ActiveSupport::TestCase
  # ⚠️ Se comprueba sobre el CÓDIGO y no visitando pantallas: varias de éstas
  # necesitan un token de un solo uso o una sesión particular, y montar eso para
  # cada una convertiría la guarda en algo que nadie mantiene. Lo que hay que
  # sostener es que nadie vuelva a escribir el campo a mano.
  test "ninguna vista escribe un campo de contraseña a mano" do
    a_mano = Dir[Rails.root.join("app/views/**/*.haml")].filter_map do |vista|
      next if vista.end_with?("_campo_de_contrasena.html.haml")
      next unless File.read(vista).include?("password_field")

      vista.sub("#{Rails.root}/app/views/", "")
    end

    assert_empty a_mano,
      "usan `password_field` en vez de `shared/campo_de_contrasena`, así que no " \
      "tienen el ojo:\n  " + a_mano.join("\n  ")
  end
end
