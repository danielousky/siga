# La suscripción de cada colegio (MOR-108).
#
# ## Las cuatro preguntas que el issue exigía responder ANTES de modelar
#
# **1 · ¿Qué cuenta como "matrícula"?** Los alumnos con inscripción **activa en
# el año escolar vigente**. No los históricos —un colegio de veinte años tendría
# miles y pagaría el plan más caro para siempre— ni todos los `students`, que
# incluyen egresados y retirados. Es lo que el colegio tiene *hoy*, que es lo
# que el contrato mide.
#
# **2 · ¿Cuándo se recalcula el plan?** Se **observa** siempre y se **cobra** al
# renovar. Que un colegio crezca en marzo no puede cambiarle la factura de marzo:
# eso es un aumento sorpresa a mitad de año escolar, y en un mercado donde los
# colegios se conocen entre sí, es la clase de cosa que se comenta. Por eso la
# fila guarda `matricula_facturada` y `precio`: lo pactado queda escrito.
#
# **3 · ¿Qué pasa al vencer?** **Solo lectura**, y lo dice el propio issue:
# *"cortar el acceso a un colegio a mitad de año escolar es quitarle las notas de
# sus alumnos — se gana la disputa de cobranza y se pierde el cliente y su
# reputación en la red"*. El colegio sigue viendo y descargando todo; lo que no
# puede es cargar nada nuevo.
#
# **4 · ¿Más de 800 alumnos?** `a_convenir`, sin precio automático. El contrato
# solo llega a 800 y arriba de eso están las redes (AVEC, ANDIEP, Fe y Alegría),
# donde la suscripción probablemente sea de la RED y no del colegio. Inventar un
# precio ahí sería inventar un producto que nadie definió.
#
# ## Sin `school_id`… pero con referencia a `schools`
#
# Ojo con la asimetría: la tabla **sí** tiene `school_id`, así que **sí** lleva
# RLS como las otras veinte. Es dato *de* un colegio —su plan, su estado— y el
# colegio tiene derecho a saber si está al día.
#
# Lo que NO es dato del colegio es la vista de la CARTERA: quién debe, cuánto
# factura la plataforma. Eso se mira desde `/siga`, que corre sin colegio.
class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :school, null: false, foreign_key: true, index: { unique: true }

      t.integer :plan,   null: false, default: 0
      t.integer :status, null: false, default: 0

      # Lo pactado, congelado. Que el colegio crezca no cambia lo que se le cobra
      # hasta la renovación — ver la pregunta 2.
      t.integer :matricula_facturada
      t.integer :precio_mensual

      t.date :vigente_desde
      t.date :vigente_hasta

      # Cuántos días después del vencimiento sigue pudiendo escribir. Un colegio
      # que se atrasa una semana en agosto no puede quedarse sin cargar notas el
      # lunes: la cobranza en Venezuela es lenta por razones que no son del
      # colegio.
      t.integer :dias_de_gracia, null: false, default: 15

      t.text :notas

      t.timestamps
    end

    add_check_constraint :subscriptions, "plan IN (0, 1, 2, 3)",   name: "subscriptions_plan_valido"
    add_check_constraint :subscriptions, "status IN (0, 1, 2, 3)", name: "subscriptions_status_valido"

    add_index :subscriptions, [:status, :vigente_hasta]

    reversible do |dir|
      dir.up do
        execute "ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY"
        execute "ALTER TABLE subscriptions FORCE  ROW LEVEL SECURITY"
        execute <<~SQL.squish
          CREATE POLICY aislamiento_por_colegio ON subscriptions
            USING (#{condicion})
            WITH CHECK (#{condicion})
        SQL
      end

      dir.down { execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON subscriptions" }
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
