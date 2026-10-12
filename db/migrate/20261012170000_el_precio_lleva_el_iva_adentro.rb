# El precio es final: lleva el IVA adentro (spec `docs/specs/del-registro-al-cobro.md`,
# decisión 28).
#
#     ANTES    0,30 $ por alumno al mes + IVA, mínimo 39 $     360 alumnos: 108 + 17,28 = 125,28
#     AHORA    0,35 $ por alumno al mes, mínimo 45 $           360 alumnos: 126,00
#
# Daniel, 12 de octubre de 2026, mirando la pantalla «Suscripción» con sus tres
# renglones —monto, IVA y total—: *«se ve muy incómodo, además no podemos cobrar
# IVA en dólares, eso no es correcto. Vamos a incrementarle el IVA al costo:
# 0,30 × 1,16 = 0,348, poco menos de 0,35. Pongámoslo de una vez como el costo.»*
#
# ## Qué cambia en la base
#
#     subscription_payments.iva    se va: un reporte ya no guarda un IVA aparte
#     las suscripciones a 0,30     pasan a 0,35, y su mínimo de 39 a 45
#
# ⚠️ Lo segundo NO contradice que el precio se congela (decisión 17). Nadie pagó
# a 0,30 + IVA: en producción no hay ninguna suscripción activa, y las de una
# base local son sembradas. No hay precio viejo que respetar, y dejarlas en 0,30
# les haría pagar MENOS de lo que se decidió: el IVA que antes se sumaba aparte
# desaparecería sin haber entrado al precio.
class ElPrecioLlevaElIvaAdentro < ActiveRecord::Migration[8.1]
  def up
    # ⚠️ El RLS también filtra a quien migra si no es superusuario —en
    # producción, el rol de la app—, y un UPDATE sin colegio en contexto no toca
    # NINGUNA fila y no avisa. El bypass va LOCAL: muere con la transacción.
    execute "SET LOCAL siga.bypass_rls = 'on'"

    remove_column :subscription_payments, :iva

    # El precio por alumno y el mínimo, con el IVA adentro. Y lo que se factura
    # al mes, recalculado con la matrícula que ya tenía anotada.
    execute <<~SQL.squish
      UPDATE subscriptions
         SET precio_por_alumno = 0.35,
             minimo_mensual    = 45,
             precio_mensual    = GREATEST(ROUND(COALESCE(matricula_facturada, 0) * 0.35, 2), 45)
       WHERE plan = 5 AND precio_por_alumno = 0.30 AND minimo_mensual = 39
    SQL

    # Y los reportes que todavía esperan validación: son la cuenta que se va a
    # activar, y tiene que ser la de hoy.
    execute <<~SQL.squish
      UPDATE subscription_payments
         SET precio_por_alumno = 0.35,
             minimo_mensual    = 45,
             precio_mensual    = GREATEST(ROUND(alumnos * 0.35, 2), 45)
       WHERE precio_por_alumno = 0.30 AND minimo_mensual = 39
    SQL
  end

  def down
    execute "SET LOCAL siga.bypass_rls = 'on'"

    add_column :subscription_payments, :iva, :decimal, precision: 10, scale: 2

    execute <<~SQL.squish
      UPDATE subscription_payments
         SET precio_por_alumno = 0.30,
             minimo_mensual    = 39,
             precio_mensual    = GREATEST(ROUND(alumnos * 0.30, 2), 39)
       WHERE precio_por_alumno = 0.35 AND minimo_mensual = 45
    SQL
    execute "UPDATE subscription_payments SET iva = ROUND(precio_mensual * 0.16, 2)"
    change_column_null :subscription_payments, :iva, false

    execute <<~SQL.squish
      UPDATE subscriptions
         SET precio_por_alumno = 0.30,
             minimo_mensual    = 39,
             precio_mensual    = GREATEST(ROUND(COALESCE(matricula_facturada, 0) * 0.30, 2), 39)
       WHERE plan = 5 AND precio_por_alumno = 0.35 AND minimo_mensual = 45
    SQL
  end
end
