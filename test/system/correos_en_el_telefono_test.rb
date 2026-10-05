require "application_system_test_case"

# Cómo se VEN los correos de SIGA, en el escritorio y en un teléfono.
#
# ⚠️ Un correo no se revisa leyendo su HTML. Este test abre los ocho en un
# navegador de verdad, a 600 px y a 380 px —el ancho de un teléfono, que es por
# donde la mitad de las familias los va a abrir— y comprueba que ninguno se
# corra de lado.
#
# Nació con el de bienvenida (MOR-206), cuando era el único con diseño. Desde
# el 5 de octubre de 2026 los ocho comparten plantilla, así que los ocho se
# miran.
#
# ⚠️ Las imágenes acá NO cargan: apuntan a un servidor que en el test no
# existe. No es un defecto del test — es el caso de Outlook de escritorio, que
# las bloquea hasta que la persona acepta, y la cabecera tiene que aguantarlo.
class CorreosEnElTelefonoTest < ApplicationSystemTestCase
  include CorreosDeMuestra

  setup { preparar_los_correos }

  test "ninguno de los ocho se corre de lado, ni en el escritorio ni en el teléfono" do
    todos_los_correos.each do |cual, correo|
      abrir(correo) do |ancho|
        sobra = page.evaluate_script(
          "document.documentElement.scrollWidth - document.documentElement.clientWidth")

        assert_equal 0, sobra, "«#{cual}», a #{ancho} px, se corre #{sobra} px de lado"
      end
    end
  end

  # Con el escudo, la cabecera lleva una ficha más. Es donde se apretaría.
  test "con el escudo del colegio en la cabecera, tampoco" do
    ponerle_escudo_al_colegio

    correos_del_colegio.each do |cual, correo|
      abrir(correo) do |ancho|
        sobra = page.evaluate_script(
          "document.documentElement.scrollWidth - document.documentElement.clientWidth")

        assert_equal 0, sobra, "«#{cual}», con escudo y a #{ancho} px, se corre #{sobra} px de lado"
        assert_selector "img[alt='Escudo de #{@colegio.name}']"
      end
    end
  end

  test "el del colegio dice de quién es, y el de SIGA también" do
    correos = todos_los_correos

    abrir(correos["boletín disponible"]) do
      assert_text @colegio.name
      assert_text "Enviado con SIGA"
      assert_selector "a", text: "Ver el boletín"
    end

    abrir(correos["bienvenida"]) do
      # El subtítulo de la cabecera va en versalitas por CSS, así que el texto
      # que el navegador reporta viene en mayúscula.
      assert_text(/Sistema Integrado de Gestión Académica/i)
      assert_text "Bienvenido a SIGA, Yoleima"
      assert_selector "a", text: "Entrar a SIGA"
    end
  end

  private

  # Abre el correo a los dos anchos y cede el control en cada uno.
  def abrir(correo)
    archivo = Rails.root.join("tmp/correo-de-prueba-#{SecureRandom.hex(4)}.html")
    archivo.write(html_de(correo))

    [ 600, 380 ].each do |ancho|
      page.driver.browser.manage.window.resize_to(ancho, 900)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                      width: ancho, height: 900,
                                      deviceScaleFactor: 0, mobile: ancho < 500)
      visit "file://#{archivo}"
      tomar_captura(correo, ancho)

      yield ancho
    end
  ensure
    archivo&.delete rescue nil
  end

  # Con `CAPTURAS=una/carpeta`, deja una imagen de cada correo a cada ancho.
  # Es para MIRARLOS: un test dice que no se corre de lado, no que se ve bien.
  def tomar_captura(correo, ancho)
    carpeta = ENV["CAPTURAS"].presence or return

    nombre = "#{correo.subject.parameterize[0, 50]}-#{ancho}.png"
    page.save_screenshot(File.join(carpeta, nombre))
  end
end
