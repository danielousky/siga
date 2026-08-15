# Los dos procesos de SIGA en producción.
#
# `worker` no es opcional: sin él, un profesor cambia una ponderación, el job
# queda esperando en la tabla y los promedios de esa sección no se recalculan
# nunca. La cola sobrevive al reinicio —para eso está Solid Queue— pero nadie
# la vacía.
#
# `bin/rails notas:recalcular` sigue existiendo como reparación idempotente, y
# es lo que hay que correr si el worker estuvo caído.
web: bundle exec rails server -p $PORT -e $RAILS_ENV
worker: bundle exec rails solid_queue:start
