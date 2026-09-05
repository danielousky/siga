# El informe descriptivo que el docente escribe por alumno y lapso (MOR-216).
#
# Spec: `docs/specs/mor-216-informe-descriptivo.md`.
#
# ## Por qué tabla propia y no una columna en `report_cards`
#
# El boletín se EMITE y queda congelado; el informe se escribe **durante** el
# lapso y se corrige hasta que se emite. Meterlo en el boletín obligaría a
# emitir para poder escribir — o sea, a entregarle a la familia un papel a
# medio hacer para poder terminarlo.
#
#     escribir  ──durante el lapso──►  informes  (se edita)
#                                            │
#     emitir    ──al cerrar──────────►  report_cards.snapshot  (congelado)
#
# ## ⚠️ El nombre está en español, y es una excepción consciente
#
# La regla del proyecto es inglés en los modelos porque Rails deduce nombres
# pluralizando, y el español casi nunca pluraliza bien (`MOR-162`). Acá sí:
#
#     "informe".pluralize    # => "informes"   ✓
#     "informes".singularize # => "informe"    ✓
#
# Y «descriptive report» no es el nombre de nada: el concepto se llama *informe
# descriptivo* en el vocabulario del MPPE y en la boca de la maestra, igual que
# `Mensaje` o `Importacion`.
#
# ⚠️ Se llamó `informes_del_lapso` durante diez minutos, y no servía:
# `"informe_del_lapso".pluralize` da **«informe_del_lapsos»** — Rails pluraliza
# la ÚLTIMA palabra, y acá la que manda es la primera. Es exactamente la trampa
# que documenta `config/initializers/inflections.rb`, y se evita eligiendo un
# nombre de una sola palabra en vez de agregándole una inflexión irregular al
# proyecto.
class ElInformeDescriptivoDelDocente < ActiveRecord::Migration[8.1]
  def change
    create_table :informes do |t|
      # ⚠️ `school_id` MATERIALIZADO, no deducido por cadena: el RLS de
      # PostgreSQL evalúa columnas de la fila, no asociaciones (`MOR-85`).
      #
      # Y el guarda no habría avisado: `aislamiento_estructural_test` pregunta
      # «¿qué tablas TIENEN school_id y les falta RLS?», así que una tabla sin
      # la columna pasa en verde y la lee todo el mundo.
      t.references :school, null: false, foreign_key: true
      t.references :enrollment, null: false, foreign_key: true
      t.references :evaluation_moment, null: false, foreign_key: true

      # Quién lo escribió. No es auditoría —para eso está `activity_logs`—: la
      # boleta puede querer firmarlo, y una sección cambia de guía a mitad de
      # año.
      t.references :escrito_por, null: false, foreign_key: { to_table: :users }

      t.text :cuerpo, null: false

      t.timestamps
    end

    # UNO por alumno y lapso. Es la decisión 1 del spec, y el índice es lo que
    # la sostiene: sin él, dos pestañas abiertas escriben dos informes y la
    # boleta imprime el que salga primero.
    add_index :informes, [ :enrollment_id, :evaluation_moment_id ],
              unique: true, name: "index_informes_uno_por_alumno_y_lapso"

    reversible do |dir|
      dir.up do
        execute "ALTER TABLE informes ENABLE ROW LEVEL SECURITY"
        execute "ALTER TABLE informes FORCE  ROW LEVEL SECURITY"
        execute <<~SQL.squish
          CREATE POLICY aislamiento_por_colegio ON informes
            USING (#{condicion})
            WITH CHECK (#{condicion})
        SQL
      end

      dir.down do
        execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON informes"
      end
    end
  end

  private

  # ⚠️ La MISMA condición que las demás tablas, palabra por palabra.
  #
  # `IS NOT DISTINCT FROM` y no `=`: con `=`, una fila con `school_id` nulo no
  # empareja ni cuando el contexto también es nulo. Y `NULLIF` es lo que evita
  # que una sesión sin contexto reviente el cast en vez de devolver cero filas —
  # que es lo que tiene que pasar: sin contexto, CERO, no todas.
  def condicion
    <<~SQL.squish
      current_setting('siga.bypass_rls', true) = 'on'
      OR school_id IS NOT DISTINCT FROM NULLIF(current_setting('siga.school_id', true), '')::bigint
    SQL
  end
end
