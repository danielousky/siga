# Los datos que pide la forma 31059 de verdad (MOR-99).
#
# Se construyó una primera versión desde la especificación escrita. Después
# apareció **un ejemplar real, lleno y sellado**, y trae campos que ninguna
# descripción mencionaba. Esto los agrega.
#
# ## Del plantel (sección II)
#
# El formato pide `Teléfono` y `CDCEE` —el Centro de Desarrollo de la Calidad
# Educativa Estadal, que es quien avala la certificación en la sección VIII—.
# Sin el CDCEE, el bloque de firma del estado queda sin membrete.
#
# ## Del estudiante (sección III)
#
# El lugar de nacimiento va PARTIDO en País, Estado y Municipio, con una casilla
# para cada uno. `birth_place` era un texto libre: sirve para mostrar «Caracas,
# Distrito Capital» en pantalla y no para llenar tres casillas.
#
# Se conserva `birth_place` y no se migra a la fuerza: lo que hay adentro es
# texto que alguien escribió, y partirlo adivinando pondría un municipio donde
# hay un estado. Lo llena quien emita la certificación.
class LosDatosQuePideLaForma31059 < ActiveRecord::Migration[8.1]
  def change
    change_table :schools, bulk: true do |t|
      t.string :telefono
      # El Centro de Desarrollo de la Calidad Educativa Estadal que avala. En el
      # ejemplar real dice «ZULIA»: es el del estado, no un código.
      t.string :cdcee
    end

    change_table :users, bulk: true do |t|
      # Venezuela por defecto sería una suposición: hay alumnos nacidos afuera y
      # el formato tiene la casilla justamente para eso.
      t.string :birth_country
      t.string :birth_state
      t.string :birth_municipality
    end
  end
end
