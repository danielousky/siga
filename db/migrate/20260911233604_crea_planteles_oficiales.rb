# El catálogo de planteles del MPPE, para SUGERIR al registrarse.
#
#     escribe «san jose»  ──►  U.E.P. COLEGIO SAN JOSÉ · PD01234567 · Distrito Capital
#                              ↓ al elegirlo
#                              se rellenan nombre, DEA y estado — y se pueden CAMBIAR
#
# ## ⚠️ Es una SUGERENCIA, nunca una verdad
#
# Daniel: *«lo que hablo es de SUGERIR, no quiere decir que sea la verdad;
# SIEMPRE podrá modificar los datos»*. El catálogo rellena y quien se registra
# corrige lo que haga falta: manda lo que él escriba, no lo que diga esta tabla.
#
# Es la misma regla que `DivisionPolitica::OTRO` —«un catálogo equivocado nunca
# puede impedirle a un colegio registrarse»— y acá pesa más, porque el código
# DEA sale impreso en cada boletín y en cada constancia.
#
# ## ⚠️ NO lleva RLS, y no es un olvido
#
# No son datos de ningún colegio: son un catálogo de la plataforma, como las
# tablas de la cola de trabajos o `siga_staffs`. Con una política por colegio,
# quien todavía NO tiene colegio —o sea, todo el que se está registrando, que
# es justo para quien existe esto— no vería ni una fila.
class CreaPlantelesOficiales < ActiveRecord::Migration[8.1]
  def change
    create_table :planteles_oficiales do |t|
      t.string :dea_code
      t.string :nombre, null: false
      t.string :entidad_federal

      # ⚠️ La forma de BUSCAR, calculada al sembrar y no en cada consulta.
      #
      # Aplanar acentos con `translate(lower(...))` sobre dieciséis mil filas en
      # cada tecla es trabajo que se puede hacer una sola vez. Y en Venezuela
      # aplanarlos no es opcional: sin eso, «san jose» no encuentra a «SAN JOSÉ».
      t.string :busqueda, null: false

      t.timestamps
    end

    add_index :planteles_oficiales, :busqueda
    # ⚠️ El DEA NO es único acá, y sí lo es en `schools`. Un catálogo compilado
    # de una fuente pública trae repetidos y vacíos; rechazarlos al sembrar
    # dejaría fuera planteles que existen. Lo que tiene que ser único es el
    # código del colegio que se registra, y eso ya lo cuida `schools`.
    add_index :planteles_oficiales, :dea_code
  end
end
