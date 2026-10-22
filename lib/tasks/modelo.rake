# Genera el mapa del modelo de datos leyendo `db/structure.sql`.
#
# Se genera, no se escribe a mano. Un documento del modelo escrito a mano
# envejece en silencio y termina describiendo una base que ya no existe — que es
# exactamente cómo `students.school_card` pasó meses etiquetado como "carnet del
# colegio" siendo la cédula escolar, un identificador nacional del MPPE.
#
#   bin/rails modelo:mapa           # el inventario, columna por columna
#   bin/rails modelo:erd            # el diagrama, en Mermaid
#
# ⚠️ El ERD del documento «Modelo de datos» de Linear se pega de `modelo:erd`.
# Estuvo escrito a mano y envejeció exactamente como este archivo advierte: decía
# «27 tablas de dominio · 22 con RLS» cuando ya eran 31 y 26, y seguía dibujando
# el profesor guía colgado del GRADO tres semanas después de moverlo a la
# sección. Un diagrama a mano es la misma deuda que un inventario a mano.
namespace :modelo do
  RUTA = Rails.root.join("db/structure.sql")

  # Todo lo que las dos tareas necesitan saber de `structure.sql`, leído UNA vez.
  Esquema = Struct.new(:tablas, :pks, :fks, :uniq, :condicionados, :rls, :force, :dominio,
                       :solid, :storage, keyword_init: true)

  def self.leer_el_esquema
    sql = File.read(RUTA)

    tablas = sql.scan(/CREATE TABLE public\.(\w+) \((.*?)\n\);/m).to_h do |t, cuerpo|
      cols = cuerpo.lines.filter_map do |l|
        l = l.strip.chomp(",")
        next if l.empty? || l.start_with?("CONSTRAINT", "PRIMARY", "CHECK")
        nombre, resto = l.split(" ", 2)
        next unless resto
        tipo = resto.split(" DEFAULT").first.to_s
          .sub("character varying", "texto")
          .sub("timestamp(6) without time zone", "fecha")
          .sub("bigint", "int8").sub("integer", "int").strip
        [ nombre, tipo ]
      end
      [ t, cols ]
    end

    pks   = sql.scan(/ALTER TABLE ONLY public\.(\w+)\s+ADD CONSTRAINT \w+ PRIMARY KEY \(([^)]+)\)/m).to_h
    rls   = sql.scan(/ALTER TABLE public\.(\w+) ENABLE ROW LEVEL SECURITY/).flatten.to_set
    force = sql.scan(/ALTER TABLE ONLY public\.(\w+) FORCE ROW LEVEL SECURITY/).flatten.to_set

    fks = Hash.new { |h, k| h[k] = [] }
    sql.scan(/ALTER TABLE ONLY public\.(\w+)\s+ADD CONSTRAINT \w+ FOREIGN KEY \((\w+)\) REFERENCES public\.(\w+)/m)
       .each { |t, col, dest| fks[t] << [ col, dest ] }

    # ⚠️ Un único PARCIAL con una condición de negocio NO es una clave.
    #
    # «Una fila por colegio MIENTRAS esté en revisión» (`subscription_payments`)
    # no dice que el colegio tenga un solo pago: tiene uno por mes. Leído como
    # clave, el diagrama dibujaba un 1:1 que no existe. Lo que sí sigue siendo
    # clave es el parcial de «si no es nulo» —el correo, el RIF, el código DEA—:
    # ahí la condición solo dice que el dato es opcional.
    uniq = Hash.new { |h, k| h[k] = [] }
    condicionados = Hash.new { |h, k| h[k] = [] }
    sql.scan(/CREATE UNIQUE INDEX \w+ ON public\.(\w+) USING btree \(([^)]+)\)(?: WHERE (.+))?;/)
       .each do |t, cols, condicion|
         if condicion.nil? || condicion.match?(/\A\(\w+ IS NOT NULL\)\z/)
           uniq[t] << cols
         else
           condicionados[t] << [ cols, condicion ]
         end
       end

    solid    = tablas.keys.grep(/\Asolid_/)
    internas = %w[ar_internal_metadata schema_migrations]
    storage  = tablas.keys.grep(/\Aactive_storage_/)
    dominio  = (tablas.keys - solid - internas - storage).sort

    Esquema.new(tablas:, pks:, fks:, uniq:, condicionados:, rls:, force:, dominio:, solid:, storage:)
  end

  desc "Mapa del modelo de datos, en Markdown, desde structure.sql"
  task :mapa do
    e = leer_el_esquema
    tablas, pks, fks, uniq = e.tablas, e.pks, e.fks, e.uniq
    rls, force, dominio    = e.rls, e.force, e.dominio
    solid, storage         = e.solid, e.storage

    puts "# Modelo de datos de SIGA"
    puts
    puts "> **Generado desde `db/structure.sql`** con `bin/rails modelo:mapa`."
    puts "> No editar a mano: se regenera. Última generación: #{begin; m=%w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre]; d=Date.current; "#{d.day} de #{m[d.month-1]} de #{d.year}"; end}."
    puts
    puts "#{dominio.size} tablas de dominio · #{rls.size} con RLS · #{force.size} con `FORCE` · " \
         "#{solid.size} de Solid Queue (sin RLS a propósito) · #{storage.size} de Active Storage"
    puts
    puts "## Quién es de un colegio y quién no"
    puts
    globales   = dominio.reject { |t| rls.include?(t) }
    por_colegio = dominio.select { |t| rls.include?(t) }
    puts "```"
    puts "GLOBALES (sin school_id, sin RLS)      POR COLEGIO (school_id + RLS + FORCE)"
    puts "-------------------------------------  -------------------------------------"
    [ globales.size, por_colegio.size ].max.times do |i|
      puts format("%-38s %s", globales[i] || "", por_colegio[i] || "").rstrip
    end
    puts "```"
    puts
    puts "## Tablas"
    puts
    dominio.each do |t|
      candado = rls.include?(t) ? "🔒" : "🌐"
      puts "### #{candado} `#{t}`"
      puts
      puts "PK: `#{pks[t] || '—'}`#{rls.include?(t) ? ' · RLS' : ''}#{force.include?(t) ? ' + FORCE' : ''}"
      puts
      puts "| Columna | Tipo |"
      puts "| -- | -- |"
      tablas[t].each { |c, ty| puts "| `#{c}` | #{ty} |" }
      puts
      unless fks[t].empty?
        puts "**Apunta a:** " + fks[t].map { |c, d| "`#{c}` → `#{d}`" }.join(" · ")
        puts
      end
      unless uniq[t].empty?
        puts "**Únicos:** " + uniq[t].map { |c| "`(#{c})`" }.join(" · ")
        puts
      end
      unless e.condicionados[t].empty?
        puts "**Únicos, con condición:** " +
             e.condicionados[t].map { |c, condicion| "`(#{c})` si `#{condicion}`" }.join(" · ")
        puts
      end
    end
  end

  # ── El diagrama, en Mermaid ────────────────────────────────────────────────
  #
  # ⚠️ Las flechas `school_id → schools` NO se dibujan, y es una decisión.
  #
  # Veintidós tablas la llevan, casi todas MATERIALIZADA por `DerivesSchoolFrom`
  # —o sea que no es una relación del dominio, es el eje de inquilino—. Dibujarlas
  # convierte el ERD en una estrella donde todo apunta a `schools` y no se
  # distingue ninguna otra cosa. La columna igual aparece como atributo de cada
  # tabla que la tiene, así que el dato no se pierde: lo que se quita es el ruido.
  #
  # Sí se dibujan las de `schools` a lo que cuelga de él ESTRUCTURALMENTE —el año
  # escolar, los grados, las materias— porque ahí la relación es real.
  ESTRUCTURALES_DE_SCHOOL = %w[
    academic_periods grades departments subjects subscriptions subscription_payments
    importaciones activity_logs
  ].freeze

  # Lo que no se dibuja: los timestamps, la fontanería de Devise y el `_type` de
  # una asociación polimórfica. ⚠️ `document_type` NO entra acá: dice CUÁL de los
  # cuatro documentos del MPPE es, que es justo lo que hay que ver.
  RUIDO = %w[
    created_at updated_at subject_type
    reset_password_token reset_password_sent_at remember_created_at
    encrypted_password
  ].freeze

  # ⚠️ El ORDEN DE LECTURA del dominio, y no el alfabético.
  #
  # `dominio` viene ordenado alfabéticamente, que para un ERD es el peor orden
  # posible: pone `activity_grades` antes que `academic_periods` y el diagrama se
  # lee a saltos. Un ERD se recorre como se recorre el negocio — la persona, el
  # colegio, la estructura del año, la evaluación, lo que sale de todo eso.
  #
  # Lo que no esté acá cae al final, y eso es señal de que hay una tabla nueva
  # sin ubicar en el relato. Lo cuida `erd_del_modelo_test`.
  ORDEN = %w[
    users students teachers admins representatives siga_staffs addresses
    student_representatives
    schools subscriptions subscription_payments
    academic_periods grades sections departments subjects grade_subjects
    bell_schedules time_slots lessons
    enrollments teacher_sections
    evaluation_moments competencies indicators
    evaluation_activities activity_competencies activity_grades
    moment_grades final_grade_books rubrics
    attendances report_cards section_closures constancias informes
    fees charges payment_reports
    importaciones mensajes mensaje_eventos mensajes_entrantes
    activity_logs demo_requests siga_settings setup
    planteles_oficiales
  ].freeze

  # ⚠️ Lo que `structure.sql` NO sabe, y es la mitad del valor de un ERD.
  #
  # La estructura se genera; el SIGNIFICADO se escribe una vez acá y viaja con
  # ella. Sin esto el diagrama dice `texto last_name` y calla que es el PRIMER
  # apellido, que es el que valida el SAIME y el que hace que una constancia
  # coincida con la partida de nacimiento.
  #
  # Es poco y es greppable: si una columna cambia de sentido, se corrige en un
  # solo lugar y el diagrama entero se entera.
  GLOSA = {
    "users.email"                    => "opcional — un niño de 8 años no tiene",
    "users.document"                 => "cédula, pasaporte o carné; único GLOBAL",
    "users.document_type"            => "cuál de los cuatro que acepta el MPPE",
    "users.cedula_escolar"           => "la asigna el MPPE; acompaña al alumno de plantel",
    "users.last_name"                => "el PRIMER apellido — es el que valida el SAIME",
    "schools.dea_code"               => "lo asigna el MPPE; único global",
    "constancias.code"               => "único GLOBAL: se teclea en /verificar sin sesión",
    "constancias.snapshot"           => "lo que decía el papel el día que se emitió",
    "schools.tope_de_arrastre"       => "materias pendientes que aún promueven — 2",
    "schools.pasos_omitidos"         => "lo ÚNICO que el arranque guarda",
    "students.school_card"           => "el carnet del plantel; único POR COLEGIO",
    "admins.role"                    => "director · asistente · coordinador · finanzas · secretaria",
    "grades.name"                    => "lo fija el Reglamento de la LOE — son quince",
    "grades.level"                   => "DEDUCIDO del nombre, no capturado",
    "grades.escala"                  => "numérica 1-20 · literal A-E",
    "grades.coordinator_teacher_id"  => "opcional — coordina a los guías, NO pasa lista",
    "sections.name"                  => "A · B · U1 — corto y en MAYÚSCULA",
    "sections.leader_teacher_id"     => "el profesor guía — SÍ pasa lista",
    "subjects.code"                  => "MAT · CAS · FIS; único por colegio",
    "subjects.name"                  => "MAYÚSCULA en la base, Tipo Título en pantalla",
    "subjects.escala"                => "opcional: pisa la del grado",
    "enrollments.status"             => "regular · retirado",
    "evaluation_moments.name"        => "I · II · III Lapso — SIN peso (Art. 111)",
    "evaluation_activities.weight_percentage" => "el 70/30 del Art. 111",
    "activity_grades.score"          => "entero del 1 al 20 — Art. 108",
    "moment_grades.origen"           => "calculada · importada",
    "final_grade_books.annual_average"      => "promedio SIMPLE de los lapsos — Art. 111",
    "final_grade_books.remedial_exam_score" => "la reparación — Art. 112, es la definitiva",
    "final_grade_books.origen"       => "calculada · importada — la importada no se recalcula",
    "attendances.status"             => "presente · ausente · tarde",
    "report_cards.code"              => "el que verifica el QR",
    "report_cards.snapshot"          => "CONGELADO al emitir",
    "subscriptions.plan"             => "gratis · por_alumno — un solo plan, sin nombres",
    "subscriptions.precio_por_alumno" => "CONGELADO al activarse — el que entró a 0,35 sigue a 0,35",
    "subscriptions.vigente_hasta"    => "el día que vence; de ahí, 15 de gracia y solo lectura",
    "subscription_payments.medio"    => "pago_movil · binance · paypal · efectivo — da la unidad del monto",
    "subscription_payments.monto"    => "lo que dice el comprobante: Bs o dólares, según el medio",
    "subscription_payments.precio_mensual" => "la cuenta con que se REPORTÓ, congelada",
    "subscription_payments.estado"   => "en_revision · validado · rechazado — uno en revisión a la vez",
    "subscription_payments.cubre_desde" => "el mes que pagó, escrito al validar",
    "setup.nombre"                   => "whatsapp · url_de_la_muestra · binance · paypal — solo los que el código conoce",
    "setup.valor"                    => "vacío es «no hay»: sin WhatsApp no hay botón ni efectivo",
    "siga_settings.cuenta"           => "veinte dígitos; el banco, los cuatro primeros",
    "importaciones.tipo"             => "matrícula · pensum · historial",
    "mensajes.correo"                => "CONGELADO — a dónde fue de verdad",
    "mensaje_eventos.tipo"           => "enviado · abierto · rebotó",
    "demo_requests.current_system"   => "qué sistema usa hoy el colegio",
    # ⚠️ NO es una FK a `subjects`: es la mitad de una asociación POLIMÓRFICA
    # (`subject_type` + `subject_id`), y el diagrama la marca FK porque termina
    # en `_id`. Decirlo acá es más barato que enseñarle polimorfismo al parser.
    "activity_logs.subject_id"       => "polimórfico: NO apunta a subjects",
    "rubrics.code"                   => "PC · PA · PI · PD · NP — lo que se imprime",
    "rubrics.valor"                  => "el PISO de la banda, no el tope",
    "competencies.descripcion"       => "prosa del docente, tal cual la escribió",
    "competencies.descripcion_canonica" => "sin acentos y en minúscula, SOLO para el índice único",
    "indicators.descripcion"         => "describe la competencia; NO se califica"
  }.freeze

  def self.en_orden(tablas)
    tablas.sort_by { |t| [ ORDEN.index(t) || ORDEN.size, t ] }
  end

  desc "El diagrama entidad-relación, en Mermaid, desde structure.sql"
  task :erd do
    e = leer_el_esquema

    # Una FK con índice único de UNA columna es un 1:1 — `subscriptions.school_id`
    # es «un plan por colegio». Se DEDUCE del índice, no se escribe a mano.
    uno_a_uno = ->(tabla, col) { e.uniq[tabla].include?(col) }

    puts "```mermaid"
    puts "erDiagram"

    en_orden(e.dominio).each do |tabla|
      e.fks[tabla].each do |col, destino|
        next if col == "school_id" && !ESTRUCTURALES_DE_SCHOOL.include?(tabla)

        # El nombre de la FK se muestra solo cuando aporta: hay DOS que van a
        # `users` desde `attendances` y hay que poder distinguirlas.
        etiqueta = col.sub(/_id\z/, "")
        etiqueta = "" if etiqueta == destino.singularize
        cardinalidad = uno_a_uno.call(tabla, col) ? "||--o|" : "||--o{"

        puts %(    #{destino} #{cardinalidad} #{tabla} : "#{etiqueta}")
      end
    end

    puts

    en_orden(e.dominio).each do |tabla|
      puts "    #{tabla} {"
      e.tablas[tabla].each do |col, tipo|
        next if RUIDO.include?(col)

        marca =
          if col == e.pks[tabla] then "PK"
          elsif col.end_with?("_id") then "FK"
          elsif e.uniq[tabla].include?(col) then "UK"
          end
        glosa = GLOSA["#{tabla}.#{col}"]

        # ⚠️ Mermaid no admite espacios ni la precisión entre paréntesis en el
        # tipo: `numeric(5,2)` rompe el parseo por la coma. Y la precisión no es
        # información de un ERD — el inventario de `modelo:mapa` la tiene.
        limpio = tipo.sub(" NOT NULL", "").sub(/\(.*\)/, "").strip.tr(" ", "_")
        linea  = [ limpio, col, marca ].compact.join(" ")
        linea += %( "#{glosa.tr('"', "'")}") if glosa

        puts "        #{linea}"
      end
      puts "    }"
    end

    puts "```"
  end

  # Los documentos del modelo, ESCRITOS en el repo y no solo impresos en la
  # consola (13 de octubre de 2026). Daniel, sobre los diagramas ER de febrero
  # que vivían en la carpeta madre: *«el diagrama ER, actualizarlo siempre»*.
  #
  #     docs/modelo/diagrama-er.md    el Mermaid, que GitHub dibuja al abrirlo
  #     docs/modelo/mapa.md           el inventario, columna por columna
  #     docs/modelo/diagrama-er.pdf   el mismo diagrama, para mirarlo o mandarlo
  #
  # ⚠️ «Siempre» lo cuida `erd_del_modelo_test`: si cambia `structure.sql` y
  # `diagrama-er.md` no se regenera, el CI se pone en rojo y dice cómo
  # arreglarlo. El PDF se copia además a la carpeta madre de SIGA, donde estaban
  # los de febrero, si esa carpeta existe.
  desc "Regenera docs/modelo/ —el diagrama, el mapa y el PDF— desde structure.sql"
  task documentos: :environment do
    carpeta = Rails.root.join("docs/modelo")
    FileUtils.mkdir_p(carpeta)

    salida_de = lambda do |tarea|
      captura = StringIO.new
      $stdout = captura
      Rake::Task[tarea].reenable
      Rake::Task[tarea].invoke
      captura.string
    ensure
      $stdout = STDOUT
    end

    diagrama = salida_de.call("modelo:erd")
    File.write(carpeta.join("diagrama-er.md"), diagrama)
    File.write(carpeta.join("mapa.md"), salida_de.call("modelo:mapa"))
    puts "✓ docs/modelo/diagrama-er.md y mapa.md"

    pdf = DocumentoImpreso.desde_html(<<~HTML, carpeta.join("diagrama-er.pdf"), espera: 20_000)
      <!doctype html><html lang="es"><head><meta charset="utf-8">
      <title>SIGA · Modelo de datos</title>
      <style>
        @page { size: 1189mm 560mm; margin: 12mm; }
        body { font-family: -apple-system, "Segoe UI", sans-serif; color: #2c2c2c; margin: 0; }
        h1 { font-size: 28px; margin: 0 0 4px; }
        p { margin: 0 0 18px; color: #5a5a5a; font-size: 15px; }
        .mermaid svg { max-width: 100% !important; height: auto; }
      </style></head><body>
      <h1>SIGA · Modelo de datos</h1>
      <p>Generado desde <code>db/structure.sql</code> con <code>bin/rails modelo:documentos</code>, el #{I18n.l(Date.current, format: :long)}.</p>
      <pre class="mermaid">#{CGI.escapeHTML(diagrama[/```mermaid\n(.*)\n```/m, 1])}</pre>
      <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
      <script>mermaid.initialize({ startOnLoad: true, theme: "neutral", er: { useMaxWidth: true } });</script>
      </body></html>
    HTML
    puts "✓ #{pdf.relative_path_from(Rails.root)}"

    copia = DocumentoImpreso.copiar_a_la_carpeta_madre(pdf, "SIGA - Modelo de datos.pdf")
    puts "✓ copiado a #{copia}" if copia
  end
end
