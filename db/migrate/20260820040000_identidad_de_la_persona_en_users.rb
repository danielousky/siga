# La identidad de una persona vivía repartida y con el nombre equivocado.
#
# `users.id_card` no decía qué documento guardaba, y `students.school_card` estaba
# modelado como carnet interno del plantel cuando la CÉDULA ESCOLAR es un
# identificador NACIONAL del MPPE: 12 caracteres que codifican nacionalidad, año de
# nacimiento y los últimos 8 dígitos de la cédula de la madre. Sustituye a la cédula
# de identidad en las planillas oficiales y ACOMPAÑA AL ALUMNO cuando cambia de
# plantel.
#
# Tres cosas que esta migración deja resueltas:
#
#   1. El MPPE acepta CUATRO documentos, no uno: cédula nacional (V/E), pasaporte,
#      carné diplomático, y cédula escolar cuando no hay ninguno de los anteriores.
#      `document` + `document_type` los cubre; `cedula_escolar` va aparte porque NO
#      es "otro tipo de documento": es lo que se usa mientras no hay documento.
#
#   2. Son dos columnas y no una con discriminador a propósito. El día que un alumno
#      saca su cédula nacional se llena `document` y `cedula_escolar` SE QUEDA, así
#      los boletines ya emitidos siguen siendo verificables. Con una sola columna se
#      sobrescribiría y el histórico apuntaría a un número que ya no existe.
#
#   3. El SAIME verifica el PRIMER apellido y la fecha de nacimiento contra la
#      partida de nacimiento. Con `last_name` guardando "López Medina" entero, eso
#      no puede coincidir nunca con "López".
#
# `cedula_escolar` queda en español a propósito, como `schools.dea_code`: es el
# nombre propio de un instrumento del MPPE. Y cualquier traducción empieza con
# `school_`, que es exactamente la ambigüedad que causó el bug — `school_id`
# significa "FK al colegio" en 22 tablas.
#
# Ver MOR-138.
class IdentidadDeLaPersonaEnUsers < ActiveRecord::Migration[8.1]
  def up
    # --- el documento -------------------------------------------------------
    # `id_card` no decía qué guardaba. Se renombra en vez de crear una columna
    # nueva para no perder las cédulas ya cargadas.
    rename_column :users, :id_card, :document
    add_column :users, :document_type, :integer
    add_column :users, :cedula_escolar, :string

    add_index :users, :cedula_escolar, unique: true

    # --- el nombre ----------------------------------------------------------
    rename_column :users, :name, :first_name
    add_column :users, :second_last_name, :string

    # --- lo que exigen las planillas del MPPE -------------------------------
    add_column :users, :birth_date,  :date
    add_column :users, :sex,         :integer
    add_column :users, :birth_place, :string

    # --- backfill -----------------------------------------------------------
    # Todo documento ya cargado es una cédula venezolana: los seeds solo le ponen
    # `id_card` a los profesores, con formato V-########.
    execute <<~SQL
      UPDATE users SET document_type = 0 WHERE document IS NOT NULL
    SQL

    # NO se copia `students.school_card` a `cedula_escolar`, aunque sea tentador.
    #
    # Se intentó y falló, y el fallo es la prueba de por qué existe este issue:
    #
    #   duplicate key value violates unique constraint index_users_on_cedula_escolar
    #   DETAIL: Key (cedula_escolar)=(25-019) already exists.
    #
    # 90 de los 290 alumnos comparten carnet entre los dos colegios: `25-001` es
    # Álvaro López en Bolívar y Valentina Reyes en Bello. Son numeración interna
    # de cada plantel —exactamente lo que el modelo viejo decía— y no cédulas
    # escolares, que serían únicas en todo el país.
    #
    # O sea: NO hay cédulas escolares que preservar. Copiarlas sería inventar
    # datos y además atribuirle a dos niños distintos el mismo documento nacional.
    # Las genera `db/seeds.rb`, que es de donde salieron estos registros.

    # --- partir el apellido -------------------------------------------------
    # "López Medina" → last_name "López" · second_last_name "Medina".
    #
    # Esto ADIVINA, y solo es seguro ahora: son 290 alumnos de datos de demo y
    # cero registros de producción. Un apellido compuesto real ("De La Cruz
    # Marín") se parte mal. Después de importar un colegio de verdad, este mismo
    # SQL sería destructivo.
    execute <<~SQL
      UPDATE users
         SET last_name        = split_part(last_name, ' ', 1),
             second_last_name = NULLIF(substr(last_name, strpos(last_name, ' ') + 1), last_name)
       WHERE last_name LIKE '% %'
    SQL
  end

  def down
    execute "UPDATE users SET last_name = concat_ws(' ', last_name, second_last_name)"

    remove_column :users, :birth_place
    remove_column :users, :sex
    remove_column :users, :birth_date
    remove_column :users, :second_last_name
    rename_column :users, :first_name, :name

    remove_index  :users, :cedula_escolar
    remove_column :users, :cedula_escolar
    remove_column :users, :document_type
    rename_column :users, :document, :id_card
  end
end
