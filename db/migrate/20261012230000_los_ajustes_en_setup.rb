# Los ajustes sueltos de la plataforma, como filas: nombre del campo y su valor.
#
# Daniel, 12 de octubre de 2026: *«Pon SIGA_MUESTRA_URL como un campo de
# ajustes. De hecho, vamos a agregar una tabla que se llame setup que sea nombre
# del campo, valor; allí vamos a colocar estos 2 valores, el número telefónico
# de WhatsApp y la url de muestra.»*
#
#     setup
#     nombre               valor
#     whatsapp             0414-1234567                    ← venía de siga_settings
#     url_de_la_muestra    https://demo.sigaeducando.com   ← era la variable SIGA_MUESTRA_URL
#
# ## Por qué filas y no columnas
#
# Un dato suelto nuevo —un correo de soporte, un enlace— es una fila más, sin
# migración. `siga_settings` se queda con lo que va JUNTO: los datos para
# pagar, que se validan entre sí (un Pago Móvil sin cédula no se ofrece).
#
# ## ⚠️ El WhatsApp se MUDA, no se copia
#
# Se pasa el número que hubiera y la columna vieja se va: dos lugares para el
# mismo número son dos números el día que alguien cambie uno solo.
#
# Solo se pasa si HAY número. Sin fila, `Setup.whatsapp` cae en la variable
# `SIGA_WHATSAPP`, que es el valor inicial de una instalación nueva —y de la
# muestra, donde nadie entra a `/siga`—; con una fila vacía, esa variable ya no
# contaría nunca.
#
# ## Y la dirección de la muestra, si la instancia la tenía
#
# `SIGA_MUESTRA_URL` deja de leerse: si estaba puesta, su valor pasa a la fila.
# Si no —producción no la tuvo nunca—, no se inventa: se escribe en
# `/siga/ajustes`, y hasta entonces la portada no ofrece la muestra.
#
# Sin `school_id` y sin RLS, como `siga_settings`: es de la plataforma, no de
# un colegio.
class LosAjustesEnSetup < ActiveRecord::Migration[8.1]
  def up
    create_table :setup do |t|
      t.string :nombre, null: false
      t.text :valor
      t.references :actualizado_por, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :setup, :nombre, unique: true

    execute <<~SQL
      INSERT INTO setup (nombre, valor, actualizado_por_id, created_at, updated_at)
      SELECT 'whatsapp', whatsapp, actualizado_por_id, updated_at, updated_at
      FROM siga_settings
      WHERE whatsapp IS NOT NULL AND whatsapp <> ''
      LIMIT 1
    SQL

    remove_column :siga_settings, :whatsapp

    url = ENV["SIGA_MUESTRA_URL"].to_s.strip.delete_suffix("/").presence
    return unless url

    execute <<~SQL
      INSERT INTO setup (nombre, valor, created_at, updated_at)
      VALUES ('url_de_la_muestra', #{connection.quote(url)}, now(), now())
    SQL
  end

  def down
    add_column :siga_settings, :whatsapp, :string

    execute <<~SQL
      UPDATE siga_settings
      SET whatsapp = (SELECT valor FROM setup WHERE nombre = 'whatsapp')
    SQL

    drop_table :setup
  end
end
