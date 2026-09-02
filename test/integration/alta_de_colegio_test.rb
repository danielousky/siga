require "test_helper"

# Vender SIGA a un colegio, de punta a punta (MOR-133 + MOR-143).
#
# Es el primer minuto de vida de un cliente, y hasta ahora terminaba en un
# callejón: el alta le ponía al director una contraseña aleatoria de 14
# caracteres que **nadie conocía** —ni él ni quien lo dio de alta—, y la nota del
# propio formulario lo admitía: "hay que mandarle un enlace para que la defina.
# Eso llega cuando haya correo configurado".
#
# Con `MOR-143` el enlace ya existe, así que el alta lo genera y lo muestra.
class AltaDeColegioTest < ActionDispatch::IntegrationTest
  setup do
    @fundador = User.create!(first_name: "Equipo", last_name: "SIGA", password: "123123",
                             email: "fundador@siga.app", document: "V-90000001",
                             document_type: :cedula_v)
    SigaStaff.create!(user: @fundador, role: :fundador)
    sign_in @fundador
  end

  COLEGIO = { name: "U.E. Nueva Esperanza", dea_code: "S0001",
              location: "Guanare" }.freeze
  DIRECTORA = { first_name: "Rosa", last_name: "Peña", second_last_name: "Guillén",
                email: "rosa.pena@nuevaesperanza.edu", document: "V-14.222.333",
                document_type: "cedula_v" }.freeze

  def dar_de_alta
    post siga_colegios_path, params: { school: COLEGIO, director: DIRECTORA }
  end

  test "el alta crea el colegio, su directora y el enlace para que entre" do
    assert_emails 1 do
      dar_de_alta
    end

    assert_response :redirect
    codigo = flash[:codigo]

    assert_not_nil codigo, "el alta tiene que dejar el enlace a la vista"

    follow_redirect!

    assert_response :success
    assert_select "p.mono", text: /#{Regexp.escape(codigo)}/
    assert_select "span.siga-estado--cancelada", text: "Sin activar"
  end

  # Antes quedaba con una contraseña aleatoria que nadie conocía: la cuenta
  # nacía inutilizable, pero pareciendo utilizable.
  test "la directora nace sin contraseña" do
    dar_de_alta
    directora = Current.sin_aislamiento { User.find_by(email: DIRECTORA[:email]) }

    assert_not directora.puede_entrar?
  end

  test "el segundo apellido de la directora se guarda" do
    dar_de_alta
    directora = Current.sin_aislamiento { User.find_by(email: DIRECTORA[:email]) }

    assert_equal "GUILLÉN", directora.second_last_name, "en la base, en mayúscula"
    assert_equal "Peña Guillén", directora.apellidos
  end

  # La cédula llega del formulario como la escribe una persona. En la base tiene
  # que quedar normalizada o la misma directora se duplica al reaparecer en otro
  # colegio (MOR-142).
  test "la cédula se guarda normalizada" do
    dar_de_alta
    directora = Current.sin_aislamiento { User.find_by(email: DIRECTORA[:email]) }

    assert_equal "14222333", directora.document
  end

  test "con el enlace, la directora entra y ve SU colegio" do
    dar_de_alta
    codigo = flash[:codigo]
    delete destroy_user_session_path

    patch activacion_path, params: { user: { token: codigo, password: "clave-nueva",
                                             password_confirmation: "clave-nueva" } }

    assert_response :redirect
    follow_redirect!

    assert_response :success
    # ⚠️ En MAYÚSCULA (MOR-201): así se guarda y así se muestra el nombre de un
    # colegio, porque el Tipo Título rompería la sigla inicial («U.e.»).
    assert_match(/#{Regexp.escape(COLEGIO[:name].upcase)}/, response.body,
                 "tiene que caer en el panel de su propio colegio")
  end

  test "quien no es fundador no da de alta colegios" do
    delete destroy_user_session_path
    operaciones = User.create!(first_name: "Ana", last_name: "Ops", password: "123123",
                               email: "ops@siga.app", document: "V-90000002",
                               document_type: :cedula_v)
    SigaStaff.create!(user: operaciones, role: :operaciones)
    sign_in operaciones

    assert_no_difference -> { Current.sin_aislamiento { School.count } } do
      dar_de_alta
    end
  end
end
