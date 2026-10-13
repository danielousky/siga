# La escalera de la suscripción, a mano (spec
# `docs/specs/del-registro-al-cobro.md`, § 5.7).
#
#     bin/rails suscripciones:escalera     mueve los estados y manda los avisos que toquen
#     bin/rails suscripciones:estado       en qué está cada colegio, sin tocar nada
#
# La escalera corre SOLA todos los días a las 8 de la mañana de Venezuela
# (`LaEscaleraJob`, en `config/recurring.yml`). Estas tareas son para cuando el
# worker estuvo caído, o para mirar antes de escribirle a un colegio.
#
# Son tareas y no un `runner` por lo mismo que las demás: `dokku run` parte la
# orden por espacios, y la salida de un `runner` no vuelve.
namespace :suscripciones do
  desc "Mueve los estados y manda los avisos que toquen hoy. Idempotente: cada aviso sale una vez."
  task escalera: :environment do
    avisados = LaEscaleraJob.perform_now
    puts "✅ La escalera corrió: #{avisados} #{avisados == 1 ? 'colegio avisado' : 'colegios avisados'}."
    puts "   Los correos quedan en la cola: los despacha el worker."
  end

  desc "En qué está la suscripción de cada colegio, y qué aviso ya recibió. No toca nada."
  task estado: :environment do
    avisos = Subscription::AVISOS.invert.merge(0 => :ninguno)

    Current.sin_aislamiento do
      puts ""
      puts format("  %-34s %-10s %-12s %-14s %s", "COLEGIO", "ESTADO", "VENCE", "ÚLTIMO AVISO", "LE TOCA HOY")
      Subscription.unscoped.includes(:school).order(:vigente_hasta, :id).each do |s|
        puts format("  %-34s %-10s %-12s %-14s %s",
                    s.school.name.to_s[0, 34], s.gratis? ? "gratis" : s.status,
                    s.vigente_hasta ? I18n.l(s.vigente_hasta, format: :short) : "—",
                    avisos.fetch(s.aviso_ya_enviado), s.aviso_pendiente || "nada")
      end
      puts ""
    end
  end
end
