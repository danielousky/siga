require "test_helper"

# De quién sale el correo de SIGA.
#
# No es cosmético. Un proveedor de verdad —ElasticEmail, y cualquier otro—
# solo despacha correo cuyo remitente esté en un dominio VERIFICADO por DNS.
# `from@example.com`, que es lo que deja el generador de Rails, se rechaza en el
# primer envío… y hasta que hubo un proveedor configurado, nada lo delataba:
# en desarrollo `perform_deliveries` es false y el correo nunca sale.
class CorreoSalienteTest < ActionMailer::TestCase
  test "el correo de activación sale del dominio del producto" do
    colegio = escenario_academico.colegio
    persona = User.create!(first_name: "Ana", last_name: "Prueba",
                           document: "99000099", document_type: :cedula_v,
                           email: "ana@familia.test")

    correo = AccesoMailer.activacion(persona, "un-codigo", colegio)

    assert_no_match(/example\.com/, correo.from.first,
                    "el remitente del generador de Rails llegó a producción")
    assert_match(/@sigaeducando\.com\z/, correo.from.first)
  end

  # ── el canal de ElasticEmail ─────────────────────────────────────────────

  test "el correo de activación va etiquetado con su canal" do
    colegio = escenario_academico.colegio
    persona = User.create!(first_name: "Ana", last_name: "Canal",
                           document: "99000098", document_type: :cedula_v,
                           email: "ana.canal@familia.test")

    correo = AccesoMailer.activacion(persona, "un-codigo", colegio)

    assert_equal "siga-acceso-activacion", correo["X-ElasticEmail-Channel"].to_s
  end

  # ⚠️ Devise hereda de `ActionMailer::Base` por defecto, así que sin
  # `config.parent_mailer` el correo de "olvidé mi contraseña" —el más frecuente
  # de la app— sería el único que quedaría fuera de las estadísticas.
  test "los correos de Devise también van etiquetados" do
    persona = User.create!(first_name: "Beto", last_name: "Canal",
                           document: "99000097", document_type: :cedula_v,
                           email: "beto.canal@familia.test", password: "123123")
    token = persona.send(:set_reset_password_token)

    correo = Devise.mailer.reset_password_instructions(persona, token)

    assert_equal "siga-devise-reset-password-instructions",
                 correo["X-ElasticEmail-Channel"].to_s
  end

  test "el canal nunca lleva guion bajo ni barra" do
    colegio = escenario_academico.colegio
    persona = User.create!(first_name: "Ceci", last_name: "Canal",
                           document: "99000096", document_type: :cedula_v,
                           email: "ceci.canal@familia.test")
    canal = AccesoMailer.activacion(persona, "x", colegio)["X-ElasticEmail-Channel"].to_s

    assert_match(/\Asiga-[a-z0-9-]+\z/, canal, "quedó #{canal.inspect}")
  end

  # ── nada de rastreo ──────────────────────────────────────────────────────

  # ⚠️ El seguimiento de clics REESCRIBE los enlaces. Con él encendido, el
  # correo de activación dejaría de llevar `sigaeducando.com/activar/<código>` y
  # llevaría un redirect de terceros: el código de un solo uso quedaría en el
  # registro de clics de ElasticEmail, y la mamá vería un dominio que no es el
  # del colegio — la forma exacta de un correo de phishing.
  test "el correo de activación no se rastrea" do
    colegio = escenario_academico.colegio
    persona = User.create!(first_name: "Dora", last_name: "Rastreo",
                           document: "99000095", document_type: :cedula_v,
                           email: "dora@familia.test")

    correo = AccesoMailer.activacion(persona, "un-codigo", colegio)

    assert_equal "false", correo["trackclicks"].to_s
    assert_equal "false", correo["trackopens"].to_s
  end

  # La cuenta de ElasticEmail es compartida con COES-FAU, COES-FHE y CODEX. Sin
  # esto, una dirección que se dio de baja de una campaña de otro sistema no
  # recibiría su código de acceso a SIGA, y el descarte es silencioso.
  test "el correo va marcado como transaccional" do
    colegio = escenario_academico.colegio
    persona = User.create!(first_name: "Elsa", last_name: "Transaccional",
                           document: "99000094", document_type: :cedula_v,
                           email: "elsa@familia.test")

    correo = AccesoMailer.activacion(persona, "un-codigo", colegio)

    assert_equal "True", correo["IsTransactional"].to_s
  end

  test "los correos de Devise tampoco se rastrean" do
    persona = User.create!(first_name: "Fito", last_name: "Rastreo",
                           document: "99000093", document_type: :cedula_v,
                           email: "fito@familia.test", password: "123123")
    token = persona.send(:set_reset_password_token)

    correo = Devise.mailer.reset_password_instructions(persona, token)

    assert_equal "false", correo["trackclicks"].to_s
    assert_equal "True", correo["IsTransactional"].to_s
  end

  # Devise tiene su propio remitente (`config.mailer_sender`). Que sea la misma
  # DIRECCIÓN que usa la app es lo que hace que verificar un dominio alcance
  # para todo el correo de SIGA.
  #
  # ⚠️ Se compara la dirección, no el remitente entero: desde el 5 de octubre de
  # 2026 el remitente lleva nombre —«SIGA», o el del colegio— y ese nombre se
  # decide por correo. La dirección es una sola.
  test "Devise usa la misma dirección que la app" do
    assert_equal ApplicationMailer.direccion, Devise.mailer_sender
  end

  test "y sus correos salen de esa dirección, con nombre" do
    persona = User.create!(first_name: "Gil", last_name: "Remitente",
                           document: "99000092", document_type: :cedula_v,
                           email: "gil@familia.test", password: "123123")
    token = persona.send(:set_reset_password_token)

    correo = Devise.mailer.reset_password_instructions(persona, token)

    assert_equal [ ApplicationMailer.direccion ], correo.from
    assert_equal "SIGA", correo[:from].display_names.first,
                 "en la bandeja se leía la dirección pelada, sin decir de quién era"
  end

  # ⚠️ Los correos de la cuenta salen de `CuentaMailer`, no de `Devise::Mailer`.
  # El canal se arma del nombre de la clase, así que habría pasado a llamarse
  # `siga-cuenta-…` — y las estadísticas del correo más frecuente de la app se
  # habrían partido en dos, con la mitad vieja congelada.
  test "el canal de los correos de la cuenta conserva su nombre" do
    assert_equal "CuentaMailer", Devise.mailer.name
    persona = User.create!(first_name: "Hugo", last_name: "Canal",
                           document: "99000091", document_type: :cedula_v,
                           email: "hugo@familia.test", password: "123123")

    correo = Devise.mailer.password_change(persona)

    assert_equal "siga-devise-password-change", correo["X-ElasticEmail-Channel"].to_s
  end
end
