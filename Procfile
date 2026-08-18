# Los dos procesos de SIGA en producción.
#
# `worker` no es opcional: sin él, un profesor cambia una ponderación, el job
# queda esperando en la tabla y los promedios de esa sección no se recalculan
# nunca. La cola sobrevive al reinicio —para eso está Solid Queue— pero nadie
# la vacía.
#
# `bin/rails notas:recalcular` sigue existiendo como reparación idempotente, y
# es lo que hay que correr si el worker estuvo caído.

# `release` lo corre Dokku UNA vez, antes de que la versión nueva entre en
# servicio, y si falla ABORTA el despliegue dejando la versión vieja intacta.
# Es el único lugar donde `rls:verificar` sirve de fusible: en `web` o `worker`
# solo tumbaría un contenedor, y Dokku podría dejarte creyendo que desplegaste.
#
# Va `db:migrate`, no `db:prepare`: `prepare` intenta sembrar en una base nueva
# y el guard de `db/seeds.rb` aborta con código 1 en production, lo que haría
# fallar el primer despliegue de todo entorno nuevo. Una base recién creada se
# prepara a mano una vez (`db:prepare`); de ahí en adelante, migraciones.
# Ojo con el `sh -c`: Dokku NO pasa esta línea por un shell, se la entrega
# directamente al binario. Sin él, `&&` llega como un argumento más y Rails
# responde `Unrecognized command "&&"`. Comprobado el 18 de agosto de 2026.
release: sh -c "./bin/rails db:migrate && ./bin/rails rls:verificar"
web: bundle exec rails server -p $PORT -e $RAILS_ENV
worker: bundle exec rails solid_queue:start
