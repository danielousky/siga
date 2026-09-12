# El código DEA deja de hacer falta para registrarse (`MOR-208`, segunda mitad).
#
# ## ⚠️ Por qué se saca de la puerta
#
# Es un código que asigna el ministerio y que nadie tiene en la cabeza. Pedirlo
# en el registro público pierde a quien iba a registrarse y se fue a buscarlo.
#
# Y el formulario ya lo sabía: decía «si no lo tiene a mano, escriba algo
# provisional y corríjalo después». Un DEA provisional es peor que ninguno —es
# un identificador NACIONAL con un valor inventado adentro, y nadie vuelve a
# corregir lo que ya pasó—. `PasosDeArranque` ya lo trata como un paso
# pendiente: el producto ya creía que un colegio puede no tenerlo todavía.
#
# ## ⚠️ El índice tiene que volverse PARCIAL, y esa es la trampa
#
# PostgreSQL considera que dos `NULL` son distintos, así que un índice único no
# bloquea dos colegios sin DEA. Pero la cadena VACÍA sí es un valor: con
# `''`, el segundo colegio que se registre sin código choca contra el primero
# con un error que no explica nada.
#
# Por eso van las dos mitades: el índice parcial acá, y `''` → `nil` en el
# modelo. Es exactamente lo que ya se hizo con `users.email` en `MOR-142`.
class ElCodigoDeaSeCargaDespues < ActiveRecord::Migration[8.1]
  def change
    change_column_null :schools, :dea_code, true

    remove_index :schools, :dea_code
    add_index :schools, :dea_code, unique: true, where: "dea_code IS NOT NULL"
  end
end
