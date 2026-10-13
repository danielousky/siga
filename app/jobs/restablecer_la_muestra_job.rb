require "open3"

# Cada noche, el colegio de muestra vuelve a su estado sembrado (spec
# `docs/specs/del-registro-al-cobro.md`, § 4.3).
#
# ## ⚠️ Está programado SOLO en la instancia de muestra
#
# `config/recurring.yml` lo agenda únicamente si `SIGA_MUESTRA=1`. Y si igual
# llegara a correr en otra parte, sale sin hacer nada; y si la variable
# estuviera mal puesta, `RestablecerLaMuestra` se niega al encontrar un colegio
# de verdad. Tres cerrojos para algo que borra una base entera.
#
# ## Por qué lanza OTRO proceso en vez de sembrar aquí
#
# Los seeds se cargan con `load`: definen constantes y métodos sueltos
# (`paso`, `alumno!`, `seccion_de`…) en el proceso que los corre. En una tarea
# eso muere con ella; en un worker que vive semanas quedarían pegados, se
# redefinirían cada noche y cualquiera podría tapar un método de la aplicación
# con el mismo nombre. Un proceso aparte nace limpio y se lleva todo al salir.
#
# `de_toda_la_plataforma`: no es de ningún colegio.
class RestablecerLaMuestraJob < ApplicationJob
  queue_as :default
  de_toda_la_plataforma

  class NoSePudo < StandardError; end

  ORDEN = [ Rails.root.join("bin/rails").to_s, "muestra:restablecer" ].freeze

  def perform
    return false unless Muestra.activa?

    salida, salio_bien = lanzar

    Rails.logger.info("[RestablecerLaMuestraJob] #{salida.to_s.lines.last(12).join.strip}")

    # ⚠️ Si no se pudo, el trabajo FALLA: queda entre los fallidos, que es lo
    # único que alguien puede llegar a mirar. La muestra sigue como estaba ayer
    # —borrar y sembrar van en una sola transacción—.
    raise NoSePudo, salida.to_s.lines.last(6).join.strip unless salio_bien

    true
  end

  private

  # El proceso aparte: qué dijo y si terminó bien. Es un método para que un
  # test pueda poner otra cosa en su lugar: probar el trabajo no puede costar
  # borrar y sembrar una base.
  def lanzar
    salida, estado = Open3.capture2e(*ORDEN, chdir: Rails.root.to_s)
    [ salida, estado.success? ]
  end
end
