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

  # Devise tiene su propio remitente y NO usa el `default from:` del mailer.
  # Que los dos salgan del mismo lado es lo que hace que verificar un dominio
  # alcance para todo el correo de la app.
  test "Devise usa el mismo remitente que la app" do
    assert_equal ApplicationMailer.default[:from].call,
                 Devise.mailer_sender
  end
end
