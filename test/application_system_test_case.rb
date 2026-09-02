require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # ⚠️ `headless_chrome` y no `chrome`: en CI no hay pantalla, y abrir una
  # ventana real en cada corrida local es ruido.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Entrar por el formulario, como una persona. Un test de sistema que se saltea
  # el login no prueba la pantalla que de verdad se ve al llegar.
  #
  # ⚠️ El submit se busca por su CLASE, no por su texto. «Iniciar sesión» es
  # también el `h1` de la página, así que `click_on` con ese texto es ambiguo:
  # Capybara elige uno de los dos y, cuando elige el título, no pasa nada — la
  # sesión no se abre y las visitas siguientes rebotan al login **sin error**.
  #
  # Y esperar el resultado no es opcional: `visit` no espera a que el submit
  # termine, así que sin esto la primera medición sale sobre la página vieja.
  def entrar_como(usuario, clave = "123123")
    visit new_user_session_path
    fill_in "user_email", with: usuario.email
    fill_in "user_password", with: clave
    find(".acceso-enviar").click

    assert_no_current_path new_user_session_path, wait: 5
  end
end
