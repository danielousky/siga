# Un niño de 2do grado no es una cuenta: es un registro.
#
# Existe en SIGA porque su nombre y su cédula escolar van en los boletines y en
# las planillas del MPPE, no porque vaya a iniciar sesión. Hasta hoy el esquema
# no permitía representarlo: `email` y `encrypted_password` eran `NOT NULL` con
# `DEFAULT ''`, así que toda persona cargada nacía con credenciales.
#
# ── Por qué el índice tiene que ser PARCIAL ─────────────────────────────────
#
# Volver `email` nullable no alcanza si el valor heredado es `''`: PostgreSQL
# trata cada NULL como distinto —por eso admite muchos—, pero `''` es un valor
# como cualquier otro y el índice único deja pasar UNO SOLO en toda la
# plataforma. Probado antes de escribir esta migración:
#
#     1) primer usuario sin correo:  OK      (email quedó como "")
#     2) segundo usuario sin correo: FALLA
#        PG::UniqueViolation: duplicate key value violates unique constraint
#                             "index_users_on_email"
#
# O sea: el alumno 2 de 360 reventaba la importación. Hacen falta las dos cosas
# —pasar los `''` a NULL y un índice `WHERE email IS NOT NULL`— y ninguna sirve
# sin la otra.
#
# `encrypted_password` va nullable por la misma razón, y es seguro por una que
# no es obvia: `Devise::Encryptor.compare` arranca con
# `return false if hashed_password.blank?`. Una persona sin contraseña NO PUEDE
# entrar por construcción, ni con la contraseña vacía. No hace falta un flag de
# cuenta activa: la ausencia de credencial ya es la respuesta.
#
# ── La normalización del documento ──────────────────────────────────────────
#
# `V-12.345.678`, `V12345678` y `12345678` son hoy tres valores distintos con
# índice único global: tres cuentas para una persona. El importador los iba a
# producir en masa, porque cada colegio escribe la cédula a su manera.
#
# Ver MOR-142.
class UnaPersonaPuedeExistirSinPoderEntrar < ActiveRecord::Migration[8.1]
  def up
    # --- el correo ----------------------------------------------------------
    change_column_default :users, :email, nil
    change_column_null    :users, :email, true
    execute "UPDATE users SET email = NULL WHERE email = ''"

    remove_index :users, :email
    add_index    :users, :email, unique: true, where: "email IS NOT NULL"

    # --- la contraseña ------------------------------------------------------
    change_column_default :users, :encrypted_password, nil
    change_column_null    :users, :encrypted_password, true
    execute "UPDATE users SET encrypted_password = NULL WHERE encrypted_password = ''"

    # --- normalizar lo ya cargado -------------------------------------------
    # Las mismas reglas que aplica `User#normalizar_identificadores` de ahora en
    # adelante. Van en SQL y no recorriendo el modelo porque tienen que correr
    # igual en un despliegue donde el código nuevo todavía no se cargó.
    #
    # Cédulas (tipos 0 y 1): solo dígitos, sin ceros a la izquierda. La
    # nacionalidad NO va en el número — sale de `document_type`, y guardarla en
    # los dos lados es invitar a que se contradigan.
    execute <<~SQL
      UPDATE users
         SET document = NULLIF(ltrim(regexp_replace(document, '[^0-9]', '', 'g'), '0'), '')
       WHERE document IS NOT NULL
         AND document_type IN (0, 1)
    SQL

    # Pasaporte y carné diplomático (tipos 2 y 3): alfanumérico en mayúscula.
    # Acá NO se puede quitar lo que no sea dígito: un pasaporte lleva letras y
    # sin ellas queda mutilado.
    execute <<~SQL
      UPDATE users
         SET document = NULLIF(upper(regexp_replace(document, '[^A-Za-z0-9]', '', 'g')), '')
       WHERE document IS NOT NULL
         AND (document_type IN (2, 3) OR document_type IS NULL)
    SQL

    # La cédula escolar NO se normaliza igual: son 12 caracteres cuyo formato
    # define el MPPE. Solo mayúsculas y quitar espacios; los guiones y las
    # letras se quedan donde están.
    execute <<~SQL
      UPDATE users
         SET cedula_escolar = NULLIF(upper(regexp_replace(cedula_escolar, '\\s', '', 'g')), '')
       WHERE cedula_escolar IS NOT NULL
    SQL
  end

  def down
    execute "UPDATE users SET email = '' WHERE email IS NULL"
    execute "UPDATE users SET encrypted_password = '' WHERE encrypted_password IS NULL"

    remove_index :users, :email
    add_index    :users, :email, unique: true

    change_column_null    :users, :email, false
    change_column_default :users, :email, ""
    change_column_null    :users, :encrypted_password, false
    change_column_default :users, :encrypted_password, ""
  end
end
