# Genera el mapa del modelo de datos leyendo `db/structure.sql`.
#
# Se genera, no se escribe a mano. Un documento del modelo escrito a mano
# envejece en silencio y termina describiendo una base que ya no existe — que es
# exactamente cómo `students.school_card` pasó meses etiquetado como "carnet del
# colegio" siendo la cédula escolar, un identificador nacional del MPPE.
#
#   bin/rails modelo:mapa           # a stdout
#   bin/rails modelo:mapa > MODELO.md
namespace :modelo do
  RUTA = Rails.root.join("db/structure.sql")

  desc "Mapa del modelo de datos, en Markdown, desde structure.sql"
  task :mapa do
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

    uniq = Hash.new { |h, k| h[k] = [] }
    sql.scan(/CREATE UNIQUE INDEX \w+ ON public\.(\w+) USING btree \(([^)]+)\)/)
       .each { |t, cols| uniq[t] << cols }

    solid    = tablas.keys.grep(/\Asolid_/)
    internas = %w[ar_internal_metadata schema_migrations]
    storage  = tablas.keys.grep(/\Aactive_storage_/)
    dominio  = (tablas.keys - solid - internas - storage).sort

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
    end
  end
end
