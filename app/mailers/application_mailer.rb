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

  # El canal con el que ElasticEmail agrupa las estadísticas.
  #
  # La cuenta manda el correo de cuatro sistemas —SIGA, COES-FAU, COES-FHE y
  # CODEX— y sin esto el Activity es un solo chorro con todo revuelto.
  #
  # Va por TIPO de correo y no un `siga` plano, porque la pregunta que de verdad
  # se hace es otra. Un colegio carga 360 representantes, la secretaria genera
  # los códigos, y a la semana nadie entró:
  #
  #     siga-acceso-activacion   360 enviados · 45 rebotados   ← accionable
  #     siga-devise-...           40 enviados ·  0 rebotados
  #
  # "45 rebotados en activación" dice qué hacer: hay 45 correos mal escritos en
  # la planilla y hay que pedirlos de nuevo. Diluido en un total, ese número no
  # dice nada.
  before_action :marcar_el_canal

  private

  def marcar_el_canal
    headers["X-ElasticEmail-Channel"] = canal
  end

  # "AccesoMailer#activacion"                  → siga-acceso-activacion
  # "Devise::Mailer#reset_password_instructions" → siga-devise-reset-password-instructions
  def canal
    familia = self.class.name.underscore
                  .delete_suffix("_mailer")
                  .tr("/", "-")
                  .delete_suffix("-mailer")

    [ "siga", familia, action_name ].join("-").tr("_", "-")
  end
end
