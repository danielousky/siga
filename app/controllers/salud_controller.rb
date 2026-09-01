# Si el worker se cayó, ¿alguien se entera? (`MOR-167`)
#
# Hasta ahora, no. El `Procfile` lo dice desde hace semanas —«sin él, un profesor
# cambia una ponderación, el job queda esperando en la tabla y los promedios de
# esa sección no se recalculan nunca»— y el modo de fallo es el peor que hay:
# **la app sigue respondiendo 200 en todas sus pantallas**. Nada se rompe. Solo
# que los promedios se quedan viejos, y el colegio lo descubre en el boletín.
#
# ## Qué contesta, y por qué no alcanza con `/up`
#
# `/up` es el health check de Rails: dice que el proceso web arrancó y que la
# base contesta. Es lo correcto para que Dokku decida si una versión nueva entra
# en servicio, y por eso **se queda como está**.
#
# Esto es otra pregunta: *¿el sistema está haciendo el trabajo que le encargaron?*
#
#     GET /salud  →  { ok, base, cola: { esperando, trabajando, fallidos,
#                                        mas_viejo_en_segundos, workers } }
#
# ## ⚠️ Devuelve 503 cuando la cola está TRANCADA, y eso tiene consecuencias
#
# Un 503 es lo que hace que un monitor externo avise. Pero por eso mismo **este
# endpoint NO puede ser el health check del despliegue**: si lo fuera, un worker
# caído impediría desplegar la corrección que lo arregla. `/up` para Dokku,
# `/salud` para el monitor. Están separados a propósito.
#
# «Trancada» es que el trabajo más viejo lleva esperando más que
# `TOLERANCIA`. No es «hay trabajos en cola»: encolar y ejecutar en el mismo
# segundo es el funcionamiento normal.
#
# ## Los trabajos FALLIDOS se informan y NO cambian el estado
#
# Un job que reventó por un dato raro se queda en `failed_executions` para
# siempre. Si eso pusiera el endpoint en rojo, el monitor avisaría todos los días
# hasta que alguien limpie la tabla — y un aviso que suena siempre deja de
# leerse. Lo que urge es que la cola AVANCE.
class SaludController < ApplicationController
  # Un monitor externo no tiene sesión, y el chequeo tiene que funcionar
  # justamente cuando la app está mal.
  skip_before_action :authenticate_user!
  skip_around_action :con_el_colegio_de_la_sesion

  # Cuánto puede esperar un trabajo antes de que sea un problema. El único job de
  # SIGA corre en ~1 segundo; cinco minutos es holgadísimo y no da falsos avisos
  # por un pico.
  TOLERANCIA = 5.minutes

  def show
    datos = medir
    render json: datos, status: datos[:ok] ? :ok : :service_unavailable
  rescue StandardError => e
    # Si ni esto se puede medir, el problema es la base. Se dice, con 503.
    Rails.logger.error("[salud] #{e.class}: #{e.message}")
    render json: { ok: false, base: false, error: e.class.name }, status: :service_unavailable
  end

  private

  def medir
    cola = estado_de_la_cola

    { ok: cola[:mas_viejo_en_segundos].to_i < TOLERANCIA.to_i,
      base: true,
      cola: cola,
      version: ENV["GIT_REV"].presence,
      medido: Time.current.iso8601 }
  end

  def estado_de_la_cola
    esperando = SolidQueue::ReadyExecution.count
    # ⚠️ `created_at` del JOB, no del `ReadyExecution`: es cuándo lo encolaron,
    # que es lo que a un colegio le importa. El registro de ejecución se puede
    # recrear al reintentar y reiniciaría el reloj.
    mas_viejo = SolidQueue::Job.where(id: SolidQueue::ReadyExecution.select(:job_id))
                               .minimum(:created_at)

    { esperando: esperando,
      trabajando: SolidQueue::ClaimedExecution.count,
      fallidos: SolidQueue::FailedExecution.count,
      # Un worker vivo late. Cero workers con trabajos esperando es exactamente
      # el caso que este endpoint existe para ver.
      workers: SolidQueue::Process.where(kind: "Worker").count,
      mas_viejo_en_segundos: mas_viejo ? (Time.current - mas_viejo).round : 0 }
  end
end
