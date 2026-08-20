require "test_helper"

# El registro público no existe. Las cuentas las da de alta el colegio.
#
# Ver MOR-101.
class RegistroCerradoTest < ActionDispatch::IntegrationTest
  test "no hay ruta de registro público" do
    # Ni el helper existe: la ruta no está definida, no está solo escondida.
    assert_not Rails.application.routes.url_helpers.respond_to?(:new_user_registration_path)

    # Rails rescata el RoutingError y lo devuelve como 404; no lo propaga.
    get "/users/sign_up"
    assert_response :not_found
  end

  test "POST a /users tampoco crea una cuenta" do
    assert_no_difference -> { Current.sin_aislamiento { User.count } } do
      post "/users", params: { user: { email: "colado@ejemplo.com", password: "123123456", password_confirmation: "123123456" } }
    end

    assert_response :not_found
  end

  test "la pantalla de login no ofrece crear cuenta" do
    get new_user_session_url

    assert_response :success
    assert_no_match(/Crear Cuenta/, response.body)
    assert_no_match(/sign_up/, response.body)
  end

  # `:recoverable` es un módulo distinto de `:registerable` y sí hace falta: es
  # el único camino de un profesor que olvidó su contraseña un domingo.
  test "olvidé mi contraseña sigue funcionando" do
    get new_user_password_url

    assert_response :success
    assert_match(/contraseña/i, response.body)
  end

  test "un usuario logueado sí puede cambiarse la contraseña" do
    esc = escenario_academico(alumnos: 1)
    sign_in esc.alumno.user

    get edit_user_registration_url
    assert_response :success

    put user_registration_url, params: { user: {
      password: "clavenueva9", password_confirmation: "clavenueva9", current_password: "123123"
    } }

    assert_redirected_to root_path
    assert esc.alumno.user.reload.valid_password?("clavenueva9")
  end

  # Que un alumno se borre a sí mismo de un sistema académico no es una función.
  test "nadie puede darse de baja solo" do
    esc = escenario_academico(alumnos: 1)
    sign_in esc.alumno.user

    assert_no_difference -> { Current.sin_aislamiento { User.count } } do
      delete "/cuenta"
    end

    assert_response :not_found
  end

  # El punto 5 del issue: no cerrar la puerta sin abrir la que corresponde.
  test "el colegio sí tiene por dónde dar de alta a su gente" do
    esc = escenario_academico(alumnos: 1)

    director = con_el_colegio(esc.colegio) do
      usuario = User.create!(first_name: "Dire", last_name: "Ctor",
                             email: "dir.#{esc.colegio.id}@test.edu", password: "123123",
                        document: "V-#{"dir.#{esc.colegio.id}@test.edu".bytes.sum}")
      Admin.create!(user: usuario, school: esc.colegio, role: :director)
      usuario
    end

    sign_in director

    [students_new_path = new_student_url, new_teacher_url, new_admin_url].each do |ruta|
      get ruta
      assert_response :success, "#{ruta} tiene que estar disponible para dar de alta"
    end
  end
end
