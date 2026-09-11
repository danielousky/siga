# El RIF de una persona, que el colegio necesita para pagarle a su docente.
#
# ## ⚠️ Por qué una columna y no un `document_type` más
#
# Un profesor tiene cédula **Y** RIF: no son dos formas de decir lo mismo, son
# dos documentos con dos usos. `document` identifica a la persona —es lo que
# verifica el SAIME— y el RIF es lo que va en la nómina y en el recibo. Meterlo
# en el enum obligaría a elegir cuál de los dos guardar.
#
# ## ⚠️ Y vive en `users`, no en `teachers`
#
# El RIF es de la PERSONA, como la cédula: la misma maestra que da clase en dos
# colegios tiene un solo RIF, y `users` es la tabla de la plataforma mientras
# que `teachers` es del colegio (`MOR-138`). Con la columna en `teachers`, esa
# maestra lo tendría escrito dos veces y nada garantizaría que coincidieran.
#
# Lo pide, por ahora, solo el formulario del docente — que es donde hace falta.
class ElRifDelDocente < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :rif, :string

    # ⚠️ PARCIAL, como el de `email` (`MOR-142`). Un índice plano trata a `NULL`
    # como cualquier valor… salvo que PostgreSQL considera que dos `NULL` son
    # distintos, así que el único no bloquea nada — pero una cadena vacía sí es
    # un valor, y la primera persona sin RIF guardada como `""` impediría la
    # segunda. El modelo convierte `""` a `nil` por la misma razón.
    add_index :users, :rif, unique: true, where: "rif IS NOT NULL"
  end
end
