class ApplicationMailer < ActionMailer::Base
  # ⚠️ Acá decía `from@example.com`, que es lo que deja el generador de Rails.
  #
  # Los correos de Devise no lo usaban —tienen su propio `config.mailer_sender`—
  # así que nadie lo notó hasta que `AccesoMailer` (MOR-143) fue el primer mailer
  # propio de la app. Y con un proveedor de verdad esto no es un detalle
  # cosmético: ElasticEmail solo despacha correo cuyo remitente esté en un
  # dominio VERIFICADO. `example.com` no lo está, así que el correo de
  # activación se habría rechazado en el primer envío.
  #
  # Va en un lambda y no en una constante para que se evalúe en cada envío: el
  # valor sale del entorno, y con `ENV.fetch` a nivel de clase quedaría
  # congelado el que hubiera al cargar la app.
  default from: -> { ENV.fetch("SIGA_MAIL_FROM", "no-responder@sigaeducando.com") }

  layout "mailer"
end
