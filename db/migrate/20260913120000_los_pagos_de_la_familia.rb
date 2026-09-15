# Que conste quién pagó qué (spec: `docs/specs/pagos-de-la-familia.md`).
#
# Daniel: *«el representante reporta y el administrador, la parte financiera de
# la escuela, debe poder validar esos pagos»*.
#
# ## Tres tablas, porque son TRES cosas distintas
#
#     fees              lo que el COLEGIO cobra ese año   «Inscripción · 120 $»
#     charges           lo que UN ALUMNO debe             «Pedro debe la inscripción»
#     payment_reports   lo que la MAMÁ dice que pagó      «transferí 120 $ el martes»
#
# Confundirlas es lo que hace inservibles a los sistemas de cobranza escolares:
# con una sola tabla, esas tres frases son la misma fila, y la primera no se
# puede corregir sin reescribir la historia de las otras dos.
#
# ## ⚠️ En INGLÉS, y no es gusto (§ MOR-162)
#
# La primera versión de esta migración las llamó `conceptos_de_cobro`, `cobros`
# y `reportes_de_pago`, y no llegó a correr:
#
#     "concepto_de_cobro".pluralize   #=> "concepto_de_cobros"   ✗
#     "reporte_de_pago".pluralize     #=> "reporte_de_pagos"     ✗
#
# `t.references :concepto_de_cobro` busca la tabla `concepto_de_cobros`, que no
# existe, y la migración muere a mitad con «relation does not exist». Es
# exactamente la razón por la que el proyecto escribe el modelo en inglés y las
# URL y las pantallas en español.
class LosPagosDeLaFamilia < ActiveRecord::Migration[8.1]
  TABLAS = %w[fees charges payment_reports].freeze

  def change
    # ── Lo que el colegio cobra ese año ─────────────────────────────────────
    create_table :fees do |t|
      t.references :school, null: false, foreign_key: true
      t.references :academic_period, null: false, foreign_key: true

      t.string  :nombre, null: false            # «Inscripción», «Septiembre»
      t.decimal :monto, precision: 10, scale: 2, null: false

      # ⚠️ La fecha de vencimiento es un CAMPO y no una regla en Ruby.
      #
      # En Venezuela agosto se paga en julio — y solo agosto, no todos los meses
      # adelantados. Una regla escrita en código («vence el 5 del mes anterior»)
      # habría que cambiarla por despliegue cada vez que un colegio cobre
      # distinto; un campo lo arregla la secretaria.
      t.date :vence_el, null: false

      # La inscripción primero, después los meses.
      t.integer :orden, null: false, default: 0

      t.timestamps
    end

    add_index :fees, [ :academic_period_id, :orden ]
    # Dos «Septiembre» en el mismo año es siempre un error de carga.
    add_index :fees, [ :academic_period_id, :nombre ], unique: true,
              name: "index_fees_sin_repetir"

    # ── Lo que un alumno debe ───────────────────────────────────────────────
    create_table :charges do |t|
      t.references :school, null: false, foreign_key: true
      t.references :enrollment, null: false, foreign_key: true
      t.references :fee, null: false, foreign_key: true

      # ⚠️ El monto y la fecha se COPIAN del concepto, no se leen de él.
      #
      # Es la misma razón por la que un boletín emitido guarda sus notas: si en
      # marzo el colegio sube la mensualidad, lo que Pedro debía en septiembre
      # no puede cambiar solo. Y permite la beca o el descuento por hermano sin
      # otra tabla: se baja el monto de ESTE cobro.
      t.decimal :monto, precision: 10, scale: 2, null: false
      t.date    :vence_el, null: false

      # Null mientras no esté pagado. No es una bandera `pagado`: la fecha
      # contesta además «¿cuándo?», que es la pregunta que sigue siempre.
      t.datetime :pagado_el

      t.timestamps
    end

    add_index :charges, [ :enrollment_id, :fee_id ], unique: true,
              name: "index_charges_uno_por_concepto"
    # «Qué debe este alumno», por vencimiento.
    add_index :charges, [ :enrollment_id, :vence_el ]
    # Y la de la oficina: «quién está en mora».
    add_index :charges, [ :school_id, :pagado_el, :vence_el ]

    # ── Lo que la familia dice que pagó ─────────────────────────────────────
    create_table :payment_reports do |t|
      t.references :school, null: false, foreign_key: true
      t.references :representative, null: false, foreign_key: true
      # De cuál de sus representados: las deudas son de cada inscripción.
      t.references :enrollment, null: false, foreign_key: true

      # ⚠️ Indispensable: es lo que la oficina busca en el estado de cuenta.
      t.string  :referencia, null: false
      t.string  :banco, null: false             # código de 4 dígitos
      t.decimal :monto, precision: 10, scale: 2, null: false

      # ⚠️ DOS fechas, y la diferencia importa. `created_at` es cuándo se
      # reportó; `pagado_el` es cuándo salió el dinero del banco. Un pago del 3
      # reportado el 28 está al día o en mora según cuál se mire, y la que manda
      # es la del banco.
      t.date :pagado_el, null: false

      # Casi nunca es la madre: es el papá, la abuela o el tío. Sin esto, el
      # nombre del estado de cuenta no coincide con nadie del colegio.
      t.string :depositante_nombre, null: false
      t.string :depositante_documento

      t.text :nota

      # `en_revision` → `validado` | `rechazado`.
      t.string     :estado, null: false, default: "en_revision"
      t.references :revisado_por, foreign_key: { to_table: :users }
      t.datetime   :revisado_el
      t.text       :motivo                      # por qué se rechazó

      t.timestamps
    end

    # ⚠️ Única por COLEGIO, no global: dos bancos distintos emiten el mismo
    # número de referencia todo el tiempo, y un índice global le impediría a una
    # familia reportar un pago legítimo porque otro colegio ya usó ese número.
    add_index :payment_reports, [ :school_id, :referencia ], unique: true,
              name: "index_payment_reports_sin_repetir"
    # La bandeja de la oficina: lo que espera revisión, lo más viejo primero.
    add_index :payment_reports, [ :school_id, :estado, :created_at ]
    add_index :payment_reports, [ :enrollment_id, :created_at ]

    # ── Qué cobros paga cada reporte ────────────────────────────────────────
    #
    # ⚠️ Va en `charges` y no en una tabla de unión: un cobro lo paga UN reporte
    # —el que la oficina validó— aunque un reporte pague varios cobros. Una
    # tabla de unión admitiría dos reportes validados sobre el mismo cobro, que
    # es exactamente el estado que nadie sabe deshacer.
    add_reference :charges, :payment_report, foreign_key: true, null: true

    reversible do |dir|
      dir.up   { TABLAS.each { |tabla| aislar(tabla) } }
      dir.down { TABLAS.each { |t| execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON #{t}" } }
    end
  end

  private

  def aislar(tabla)
    execute "ALTER TABLE #{tabla} ENABLE ROW LEVEL SECURITY"
    execute "ALTER TABLE #{tabla} FORCE  ROW LEVEL SECURITY"
    execute <<~SQL.squish
      CREATE POLICY aislamiento_por_colegio ON #{tabla}
        USING (#{condicion})
        WITH CHECK (#{condicion})
    SQL
  end

  def condicion
    <<~SQL.squish
      current_setting('siga.bypass_rls', true) = 'on'
      OR school_id IS NOT DISTINCT FROM NULLIF(current_setting('siga.school_id', true), '')::bigint
    SQL
  end
end
