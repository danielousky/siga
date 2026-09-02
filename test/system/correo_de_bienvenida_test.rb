require "application_system_test_case"

# Cómo se VE el correo de bienvenida (MOR-206).
#
# ⚠️ Un correo no se revisa leyendo su HTML. Este test lo abre en un navegador
# de verdad, a 600 px y a 380 px —el ancho de un teléfono, que es por donde la
# mitad de los directores lo va a abrir— y comprueba que no se corra de lado.
class CorreoDeBienvenidaTest < ApplicationSystemTestCase
  test "el correo se ve, y no se corre de lado en un teléfono" do
    correo = BienvenidaMailer.cuenta_creada(
      User.new(first_name: "YOLEIMA", email: "yoleima@sucolegio.edu")
    )
    archivo = Rails.root.join("tmp/correo_bienvenida.html")
    archivo.write(correo.html_part.body.to_s)

    [ 600, 380 ].each do |ancho|
      page.driver.browser.manage.window.resize_to(ancho, 900)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                      width: ancho, height: 900,
                                      deviceScaleFactor: 0, mobile: ancho < 500)
      visit "file://#{archivo}"

      sobra = page.evaluate_script(
        "document.documentElement.scrollWidth - document.documentElement.clientWidth")
      assert_equal 0, sobra, "a #{ancho}px el correo se corre #{sobra}px de lado"

      # El subtítulo del banner va en versalitas por CSS, así que el texto que
      # el navegador reporta viene en mayúscula.
      assert_text(/Sistema Integrado de Gestión Académica/i)
      assert_text "Bienvenido a SIGA, Yoleima"
      assert_selector "a", text: "Entrar a SIGA"
    end
  ensure
    Rails.root.join("tmp/correo_bienvenida.html").delete rescue nil
  end
end
