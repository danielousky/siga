require "test_helper"

# Estos dos tests venían del generador apuntando a rutas que nunca existieron
# (`demo_requests_new_url`, `demo_requests_create_url`). Estaban en rojo desde
# que se creó el módulo. Acá quedan sobre las rutas reales.
class DemoRequestsControllerTest < ActionDispatch::IntegrationTest
  test "el formulario de demo es público: no exige sesión" do
    get new_demo_request_url
    assert_response :success
  end

  test "una solicitud válida se guarda y lleva a la página de gracias" do
    assert_difference "DemoRequest.count", 1 do
      post demo_requests_url, params: { demo_request: {
        name: "Ana Pérez",
        email: "ana@colegio.edu.ve",
        institution: "U.E. Ejemplo",
        current_system: "escritorio"
      } }
    end

    assert_redirected_to success_demo_requests_url
  end

  test "una solicitud sin institución se rechaza y vuelve al formulario" do
    assert_no_difference "DemoRequest.count" do
      post demo_requests_url, params: { demo_request: {
        name: "Ana Pérez",
        email: "ana@colegio.edu.ve"
      } }
    end

    assert_response :unprocessable_entity
  end
end
