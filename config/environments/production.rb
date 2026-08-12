require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # ── TLS ───────────────────────────────────────────────────────────────────
  #
  # El TLS lo termina el proxy de adelante —nginx en Dokku, o el túnel de
  # Cloudflare— y a la app le llega HTTP plano con `X-Forwarded-Proto: https`.
  # Sin `assume_ssl`, Rails ve HTTP, redirige a HTTPS, el proxy vuelve a entrar
  # por HTTP… y el navegador corta por bucle de redirecciones.
  config.assume_ssl = ENV.fetch("SIGA_ASSUME_SSL", "true") == "true"

  # ⚠️ `force_ssl` activa HSTS, y **HSTS es difícil de deshacer**: el navegador
  # recuerda "esta gente solo habla HTTPS" durante `max_age` y no acepta que le
  # digan lo contrario. Si el certificado no está en orden, el sitio queda
  # inaccesible hasta que ese plazo expire — en nadie más que en el visitante.
  #
  # Por eso hay dos perillas: se puede apagar entero para el primer arranque, y
  # el `max_age` arranca en una hora en vez de en un año. Se sube cuando el
  # dominio y el certificado están asentados.
  config.force_ssl = ENV.fetch("SIGA_FORCE_SSL", "true") == "true"

  config.ssl_options = {
    hsts: { expires: ENV.fetch("SIGA_HSTS_SEGUNDOS", 1.hour.to_i).to_i, subdomains: false },
    # El health check tiene que responder por HTTP: Dokku lo consulta desde
    # adentro de la red del servidor, sin pasar por el proxy.
    redirect: { exclude: ->(request) { request.path == "/up" } }
  }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # config.cache_store = :mem_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # ── Correo ────────────────────────────────────────────────────────────────
  #
  # Hoy el único correo que la app manda es el de "olvidé mi contraseña", y es el
  # único camino de un profesor que se quedó afuera un domingo a la noche. Sin
  # esto configurado, ese formulario dice "le enviamos un enlace" y no envía
  # nada — que es peor que no tener el formulario.
  #
  # Todo sale de variables de entorno para no atar el sistema a un proveedor:
  # sirve igual Resend, Brevo, Mailgun o el SMTP del propio colegio.
  config.action_mailer.default_url_options = {
    host: ENV.fetch("SIGA_HOST", "localhost:3000"),
    protocol: ENV.fetch("SIGA_FORCE_SSL", "true") == "true" ? "https" : "http"
  }

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = ENV["SMTP_ADDRESS"].present?

  # `raise_delivery_errors` en true a propósito: un correo que no sale tiene que
  # aparecer en el log de errores, no desaparecer. Un fallo silencioso acá se
  # descubre cuando un profesor llama al colegio porque no puede entrar.
  config.action_mailer.raise_delivery_errors = true

  config.action_mailer.smtp_settings = {
    address:              ENV["SMTP_ADDRESS"],
    port:                 ENV.fetch("SMTP_PORT", 587).to_i,
    user_name:            ENV["SMTP_USERNAME"],
    password:             ENV["SMTP_PASSWORD"],
    domain:               ENV.fetch("SMTP_DOMAIN", ENV.fetch("SIGA_HOST", "localhost")),
    authentication:       ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
    enable_starttls_auto: true
  }.compact

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # ── Qué dominios acepta ───────────────────────────────────────────────────
  #
  # Protege contra DNS rebinding y contra que alguien sirva la app desde un
  # dominio ajeno. Se declara por variable de entorno porque el dominio cambia
  # entre la demo (un túnel de Cloudflare, `algo.trycloudflare.com`) y el
  # definitivo.
  #
  #   SIGA_HOSTS="siga.midominio.com,.midominio.com"
  #
  # Un valor que arranca con punto vale para el dominio y sus subdominios.
  # Sin la variable no se filtra nada — que es el default de Rails, y lo correcto
  # mientras no se sepa el dominio: filtrar mal deja la app inaccesible.
  hosts_permitidos = ENV.fetch("SIGA_HOSTS", "").split(",").map(&:strip).reject(&:empty?)
  config.hosts += hosts_permitidos if hosts_permitidos.any?

  # El health check queda afuera: Dokku lo consulta por IP, sin `Host` válido.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
