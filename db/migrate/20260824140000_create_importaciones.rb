# La importación de matrícula, como registro (MOR-126).
#
# Existe porque el proceso tiene CUATRO pasos y una planilla de 360 filas no
# cabe en la sesión:
#
#     subir  →  mapear columnas  →  previsualizar  →  confirmar
#
# Entre uno y otro hay que recordar el archivo y el mapeo elegido. Y después,
# hay que poder responder "¿qué se cargó el 12 de septiembre y quién lo hizo?",
# que es la pregunta de un colegio al que le aparecieron alumnos de más.
#
# ## Por qué el archivo se guarda y no se procesa al vuelo
#
# Porque la previsualización tiene que mostrar lo mismo que después se va a
# escribir. Releerlo del disco en cada paso garantiza eso; volver a subirlo en
# cada paso se lo pide a la secretaria tres veces.
class CreateImportaciones < ActiveRecord::Migration[8.1]
  def change
    create_table :importaciones do |t|
      t.references :school, null: false, foreign_key: true

      # Quién la subió. Es dato de auditoría y no se borra con la persona: si
      # esa secretaria deja el colegio, la importación que hizo sigue siendo
      # suya. Por eso `restrict` y no `cascade`.
      t.references :subido_por, null: false, foreign_key: { to_table: :users }

      t.integer :estado, null: false, default: 0

      # El mapeo elegido: `{ "APELLIDOS Y NOMBRES" => "nombre_completo" }`.
      #
      # Se guarda para poder reimportar una planilla corregida sin rehacerlo, que
      # es el caso NORMAL —el colegio manda el archivo, ve el reporte, arregla
      # cuatro filas y lo vuelve a mandar—, no la excepción.
      t.jsonb :mapeo, null: false, default: {}

      # Lo que pasó al confirmar: conteos, y las filas que quedaron fuera con su
      # motivo. Se guarda en vez de recalcularse porque el archivo puede cambiar
      # y el reporte tiene que seguir describiendo lo que de verdad ocurrió.
      t.jsonb :resultado, null: false, default: {}

      # Para el listado, sin tener que abrir el archivo.
      t.string  :nombre_del_archivo
      t.integer :filas_leidas

      t.timestamps
    end

    add_index :importaciones, [ :school_id, :created_at ]

    add_check_constraint :importaciones, "estado IN (0, 1, 2, 3)",
                         name: "importaciones_estado_valido"

    reversible do |dir|
      dir.up do
        execute "ALTER TABLE importaciones ENABLE ROW LEVEL SECURITY"
        execute "ALTER TABLE importaciones FORCE  ROW LEVEL SECURITY"

        # `USING` filtra lo que se puede LEER; `WITH CHECK`, lo que se puede
        # ESCRIBIR. Sin el segundo se podrían insertar filas de otro colegio
        # aunque no se pudieran ver después.
        execute <<~SQL.squish
          CREATE POLICY aislamiento_por_colegio ON importaciones
            USING (#{condicion})
            WITH CHECK (#{condicion})
        SQL
      end

      dir.down { execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON importaciones" }
    end
  end

  private

  def condicion
    <<~SQL.squish
      current_setting('siga.bypass_rls', true) = 'on'
      OR school_id IS NOT DISTINCT FROM NULLIF(current_setting('siga.school_id', true), '')::bigint
    SQL
  end
end
