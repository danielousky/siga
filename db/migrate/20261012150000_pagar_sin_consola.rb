# Pagar sin consola (spec: `docs/specs/del-registro-al-cobro.md`, tanda 2).
#
#     el colegio REPORTA  ──►  a SIGA le llega un correo  ──►  el fundador VALIDA en /siga
#                                                              └─►  o rechaza, con motivo
#
# Hasta hoy, que un colegio pasara a pagar exigía abrir la consola de producción.
#
# ## Dos tablas, y solo una es de un colegio
#
#     subscription_payments   lo que un COLEGIO dice que le pagó a SIGA     con RLS
#     siga_settings           el WhatsApp de SIGA y sus datos para cobrar   sin RLS
#
# La segunda es de la PLATAFORMA, como `siga_staffs`: no lleva `school_id`, y por
# eso solo se edita desde `/siga` (decisiones 20 y 21).
class PagarSinConsola < ActiveRecord::Migration[8.1]
  def change
    # ── Lo que el colegio dice que pagó ───────────────────────────────────────
    #
    # ⚠️ No reutiliza `payment_reports`: esa es la familia pagándole al COLEGIO,
    # con sus cuotas y su oficina de finanzas. Esto es el colegio pagándole a
    # SIGA. Se parecen en la forma —medio, monto, referencia, comprobante— y no
    # en nada más: quién valida, qué se abre al validar y a quién se le avisa.
    create_table :subscription_payments do |t|
      t.references :school, null: false, foreign_key: true
      t.references :reportado_por, null: false, foreign_key: { to_table: :users }

      # pago_movil · binance · efectivo. La UNIDAD del monto la da el medio:
      # bolívares el primero, dólares los otros dos (§ 4.4 del spec).
      t.string  :medio, null: false
      # ⚠️ Catorce dígitos y no diez: en bolívares, 125 $ a la tasa del día ya son
      # cinco cifras, y la tasa no espera.
      t.decimal :monto, precision: 14, scale: 2, null: false
      t.string  :referencia                      # no hay en efectivo
      t.date    :pagado_el, null: false
      t.text    :nota

      # ⚠️ La cotización con que se REPORTÓ, congelada en la fila.
      #
      # Es lo que el colegio vio en su pantalla y lo que pagó. Si inscribe diez
      # alumnos más entre que reporta y que se valida, el pago sigue siendo por
      # lo que le dijimos, no por un número que no vio.
      t.integer :alumnos, null: false
      t.decimal :precio_por_alumno, precision: 6, scale: 2, null: false
      t.decimal :minimo_mensual, precision: 8, scale: 2, null: false
      t.decimal :precio_mensual, precision: 10, scale: 2, null: false   # sin IVA
      t.decimal :iva, precision: 10, scale: 2, null: false

      t.string     :estado, null: false, default: "en_revision"
      t.references :revisado_por, foreign_key: { to_table: :users }
      t.datetime   :revisado_el
      t.text       :motivo                       # por qué se rechazó

      # El mes que pagó, escrito al validar: la historia de qué cubrió cada pago.
      t.date :cubre_desde
      t.date :cubre_hasta

      t.timestamps
    end

    add_check_constraint :subscription_payments, "medio IN ('pago_movil', 'binance', 'efectivo')",
                         name: "subscription_payments_medio_valido"
    add_check_constraint :subscription_payments, "estado IN ('en_revision', 'validado', 'rechazado')",
                         name: "subscription_payments_estado_valido"
    add_check_constraint :subscription_payments, "monto > 0", name: "subscription_payments_monto_positivo"

    # ⚠️ UN reporte en revisión por colegio, y lo dice la base (spec § 5.5). El
    # modelo lo explica con palabras; esto lo sostiene cuando dos personas de la
    # oficina reportan el mismo pago a la vez.
    add_index :subscription_payments, :school_id, unique: true, where: "estado = 'en_revision'",
              name: "index_subscription_payments_uno_en_revision"

    # ⚠️ La misma referencia no se reporta dos veces… salvo que la anterior se
    # haya RECHAZADO. Un rechazo por un monto mal escrito deja la referencia
    # buena, y el colegio tiene que poder volver a reportarla: con un índice
    # sin esa salvedad quedaría en un callejón (el mismo que tuvieron los pagos
    # de la familia).
    add_index :subscription_payments, [ :school_id, :referencia ], unique: true,
              where: "referencia IS NOT NULL AND estado <> 'rechazado'",
              name: "index_subscription_payments_sin_repetir"

    # Lo que espera en /siga, lo más viejo primero.
    add_index :subscription_payments, [ :estado, :created_at ]

    # ── Los ajustes de la plataforma ──────────────────────────────────────────
    #
    # Cambiar de número de WhatsApp o de cuenta no puede exigir un despliegue
    # (decisiones 20 y 21). Son columnas y no un `clave → valor`: cada dato
    # tiene su forma —un teléfono, un banco, una cuenta de veinte dígitos— y su
    # validación.
    create_table :siga_settings do |t|
      t.string :whatsapp                         # 0414-1234567

      # A nombre de quién se paga, y su cédula o RIF.
      t.string :titular
      t.string :documento

      t.string :pago_movil_banco                 # el código de cuatro dígitos
      t.string :pago_movil_telefono
      t.string :cuenta                           # veinte dígitos, para transferir
      t.string :binance                          # Binance Pay: el ID o el correo

      # ⚠️ Si la persona se borra, los ajustes se QUEDAN (`ON DELETE SET NULL`).
      # Son configuración de la plataforma, no datos de nadie: limpiar una demo
      # —que borra a todas las personas— no puede llevarse el WhatsApp ni las
      # cuentas con que SIGA cobra (`OrdenDeBorrado::NO_SE_TOCAN`).
      t.references :actualizado_por, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end

    # ⚠️ UNA fila, y lo dice la base. Dos filas de ajustes son dos números de
    # WhatsApp y nadie sabe cuál está en la portada.
    add_index :siga_settings, "(true)", unique: true, name: "index_siga_settings_una_sola_fila"

    reversible do |dir|
      dir.up   { aislar("subscription_payments") }
      dir.down { execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON subscription_payments" }
    end
  end

  private

  # La misma política que el resto de las tablas de un colegio (`MOR-87`).
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
