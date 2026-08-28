require "test_helper"

# Qué puede y qué no puede hacer alguien con su propia cuenta.
#
# ## ⚠️ Este archivo se llamaba `registro_cerrado_test` y afirmaba lo contrario
#
# `MOR-101` cerró el registro público: cualquiera podía quemar el correo de un
# profesor real registrándolo antes que su colegio, porque `users.email` es único
# en toda la plataforma.
#
# `MOR-158` lo reabre. El riesgo sigue existiendo y se acepta a propósito — la
# decisión de producto es facilidad y velocidad de registro por encima de la
# seguridad, mientras el acceso sea compartir el enlace a mano. Lo que lo hace
# tolerable es el aislamiento: registrarse crea SIEMPRE un colegio nuevo, así que
# el daño máximo es una fila que no ve nada de nadie. Ver `registro_abierto_test`.
#
# Lo que NO se reabrió es lo que sigue probando este archivo, y no es lo mismo.
class RegistroDeCuentasTest < ActionDispatch::IntegrationTest
  # ⚠️ `/users/sign_up` sigue sin existir: la puerta es `/registrarse`.
  #
  # Se mantiene la ruta vieja muerta a propósito para que un enlace guardado de
  # antes no lleve a un formulario distinto del que el producto ofrece hoy.
  test "la puerta es /registrarse, no la de Devise" do
    get "/users/sign_up"
    assert_response :not_found

    get new_user_registration_path
    assert_response :success
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
