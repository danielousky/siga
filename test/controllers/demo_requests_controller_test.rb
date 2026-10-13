require "test_helper"

# El formulario de «pedir una demostración» salió (spec
# `docs/specs/del-registro-al-cobro.md`, decisiones 1 y 19): la puerta es el
# registro. Su dirección quedó en buscadores, en mensajes reenviados y en
# marcadores, así que no da 404: lleva a la portada.
class DemoRequestsControllerTest < ActionDispatch::IntegrationTest
  test "la dirección del formulario lleva a la portada, para siempre" do
    get new_demo_request_path

    assert_redirected_to root_path
    assert_response :moved_permanently
  end

  test "y la de las gracias, también" do
    get success_demo_requests_path

    assert_redirected_to root_path
  end

  # ⚠️ Una pestaña que quedó abierta desde antes puede enviar el formulario
  # viejo. No crea nada: nadie va a leer esa solicitud, y fingir que se recibió
  # sería dejar a alguien esperando una llamada.
  test "un envío del formulario viejo no crea ninguna solicitud" do
    assert_no_difference -> { Current.sin_aislamiento { DemoRequest.unscoped.count } } do
      post demo_requests_path, params: { demo_request: { name: "Ana Pérez", institution: "U.E. Prueba",
                                                         phone: "0414-1234567" } }
    end

    assert_redirected_to root_path
    assert_response :see_other
  end

  # Lo que entró antes sigue siendo historia del equipo de SIGA.
  test "las solicitudes que ya existían no se tocan" do
    antes = Current.sin_aislamiento do
      DemoRequest.create!(name: "Yajaira Colmenares", institution: "U.E. Santa Rosa", phone: "0212-9871122")
    end

    get new_demo_request_path

    assert Current.sin_aislamiento { DemoRequest.unscoped.exists?(antes.id) }
  end
end
