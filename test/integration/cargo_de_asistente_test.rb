require "test_helper"

# El asistente de dirección puede trabajar (MOR-208).
#
# Daniel, definiendo el registro: *«puedes preguntarle el cargo para saber si es
# director o asistente»*. O sea que un asistente puede ser el ÚNICO usuario de un
# colegio — y un colegio cuyo único usuario no puede configurarlo está roto antes
# de empezar.
#
# ⚠️ Un rol nuevo que no aparece en ninguna lista de permisos es exactamente eso:
# una persona que entra y no puede hacer nada, sin ningún error que lo explique.
class CargoDeAsistenteTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    @asistente = con_el_colegio(@a.colegio) do
      persona = User.create!(first_name: "Ana", last_name: "Suárez",
                             email: "asistente@bolivar.test", password: "clave-larga-1",
                             document: "27182818", document_type: :cedula_v)
      Admin.create!(user: persona, school: @a.colegio, role: :asistente)
      persona
    end
  end

  test "el cargo existe en el enum" do
    assert_includes Admin.roles.keys, "asistente"
  end

  # ⚠️ El valor es 5, el siguiente libre. Renumerar un enum de enteros rompe las
  # filas ya guardadas, que apuntan al número y no al nombre.
  test "no se renumeró ningún rol existente" do
    assert_equal({ "desarrollador" => 0, "director" => 1, "finanzas" => 2,
                   "coordinador" => 3, "secretaria" => 4, "asistente" => 5 }, Admin.roles)
  end

  test "el registro ofrece director, asistente y otro" do
    assert_equal %w[director asistente otro], Admin::CARGOS_AL_REGISTRARSE.keys
  end

  # ⚠️ «Otro cargo» mapeaba a `coordinador`, que NO está en `DIRECCION`: quien
  # lo elegía al registrar su colegio quedaba encerrada —sin poder cargar
  # profesores ni entrar a `/administradores` para corregirse el rol—. Le pasó
  # a la primera directora real.
  test "las tres opciones del registro dan permisos de dirección" do
    Admin::CARGOS_AL_REGISTRARSE.each_key do |cargo|
      assert_includes ApplicationController::DIRECCION, Admin.rol_al_registrarse(cargo),
                      "«#{Admin::CARGOS_AL_REGISTRARSE[cargo]}» deja sin permisos a quien registra"
    end
  end

  test "un asistente puede administrar su colegio" do
    sign_in @asistente

    { "alumnos" => students_path, "profesores" => teachers_path,
      "secciones" => sections_path, "grados" => grades_path,
      "años escolares" => academic_periods_path,
      "administradores" => admins_path }.each do |que, ruta|
      get ruta
      assert_response :success, "un asistente no puede entrar a #{que}"
    end
  end

  # ⚠️ El menú y el controller tienen que decir lo MISMO: dos listas de roles se
  # desparejan, y el síntoma es una entrada de menú que lleva a un «esta parte la
  # administra la dirección».
  test "lo que el menú ofrece es lo que el controller deja entrar" do
    sign_in @asistente
    get dashboards_administrador_path

    css_select(".sidebar-index a[href]").map { |a| a["href"] }.uniq.each do |ruta|
      next if ruta.start_with?("http") || ruta == "/"

      get ruta
      # ⚠️ Un redirect no es un fallo: `/asistencia` con una sola sección lleva
      # derecho a su planilla, y eso es lo correcto. Lo que se prohíbe es que
      # termine en un «esta parte la administra la dirección».
      2.times { response.redirect? ? follow_redirect! : break }

      assert_response :success, "el menú ofrece #{ruta} y el controller no deja entrar"
      assert_no_match(/administra la dirección|no autorizado/i, response.body,
                      "el menú ofrece #{ruta} y el controller lo rechaza")
    end
  end
end
