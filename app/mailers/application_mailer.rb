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
  before_action :sin_seguimiento

  private

  def marcar_el_canal
    headers["X-ElasticEmail-Channel"] = canal
  end

  # SIGA no rastrea sus correos, y no es una postura: es que rastrearlos los
  # rompe.
  #
  # El seguimiento de clics **reescribe los enlaces**. El correo de activación
  # dejaría de llevar `https://sigaeducando.com/activar/<código>` y llevaría un
  # redirect por `tracking.sigaeducando.com`. Tres consecuencias, y ninguna es
  # aceptable para un correo que transporta una credencial:
  #
  #   1. El código de un solo uso viaja por el sistema de terceros y queda en
  #      SU registro de clics. Un código sin usar es una llave viva por 72 h.
  #   2. La mamá ve un dominio de redirección donde esperaba el del colegio.
  #      Es exactamente la forma de un correo de phishing.
  #   3. Si el rastreo falla, el enlace de activación falla con él — y el
  #      colegio no tiene forma de saber por qué nadie puede entrar.
  #
  # Se apaga POR MENSAJE y no en la cuenta a propósito: la misma cuenta manda el
  # correo de COES-FAU, COES-FHE y CODEX, donde el rastreo de campañas sí sirve.
  #
  # `IsTransactional` es lo que evita el otro accidente de compartir cuenta: si
  # una dirección se dio de baja de una campaña de otro sistema, sin esta
  # cabecera su código de acceso a SIGA se descartaría en silencio.
  def sin_seguimiento
    headers["trackclicks"]     = "false"
    headers["trackopens"]      = "false"
    headers["IsTransactional"] = "True"
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
