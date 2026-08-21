require "test_helper"

# Que se VEA quién no puede entrar todavía (MOR-142).
#
# Desde `MOR-142` un representante puede existir sin correo y sin contraseña. Eso
# está bien —el importador los va a cargar así por centenas—, pero una celda
# vacía en el listado no dice nada: la secretaria se entera de que falta el
# correo cuando la mamá llama preguntando por qué no entra.
#
# El estado se dice en palabras y en gris. Gris y no ámbar a propósito: que
# todavía no haya activado su acceso es un HECHO, no una alerta — la regla de
# color reserva el ámbar para lo que exige actuar ya.
class QuienNoPuedeEntrarSeVeTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director

    con_el_colegio(@a.colegio) do
      @sin_correo = representante("Yolanda", "Guerra", "99887766")
      @activa     = representante("Carmen", "López", "99887767",
                                  email: "carmen@familia.test", password: "123123")
    end
  end

  def representante(nombre, apellido, documento, **credenciales)
    Representative.create!(
      school: @a.colegio, phone: "0416-3334455",
      user: User.create!(first_name: nombre, last_name: apellido,
                         document: documento, document_type: :cedula_v, **credenciales)
    )
  end

  test "el listado marca a quien no tiene correo" do
    get representatives_path

    assert_response :success
    assert_select "span.nota-pendiente", text: "Sin correo"
    assert_select "td", text: /carmen@familia\.test/
  end

  test "la ficha de quien no activó su acceso lo dice" do
    get representative_path(@sin_correo)

    assert_response :success
    assert_select "span.estado.estado--inactivo", text: "Sin activar"
  end

  test "la ficha de quien ya tiene contraseña lo dice" do
    get representative_path(@activa)

    assert_response :success
    assert_select "span.estado.estado--al-dia", text: "Activo"
  end
end
