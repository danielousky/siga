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
        institution: "U.E. Ejemplo",
        phone: "0424-5556677",
        current_system: "escritorio"
      } }
    end

    assert_redirected_to success_demo_requests_url
  end

  # El correo dejó de ser obligatorio (MOR-135): en un colegio venezolano el
  # canal es WhatsApp, y muchos no tienen correo institucional.
  test "una solicitud sin correo es válida" do
    assert_difference "DemoRequest.count", 1 do
      post demo_requests_url, params: { demo_request: {
        name: "Ana Pérez", institution: "U.E. Ejemplo", phone: "0412 998 8776"
      } }
    end

    assert_redirected_to success_demo_requests_url
  end

  # El teléfono pasó a ser el obligatorio, por lo mismo.
  test "una solicitud sin teléfono se rechaza y vuelve al formulario" do
    assert_no_difference "DemoRequest.count" do
      post demo_requests_url, params: { demo_request: {
        name: "Ana Pérez", institution: "U.E. Ejemplo", email: "ana@colegio.edu.ve"
      } }
    end

    assert_response :unprocessable_entity
  end

  test "una solicitud sin institución se rechaza y vuelve al formulario" do
    assert_no_difference "DemoRequest.count" do
      post demo_requests_url, params: { demo_request: {
        name: "Ana Pérez", phone: "0424-5556677"
      } }
    end

    assert_response :unprocessable_entity
  end

  # El caso que antes devolvía "Email ya está en uso" al prospecto más caliente
  # que existe: el que escribe dos veces.
  test "pedir la demo dos veces agradece igual y no crea una fila nueva" do
    post demo_requests_url, params: { demo_request: {
      name: "Ana Pérez", institution: "U.E. Ejemplo", phone: "0424-5556677"
    } }

    assert_no_difference "DemoRequest.count" do
      post demo_requests_url, params: { demo_request: {
        name: "Ana Pérez", institution: "U.E. Ejemplo", phone: "+58 424 555 66 77"
      } }
    end

    assert_redirected_to success_demo_requests_url
    assert_equal 2, DemoRequest.find_by(telefono_normalizado: "4245556677").veces
  end

  # Las etiquetas sociales son la única impresión que existe antes del clic,
  # porque el enlace viaja por WhatsApp.
  test "la página pública trae la tarjeta social completa y absoluta" do
    get new_demo_request_url

    assert_select "meta[property='og:title']"
    assert_select "meta[property='og:description']"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"

    imagen = css_select("meta[property='og:image']").first["content"]
    assert imagen.start_with?("http"), "og:image tiene que ser absoluta, era #{imagen}"
  end

  # `autofocus` en un teléfono abre el teclado al cargar y tapa la página.
  test "el formulario no roba el foco al cargar" do
    get new_demo_request_url

    assert_select "[autofocus]", false, "ningún campo debe traer autofocus"
    assert_select "input[autocomplete='tel']"
    assert_select "input[autocomplete='organization']"
  end
end
