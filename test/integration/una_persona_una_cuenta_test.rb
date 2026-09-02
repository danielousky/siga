require "test_helper"

# Una persona es UNA cuenta, y puede representar en más de un colegio (MOR-142).
#
# El alta de representantes buscaba a la persona **por correo**. Mientras el
# correo fue obligatorio eso alcanzaba; desde `MOR-142` es opcional, y buscar por
# un campo que puede venir vacío deja a la señora sin encontrar.
#
# ── Qué se rompía, exactamente ──────────────────────────────────────────────
#
# No duplicaba: el índice único de `users.document` lo impedía. **Bloqueaba**, y
# con un mensaje que culpa al dato:
#
#     Colegio A registra a Carmen Rodríguez (V-12.345.678) ······ ✓
#     Colegio B intenta registrarla, su otro hijo estudia allá ·· ✗ 422
#                                        "Document ya está en uso"
#
# La secretaria de B no tiene salida: la persona que "ya está en uso" es alguien
# que el RLS no la deja ver, y el formulario no le ofrece nada que hacer. Es la
# promesa de `MOR-138` —la misma persona con el mismo rol en varios colegios—
# rota en el único camino por el que se llega a ella.
class UnaPersonaUnaCuentaTest < ActionDispatch::IntegrationTest
  setup { @a, @b = dos_colegios_completos }

  def personas = Current.sin_aislamiento { User.count }
  def roles_de_representante = Current.sin_aislamiento { Representative.count }

  def alta(telefono: "0412-1234567", **datos)
    post representatives_path, params: { user: datos, representative: { phone: telefono } }
  end

  # La aserción tiene DOS mitades y ninguna sirve sola:
  #
  #   sin persona nueva ....  no la duplicó
  #   con rol nuevo ........  y además la registró
  #
  # Solo con la primera, el test pasa igual con el código viejo: bloquear el
  # alta también deja el conteo de personas quieto. Es exactamente el error que
  # tuvo esta suite antes de reescribirla.
  def assert_reutiliza_la_persona
    assert_difference "roles_de_representante", 1, "no la registró en este colegio" do
      assert_no_difference "personas", "creó una persona nueva en vez de reutilizarla" do
        yield
      end
    end

    assert_response :redirect
  end

  CARMEN = { first_name: "Carmen", last_name: "Rodríguez",
             document: "12345678", document_type: "cedula_v" }.freeze

  test "una madre sin correo puede representar en dos colegios" do
    sign_in @a.director
    alta(**CARMEN)
    assert_response :redirect, "el primer colegio la registra sin problema"

    sign_out @a.director
    sign_in @b.director

    # Antes: 422 "Document ya está en uso", y sin salida para la secretaria.
    assert_reutiliza_la_persona { alta(**CARMEN) }
  end

  test "la misma cédula escrita distinto encuentra a la misma persona" do
    sign_in @a.director
    alta(**CARMEN.merge(document: "V-12.345.678"))

    sign_out @a.director
    sign_in @b.director

    # En la base vive `12345678`; `WHERE document = 'V-12.345.678'` no devuelve
    # nada. Por eso la búsqueda normaliza ANTES de preguntar.
    assert_reutiliza_la_persona { alta(**CARMEN.merge(document: "12.345.678")) }
  end

  test "se la encuentra por cédula escolar cuando es lo único que tiene" do
    joven = { first_name: "Joven", last_name: "Representante", cedula_escolar: "V20090000123" }

    sign_in @a.director
    alta(**joven)

    sign_out @a.director
    sign_in @b.director

    assert_reutiliza_la_persona { alta(**joven) }
  end

  # ⚠️ Este test AFIRMABA LO CONTRARIO, y hubo que darlo vuelta (MOR-200).
  #
  # Decía «se la encuentra por correo cuando es lo único que tiene»: sin
  # documento, un correo repetido reutilizaba la persona. Suena razonable y
  # causó un incidente.
  #
  # Daniel: *«accidentalmente coloqué el mismo correo para un director y un
  # representante. En primer lugar, nunca dio error y debió darlo; segundo, al
  # cambiárselo al director también lo hizo con el representante»*. El
  # «representante nuevo» no fue una persona nueva: fue un rol más colgado de la
  # fila del director, y editar el correo de uno editaba el del otro porque son
  # el mismo `User`. Daniel terminó sin poder entrar.
  #
  # El correo NO distingue los dos casos —la misma persona en su segundo
  # colegio, y dos personas con el buzón mal escrito— porque identifica un
  # BUZÓN, y un buzón cambia de dueño.
  #
  # Lo que sí es asimétrico es el costo de equivocarse:
  #
  #     no reutilizar y era la misma  →  «ese correo ya es de alguien»; la
  #                                      secretaria escribe la cédula y anda
  #     reutilizar y eran dos         →  dos personas fusionadas EN SILENCIO,
  #                                      sin manera de deshacerlo desde la app
  #
  # Por eso ahora se rechaza. El camino para la persona de verdad repetida sigue
  # abierto y es el correcto: su cédula (los tests de acá arriba).
  test "sin documento, un correo repetido se RECHAZA en vez de fusionar" do
    ocupado = { first_name: "Solo", last_name: "Correo",
                email: "solo.correo@familia.test", document: "98765432",
                document_type: "cedula_v" }

    sign_in @a.director
    alta(**ocupado)

    sign_out @a.director
    sign_in @b.director

    assert_no_difference [ "personas", "roles_de_representante" ] do
      alta(first_name: "Otra", last_name: "Persona", email: "Solo.Correo@familia.test")
    end

    assert_response :unprocessable_entity
    assert_match(/correo/i, response.body,
                 "tiene que decir que el problema es el correo, no fusionar en silencio")
  end

  test "la profesora del colegio que además representa a su hijo sigue siendo una persona" do
    sign_in @a.director

    assert_reutiliza_la_persona do
      alta(first_name: @a.profesor.first_name, last_name: @a.profesor.last_name,
           document: @a.profesor.document, document_type: "cedula_v")
    end
  end

  # Antes se le ponía una contraseña aleatoria de 12 caracteres que NADIE
  # conocía: la cuenta nacía inutilizable, pero pareciendo utilizable.
  test "un representante nuevo nace sin credenciales" do
    sign_in @a.director
    alta(first_name: "Nueva", last_name: "Representante",
         document: "11223344", document_type: "cedula_v")

    persona = Current.sin_aislamiento { User.find_by(document: "11223344") }

    assert_not_nil persona
    assert_nil persona.encrypted_password
    assert_not persona.puede_entrar?
  end
end
