# El formulario público pedía correo obligatorio y teléfono opcional (MOR-135).
#
# Está al revés de como se contacta a un colegio en Venezuela. La conversación
# de venta ocurre por WhatsApp: el correo institucional muchas veces lo revisa
# la secretaria una vez por semana, si existe. Pedir como obligatorio el canal
# que no se usa, y como opcional el único por el que se puede responder, es
# perder al prospecto en el campo que sí completó.
#
# Tres cambios, uno por problema:
#
#   email → NULL permitido    el correo pasa a ser opcional
#   veces                     pedir la demo dos veces NO es un error: es la
#                             señal más fuerte que da un prospecto. Antes
#                             chocaba contra `validates :email, uniqueness` y
#                             la directora recibía "ya está en uso" — o sea, el
#                             sistema contestándole que se callara.
#   telefono_normalizado      los últimos 10 dígitos, para reconocer que
#                             `0424-1234567`, `+58 424 1234567` y
#                             `(0424) 123 45 67` son la misma persona.
#
# Sobre la última: es un dato DERIVADO de `phone`, materializado en su propia
# columna por la misma razón que `school_id` en las nueve tablas de `MOR-85` —
# **un índice evalúa columnas, no métodos de Ruby.** Sin columna, reconocer al
# insistente sería un `regexp_replace` por fila en cada envío.
class ElTelefonoMandaEnLasSolicitudes < ActiveRecord::Migration[8.1]
  def change
    change_column_null :demo_requests, :email, true

    add_column :demo_requests, :veces, :integer, default: 1, null: false
    add_column :demo_requests, :telefono_normalizado, :string, limit: 10

    add_index :demo_requests, :telefono_normalizado

    # Los que ya existen: se les calcula el normalizado con el mismo criterio
    # que usará el modelo, para que un prospecto viejo que vuelva a escribir
    # sea reconocido y no entre como fila nueva.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE demo_requests
             SET telefono_normalizado = RIGHT(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 10)
           WHERE phone IS NOT NULL
             AND LENGTH(REGEXP_REPLACE(phone, '[^0-9]', '', 'g')) >= 7
        SQL
      end
    end
  end
end
