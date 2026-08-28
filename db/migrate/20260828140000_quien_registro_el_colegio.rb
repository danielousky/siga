# Quién dio de alta cada colegio (MOR-158).
#
# ## Por qué esto se guarda AHORA aunque `Account` no exista todavía
#
# El concepto de cuenta quedó planteado y sin implementar: una cuenta con varios
# colegios, un dueño, y la suscripción colgando de ella. Cuando llegue, la
# pregunta que va a haber que contestar es **a quién pertenece cada colegio** —
# y esa respuesta solo existe en el momento del alta.
#
# Guardarla hoy es una columna. Reconstruirla después es imposible: el primer
# `Admin` de un colegio se puede haber ido, o pueden ser tres, y ninguno dice
# quién fue el que se registró.
#
# ⚠️ Es nullable a propósito. Los colegios que ya existen —y los que da de alta
# el equipo de SIGA— no tienen a nadie que se haya "registrado": inventarles un
# dueño sería peor que dejarlo vacío.
class QuienRegistroElColegio < ActiveRecord::Migration[8.1]
  def change
    add_reference :schools, :registrado_por, foreign_key: { to_table: :users }, null: true
  end
end
