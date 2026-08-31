require "test_helper"

# La ayuda aparece SOLO cuando alguien la pide (MOR-161).
#
# ## Por qué existe este test
#
# Había 102 notas de ayuda en 53 pantallas, todas siempre visibles: dos renglones
# de gris debajo de cada campo. Eso no es guiar, es ruido — y tiene el mismo modo
# de fallar que el panel del director ya tenía escrito: *«un panel que siempre
# dice lo mismo se deja de leer, y el día que dice otra cosa tampoco se lee»*.
#
# Lo que este test sostiene no es el estilo, es la PROMESA: que el «?» sea un
# control de verdad —enfocable, con nombre, y con su texto asociado— y no un
# adorno que solo funciona con el ratón.
class PistasTest < ActionDispatch::IntegrationTest
  test "el «?» es un botón de verdad, con nombre y con su texto asociado" do
    get new_user_registration_path

    assert_response :success
    boton = css_select("button.pista-boton").first
    assert boton, "no hay ninguna pista en el registro"

    assert_equal "button", boton["type"], "sin type=button, dentro de un form ENVÍA"
    assert boton["aria-label"].present?, "un botón con solo un icono necesita nombre accesible"

    destino = boton["popovertarget"]
    assert destino.present?, "el botón no apunta a ningún texto"
    assert_select "##{destino}[popover]", 1,
                  "el texto de la pista no es un popover: sin eso no cierra con esc " \
                  "ni al tocar afuera, y cualquier overflow del formulario lo recorta"
  end

  # ⚠️ Lo que se esconde es la DEFINICIÓN de un campo, no la consecuencia de una
  # decisión. «Sin guía, la asistencia solo la toma la dirección» tiene que
  # seguir leyéndose sin pedirla: quien no la lea decide a ciegas.
  test "la consecuencia de una decisión sigue visible" do
    @a, _b = dos_colegios_completos
    sign_in @a.director

    get new_section_path

    assert_response :success
    assert_select ".nota-ayuda", { minimum: 1 },
                  "se escondió una consecuencia: eso no es ayuda, es información"
    assert_match(/dirección/i, response.body)
  end

  # El texto de la pista viaja en el HTML aunque no se vea. Si alguien lo cargara
  # por JavaScript, un lector de pantalla y un buscador se quedarían sin él.
  test "el texto de la pista está en la página, no se pide después" do
    get new_user_registration_path

    assert_match(/Identifica a la persona en todo el sistema/, response.body)
  end

  # El id sale del texto y no de un aleatorio: con `SecureRandom` cambiaría entre
  # peticiones y cualquier prueba que lo busque por selector sería inestable.
  test "el id de una pista es estable entre peticiones" do
    get new_user_registration_path
    primero = css_select("button.pista-boton").map { |b| b["popovertarget"] }

    get new_user_registration_path
    segundo = css_select("button.pista-boton").map { |b| b["popovertarget"] }

    assert_equal primero, segundo
  end
end
