# Saber qué pasó con un correo después de mandarlo (MOR-189).
#
# Daniel: *«agregar incluso webhooks en ElasticEmail que nos indiquen cuándo lo
# reciban, y le colocamos una pequeña tabla de envíos, no editables, con
# opciones de ver si lo recibieron, si lo abrieron y responder directamente.
# Creo que también valdría la pena agregar la visualización de inbound. ¡Tipo
# CRM!»*.
#
# ## Por qué hacen falta tres piezas y no una columna `estado`
#
# Un correo no tiene UN estado: tiene una historia. Sale, lo aceptan, lo abren
# tres veces desde dos teléfonos, hacen clic, y a la semana rebota porque el
# buzón se llenó. Una columna `estado` guarda lo último y pierde todo lo demás
# —incluido el «rebotó DESPUÉS de que lo abrieron», que es lo que explica por
# qué la mamá vio la nota y ahora no le llega nada.
#
# Por eso: el mensaje (ya existía), sus EVENTOS, y lo que la familia CONTESTA.
#
# ## ⚠️ El token es la pieza que hace que todo esto funcione
#
# ElasticEmail avisa por un `GET` a una URL nuestra, y ese aviso tiene que poder
# decir DE CUÁL de los mensajes habla. Su `messageid` no sirve: lo asigna él
# después de recibir el correo por SMTP, y nosotros nunca lo vemos.
#
# La salida es un identificador NUESTRO que viaje con el correo y vuelva en el
# aviso. ElasticEmail lo llama `postback`: un header propio que devuelve tal
# cual en cada notificación. Y el mismo token va en el `Reply-To`, así que
# cuando la familia responde, la respuesta llega a una dirección que dice a qué
# mensaje pertenece — sin adivinar por asunto ni por remitente.
#
#   sale     →  X-PostBack: k3f9…      Reply-To: respuesta+k3f9…@…
#   abren    →  GET /webhooks/…?postback=k3f9…&status=Opened
#   responden→  POST /webhooks/…  to=respuesta+k3f9…@…
#
# Un solo dato ata las tres cosas.
class SeguirleElRastroALosCorreos < ActiveRecord::Migration[8.1]
  def change
    # ── El token, en el mensaje que ya existía ──────────────────────────────
    add_column :mensajes, :token, :string
    add_index  :mensajes, :token, unique: true

    # ⚠️ Los mensajes que ya se mandaron NO reciben token, y está bien: salieron
    # sin él, así que ningún aviso va a poder mencionarlos. Ponerles uno ahora
    # sería inventar una correlación que no existe.

    # ── Lo que pasó con él ──────────────────────────────────────────────────
    create_table :mensaje_eventos do |t|
      t.references :school,  null: false, foreign_key: true
      t.references :mensaje, null: false, foreign_key: true

      # `aceptado`, `abierto`, `clicado`, `rebotado`, `queja`, `desuscrito`.
      # Se guarda el nombre y no un número: esta tabla se lee a mano cuando
      # alguien reclama que no le llegó.
      t.string   :tipo, null: false
      t.datetime :ocurrio_en, null: false

      # Lo que el aviso traía además del tipo: IP, navegador, país, y el enlace
      # en el caso de un clic. Va en JSON porque cada evento trae campos
      # distintos y ninguno se consulta: se muestra.
      t.jsonb :detalle, null: false, default: {}

      t.timestamps
    end

    # La consulta es siempre «los eventos de este mensaje, en orden».
    add_index :mensaje_eventos, [ :mensaje_id, :ocurrio_en ]

    # ⚠️ Único por (mensaje, tipo, momento): ElasticEmail reintenta un aviso que
    # no contestó 2xx, y sin esto un problema de red de dos segundos deja «lo
    # abrió» cuatro veces en la ficha.
    #
    # No es único por (mensaje, tipo) a secas, y es a propósito: abrir un correo
    # dos veces el martes y el jueves son DOS hechos, y el segundo es el que
    # dice que la familia volvió a mirarlo.
    add_index :mensaje_eventos, [ :mensaje_id, :tipo, :ocurrio_en ], unique: true,
              name: "index_mensaje_eventos_sin_repetir"

    # ── Lo que la familia contesta ──────────────────────────────────────────
    create_table :mensajes_entrantes do |t|
      t.references :school, null: false, foreign_key: true

      # A cuál responde. Opcional: alguien puede escribirle al colegio sin que
      # haya un mensaje antes, y esa carta también hay que poder leerla.
      t.references :mensaje, foreign_key: true

      # Quién escribió, tal como venía en el sobre. Se guarda el texto y NO se
      # resuelve a un `User`: puede ser una dirección que no conocemos, y eso
      # también es información.
      t.string :de, null: false
      t.string :asunto
      t.text   :cuerpo

      t.datetime :recibido_en, null: false
      t.datetime :leido_en

      # El correo completo como llegó. Ocupa poco y es lo único que queda si
      # algún día el parseo resulta estar equivocado.
      t.jsonb :crudo, null: false, default: {}

      t.timestamps
    end

    add_index :mensajes_entrantes, [ :school_id, :recibido_en ]

    reversible do |dir|
      dir.up do
        %w[mensaje_eventos mensajes_entrantes].each do |tabla|
          execute "ALTER TABLE #{tabla} ENABLE ROW LEVEL SECURITY"
          execute "ALTER TABLE #{tabla} FORCE  ROW LEVEL SECURITY"
          execute <<~SQL.squish
            CREATE POLICY aislamiento_por_colegio ON #{tabla}
              USING (#{condicion})
              WITH CHECK (#{condicion})
          SQL
        end
      end

      dir.down do
        %w[mensaje_eventos mensajes_entrantes].each do |tabla|
          execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON #{tabla}"
        end
      end
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
