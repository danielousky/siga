require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Siga
  # La versión del PRODUCTO, que no es la del commit.
  #
  # ## ⚠️ SemVer con los significados puestos desde el colegio
  #
  # El MAYOR de SemVer significa «rompí la API para quien depende de mí». De
  # SIGA no depende nadie: hay UNA versión corriendo y todos los colegios la
  # tienen. Sin darles otro significado, MAYOR/MENOR/PARCHE son una moneda al
  # aire y la numeración deja de decir nada.
  #
  #     MAYOR    cambia CÓMO TRABAJA el colegio    hay que avisarle y enseñarle
  #     MENOR    una función nueva                  se cuenta en el CHANGELOG
  #     PARCHE   un arreglo o un ajuste             nadie tiene que enterarse
  #
  # ⚠️ `1.0.0` NO significa «está completo»: significa **un colegio real opera
  # con esto**. Lo único que falta para eso es sacar los datos de demostración
  # de producción (`MOR-146`). La cobranza dentro de la app (`MOR-128`) NO es
  # un portón: hoy se vende igual y la suscripción ya lleva su estado.
  #
  # ⚠️ Y no es la revisión de git. `/salud` devuelve las dos: `version` es esta
  # —qué producto es— y `revision` es el commit desplegado —qué build es—.
  # Confundirlas hace que «la 0.9.0» signifique cuarenta cosas distintas.
  VERSION = "1.21.0".freeze

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

    # En el colegio de muestra no sale ningún correo. Ver `NadaSaleDeLaMuestra`.
    config.action_mailer.interceptors = %w[NadaSaleDeLaMuestra]

    # El campo que falló se MARCA, en todos los formularios (MOR-196).
    #
    # ## Qué estaba pasando
    #
    # Daniel, dos veces el mismo día: *«me faltó el Código DEA y no me arrojó
    # error, sino que me volvió a cargar la página»* y *«intenté crear una
    # materia vacía y no me arrojó ningún error»*.
    #
    # El error SÍ salía: los controllers responden 422, el resumen rojo se
    # pinta arriba del formulario y dice exactamente qué falta. Lo que no
    # pasaba es que el CAMPO culpable se distinguiera de los otros ocho. En un
    # formulario largo eso se ve igual que una recarga.
    #
    # ## Por qué el default de Rails no alcanzaba
    #
    # Rails ya envuelve el campo inválido en `<div class="field_with_errors">`
    # — y esta app **nunca le dio estilo a esa clase**, así que la envoltura no
    # se veía. Peor: es un `div` extra dentro del `.form-group`, o sea que
    # además desacomoda la fila.
    #
    # Cambiar el `field_error_proc` resuelve las dos cosas de una: en vez de
    # envolver, le agrega una clase AL CONTROL. Sin `div` de más, y con el
    # borde rojo que ya existe en la hoja de estilos.
    #
    # ⚠️ La etiqueta se deja intacta a propósito: Rails llama a esto también
    # para el `<label>`, y marcar los dos pinta de rojo el nombre del campo
    # además del campo. Con uno alcanza.
    #
    # ⚠️ Esto NO alcanza a los formularios escritos con `text_field_tag` —el
    # del colegio, el de la ubicación—, porque ésos no están atados a un
    # objeto y Rails no sabe que fallaron. Para ésos está
    # `ApplicationHelper#clase_de_campo`, que hace lo mismo a mano.
    config.action_view.field_error_proc = proc do |etiqueta_html, _|
      fragmento = Nokogiri::HTML::DocumentFragment.parse(etiqueta_html)
      control = fragmento.at_css("input, select, textarea")
      control["class"] = [ control["class"], "campo-con-error" ].compact_blank.join(" ") if control

      fragmento.to_html.html_safe
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
