require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Siga
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # La interfaz es en español; el inglés queda disponible para no cerrar la puerta.
    config.i18n.default_locale = :es
    config.i18n.available_locales = [:es, :en]

    # El esquema se versiona como SQL, no como schema.rb.
    #
    # No es preferencia: schema.rb no puede representar las políticas de RLS
    # (MOR-87). Con el formato Ruby, las políticas existirían en la base de
    # desarrollo y desaparecerían en cualquier entorno creado con db:setup —
    # o sea, en producción. El aislamiento se caería justo donde importa.
    config.active_record.schema_format = :sql

    # Todo `deliver_later` lleva el colegio de quien lo disparó (MOR-88).
    #
    # El default de Rails es `ActionMailer::MailDeliveryJob`, que no hereda de
    # ApplicationJob y por lo tanto no lleva contexto de inquilino.
    config.action_mailer.delivery_job = "MailerDeliveryJob"

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
