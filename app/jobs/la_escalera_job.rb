# La escalera de la suscripción, una vez al día (spec
# `docs/specs/del-registro-al-cobro.md`, § 5.7).
#
#     5 días antes       correo + aviso: «vence el 9 de noviembre»     todo funciona
#     vence              correo + aviso: «venció; quedan 15 días»      todo funciona
#     pasados 15 días    correo + aviso: solo lectura                  ve y descarga
#
# ## Por qué existe
#
# Daniel: *«no quiero estar persiguiendo pagos»*. Hasta esta tanda, el estado de
# una suscripción se movía solo cuando alguien abría la Cartera de `/siga`: un
# colegio vencido seguía «activo» hasta que el fundador pasara a mirar, y nadie
# le avisaba nada al colegio. Ahora el calendario lo mueve y le escribe.
#
# ## ⚠️ Cada correo sale UNA vez
#
# El trabajo corre todos los días y un colegio pasa quince en la gracia: sin
# memoria recibiría quince correos de «venció». `Subscription#aviso_pendiente`
# recuerda cuál fue el último y de qué vencimiento; al pagar, la cuenta empieza
# de nuevo sola.
#
# ## ⚠️ Anotar y encolar van juntos
#
# En una transacción por colegio: la cola vive en la misma base, así que el
# aviso anotado y el correo encolado se confirman a la vez o no se confirma
# ninguno. Anotando primero, un tropiezo deja a un colegio sin su aviso;
# encolando primero, se lo manda dos veces.
#
# `de_toda_la_plataforma`: recorre las suscripciones de todos los colegios.
class LaEscaleraJob < ApplicationJob
  queue_as :default
  de_toda_la_plataforma

  def perform
    avisados = 0

    Current.sin_aislamiento do
      Subscription.unscoped.includes(:school).find_each do |suscripcion|
        avisados += 1 if mover_y_avisar(suscripcion)
      end
    end

    Rails.logger.info("[LaEscaleraJob] #{avisados} colegios avisados")
    avisados
  end

  private

  def mover_y_avisar(suscripcion)
    suscripcion.with_lock do
      suscripcion.actualizar_estado!

      aviso = suscripcion.aviso_pendiente
      next false if aviso.nil?

      suscripcion.anotar_aviso!(aviso)
      next false if suscripcion.correos_de_quienes_pagan.empty?

      # ⚠️ DENTRO del colegio: un trabajo se lleva el que haya al encolarlo
      # (`CarriesSchool`), y aquí no hay ninguno. Sin él, el worker busca la
      # suscripción con el RLS puesto, no la encuentra, y el correo no sale —
      # sin que nada falle. Es la lección de la tanda 2.
      Current.en_el_colegio(suscripcion.school) do
        SuscripcionMailer.public_send(aviso, suscripcion).deliver_later
      end
      true
    end
  end
end
