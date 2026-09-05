# Herramientas para mirar y limpiar los datos de demostración (MOR-146).
#
# ## Por qué son tareas del repo y no comandos sueltos
#
# En producción se corren con `dokku run`, que **parte el comando por espacios**:
# un `bin/rails runner "..."` con un bloque de Ruby llega despedazado y ejecuta
# cualquier otra cosa. Comprobado — un intento de contar filas terminó corriendo
# la verificación de RLS.
#
# Una tarea es un solo token. Y además queda versionada: lo que se corrió contra
# la base de producción se puede leer después, que es la mitad de poder confiar
# en lo que pasó.
namespace :demo do
  desc "Qué hay en la base, sin tocar nada (MOR-146)"
  task inventario: :environment do
    Current.sin_aislamiento do
      puts ""
      puts "═══ INVENTARIO · #{Rails.env} · #{Time.current.strftime('%d/%m/%Y %H:%M')} ═══"
      puts ""

      puts "COLEGIOS (#{School.count})"
      School.order(:id).each do |c|
        alumnos = Student.unscoped.where(school_id: c.id).count
        puts format("  %-30s dea=%-12s alumnos=%s", c.name, c.dea_code, alumnos)
      end

      puts ""
      puts "PERSONAS (#{User.count})"
      sin_id = User.where(document: nil, cedula_escolar: nil)
      puts "  sin ningún identificador: #{sin_id.count}"
      puts "  con correo:               #{User.where.not(email: nil).count}"

      puts ""
      puts "ROLES"
      { "Student" => Student, "Teacher" => Teacher, "Admin" => Admin,
        "Representative" => Representative, "SigaStaff" => SigaStaff }.each do |nombre, modelo|
        puts format("  %-16s %s", nombre, modelo.unscoped.count)
      end

      puts ""
      puts "EQUIPO DE SIGA — quién puede ver TODOS los colegios"
      SigaStaff.unscoped.includes(:user).each do |s|
        puts format("  %-28s %s", s.user.email, s.role)
      end

      puts ""
      puts "LO QUE NO ES DE DEMO Y NO SE PUEDE PERDER"
      puts "  solicitudes de demo (leads): #{DemoRequest.count}"
      puts "  suscripciones:               #{Subscription.count}"
      puts "  importaciones:               #{Importacion.unscoped.count}"
      puts "  registro de actividad:       #{ActivityLog.unscoped.count}"

      puts ""
      puts "DATOS ACADÉMICOS"
      { "Inscripciones" => Enrollment, "Notas de lapso" => MomentGrade,
        "Notas definitivas" => FinalGradeBook, "Boletines emitidos" => ReportCard,
        "Asistencias" => Attendance }.each do |nombre, modelo|
        puts format("  %-20s %s", nombre, modelo.unscoped.count)
      end
      puts ""
    end
  end

  # ⚠️ Borra en ORDEN y dentro de UNA transacción, en vez de truncar.
  #
  # `db:seed:replant` usa `TRUNCATE`, y eso trae dos problemas en esta app:
  #
  #   1. **Privilegios.** La app se conecta como `siga_app`, que no es dueño de
  #      las tablas a propósito (es lo que hace que el RLS se evalúe). `TRUNCATE`
  #      es privilegio de tabla, y descubrirlo A MITAD del truncado deja la base
  #      partida: unas tablas vacías y otras no.
  #   2. **No es atómico entre tablas.** Un `DELETE` ordenado dentro de una
  #      transacción sí lo es: o se borra todo, o no se borra nada.
  #
  # `delete_all` y no `destroy_all`: los `dependent: :restrict_with_error` están
  # para que nadie borre un grado con alumnos por accidente desde una pantalla.
  # Acá el orden es explícito y las claves foráneas son la red — si el orden
  # estuviera mal, la base lo rechaza en vez de dejar filas huérfanas.
  #
  # ⚠️ El orden va de HIJOS a PADRES, y `siga_staffs` está en la lista por una
  # razón que costó un intento fallido contra producción: **también apunta a
  # `users`**. Sin él, el `DELETE FROM users` choca contra su clave foránea, la
  # transacción entera se deshace, y —si nadie comprueba— la tarea informa que
  # borró todo habiendo borrado nada.
  #
  # Que se borre es además lo correcto: `dev.demo@siga.local` quedó ahí desde el
  # primer sembrado, con rol `fundador`, o sea con acceso a todos los colegios de
  # la plataforma. Los seeds recrean el equipo con cuentas conocidas.
  EN_ORDEN_DE_BORRADO = %w[
    activity_grades moment_grades final_grade_books report_cards attendances
    evaluation_activities teacher_sections student_representatives enrollments
    grade_subjects sections evaluation_moments academic_periods
    subjects departments grades
    students teachers admins representatives
    subscriptions importaciones activity_logs addresses
    siga_staffs users schools
  ].freeze

  desc "Borra TODA la demo y la vuelve a sembrar (MOR-146). Exige respaldo previo."
  task limpiar: :environment do
    Rake::Task["demo:es_solo_demo"].invoke

    unless ENV["SIGA_RESPALDO_VERIFICADO"] == "1"
      abort "\n🚫 Falta SIGA_RESPALDO_VERIFICADO=1.\n" \
            "   No es burocracia: esto no se puede deshacer.\n" \
            "   Exporta la base, restáurala en otra aparte, cuenta las filas, y entonces sí.\n"
    end

    # ⚠️ Lo que se va a perder, ANTES de perderlo y en voz alta.
    #
    # La tarea ya avisaba que era irreversible; lo que no decía es CUÁNTO. Un
    # «esto no se puede deshacer» abstracto se lee y se sigue; «293 alumnos y
    # 20 boletines» se lee distinto.
    Current.sin_aislamiento do
      puts ""
      puts "═══ SE VA A BORRAR ═══"
      puts format("  %-22s %s", "colegios", School.count)
      puts format("  %-22s %s", "personas", User.count)
      puts format("  %-22s %s", "alumnos", Student.unscoped.count)
      puts format("  %-22s %s", "notas cargadas", ActivityGrade.unscoped.count)
      puts format("  %-22s %s", "boletines emitidos", ReportCard.unscoped.count)
      puts format("  %-22s %s", "registro de actividad", ActivityLog.unscoped.count)
      puts ""
    end

    antes = Current.sin_aislamiento { [ School.count, User.count ] }

    Current.sin_aislamiento do
      ActiveRecord::Base.transaction do
        EN_ORDEN_DE_BORRADO.each do |tabla|
          cuantas = ActiveRecord::Base.connection.select_value("SELECT count(*) FROM #{tabla}").to_i
          next if cuantas.zero?

          ActiveRecord::Base.connection.execute("DELETE FROM #{tabla}")
          puts format("  borradas %6d de %s", cuantas, tabla)
        end
      end
    end

    # ⚠️ COMPROBAR, no suponer. Esta es la lección del primer intento contra
    # producción: la transacción se deshizo por una clave foránea y la tarea
    # igual anunció «base vacía». Un borrado que informa lo que no hizo es peor
    # que uno que falla, porque el siguiente paso —resembrar— se ejecuta sobre
    # datos que se creían borrados.
    quedan = Current.sin_aislamiento do
      EN_ORDEN_DE_BORRADO.filter_map do |tabla|
        cuantas = ActiveRecord::Base.connection.select_value("SELECT count(*) FROM #{tabla}").to_i
        "#{tabla}=#{cuantas}" if cuantas.positive?
      end
    end

    if quedan.any?
      abort "\n🚫 EL BORRADO NO PERSISTIÓ. Todavía hay filas en: #{quedan.join(' ')}\n" \
            "   La transacción se deshizo —casi seguro una clave foránea contra una\n" \
            "   tabla que falta en EN_ORDEN_DE_BORRADO—. La base quedó como estaba.\n" \
            "   NO corras los seeds hasta resolver esto.\n"
    end

    puts ""
    puts "✅ Base vacía, comprobado tabla por tabla."
    puts "   Antes había #{antes[0]} colegios y #{antes[1]} personas."
    puts "   Ahora corre los seeds con SIGA_ENTORNO_DEMO=1 y SIGA_SEED_PASSWORD."
    puts ""
  end

  # ⚠️ Esta es la comprobación que el issue pide ANTES de tocar nada, y no es
  # ceremonia: borrar acá se lleva por delante cualquier colegio real que
  # hubiera entrado.
  desc "¿Es seguro resembrar? Falla si hay algo que no sea la demo (MOR-146)"
  task es_solo_demo: :environment do
    Current.sin_aislamiento do
      esperados = [ "U.E. Simón Bolívar", "U.E. Andrés Bello" ]

      # ⚠️ Los colegios que alguien REGISTRÓ y que igual se van, uno por uno y
      # con su nombre escrito.
      #
      # No es una excepción cómoda: es el registro de una decisión que se tomó
      # mirando los datos. El 5 de septiembre de 2026 había dos colegios que no
      # eran de la demo —«U.E. Ceapucv», registrado por Yoleima Contreras con
      # tres alumnos, y «LA ESCUELITA», de Daniel, vacío— y Daniel autorizó
      # borrar los dos: pruebas del registro, no clientes.
      #
      # Se pasan por variable de entorno y no se escriben acá a propósito. El
      # que venga después NO puede heredar el permiso de borrar el colegio de
      # alguien: tiene que volver a mirar `demo:procedencia`, decidir, y
      # escribir los nombres él.
      autorizados = ENV["SIGA_BORRAR_TAMBIEN"].to_s.split("|").map(&:strip).compact_blank
      encontrados = School.order(:id).pluck(:name)

      # ⚠️ Se comparan los nombres NORMALIZADOS, no literales.
      #
      # `School` guarda el nombre en mayúscula desde `MOR-…`, pero los colegios
      # sembrados antes de esa regla quedaron como «U.E. Simón Bolívar». Con
      # comparación literal, el guarda decía que la propia demo «NO es de la
      # demo» —y en producción pasaba por casualidad, porque ahí los nombres
      # son los viejos—. Un guarda que depende de cuándo se sembró la fila es
      # un guarda que va a fallar el día que importa.
      igual = ->(a, b) { Normaliza.para_comparar(a) == Normaliza.para_comparar(b) }
      permitidos = esperados + autorizados

      problemas = []
      inesperados = encontrados.reject { |c| permitidos.any? { |p| igual.(c, p) } }
      problemas << "colegios que NO son de la demo: #{inesperados.join(', ')}" if inesperados.any?

      if autorizados.any?
        puts ""
        puts "⚠️  Se van a borrar TAMBIÉN estos colegios, autorizados a mano:"
        autorizados.each do |nombre|
          colegio = School.all.find { |c| igual.(c.name, nombre) }
          if colegio.nil?
            puts "   · #{nombre} — NO EXISTE (¿nombre mal escrito?)"
            next
          end
          Current.en_el_colegio(colegio) do
            quien = colegio.registrado_por
            puts "   · #{nombre} — lo registró #{quien&.email || 'el equipo'} · " \
                 "#{Student.count} alumnos · #{ActivityGrade.count} notas"
          end
        end
        puts ""
      end

      # Un boletín emitido es un papel que salió a una familia. Si existe, alguien
      # usó esto de verdad y truncar deja de ser una decisión técnica.
      if ReportCard.unscoped.where.not(code: nil).count.positive? && inesperados.any?
        problemas << "hay boletines emitidos en un colegio que no es de la demo"
      end

      if problemas.any?
        puts ""
        puts "🚫 NO ES SEGURO RESEMBRAR:"
        problemas.each { |p| puts "   · #{p}" }
        puts ""
        abort "Abortado. Truncar acá borraría datos que no son de demostración."
      end

      puts ""
      puts "✅ Solo hay datos de demostración: #{encontrados.join(' · ')}"
      puts "   Resembrar es seguro. El respaldo sigue siendo obligatorio."
      puts ""
    end
  end
  # mostrándole el producto a un cliente, y borrar el segundo no se deshace.
  desc "Quién creó cada colegio y qué tiene adentro (MOR-146)"
  task procedencia: :environment do
    Current.sin_aislamiento do
      puts ""
      puts "═══ PROCEDENCIA · #{Rails.env} · #{Time.current.strftime('%d/%m/%Y %H:%M')} ═══"
      puts ""

      School.order(:id).each do |c|
        quien = c.registrado_por
        puts "#{c.name}  (dea #{c.dea_code})"
        puts "  creado          #{c.created_at.strftime('%d/%m/%Y %H:%M')}"
        puts "  lo registró     #{quien ? "#{quien.email} · #{quien.nombre_completo}" : '— nadie (lo sembró el equipo)'}"

        Current.en_el_colegio(c) do
          puts "  alumnos         #{Student.count}"
          puts "  profesores      #{Teacher.count}"
          puts "  administradores #{Admin.includes(:user).map { |a| "#{a.user.email} (#{a.role})" }.join(', ').presence || '—'}"
          puts "  notas cargadas  #{ActivityGrade.count}"
          puts "  boletines       #{ReportCard.count}"
          puts "  última señal    #{ActivityLog.order(:created_at).last&.created_at&.strftime('%d/%m/%Y %H:%M') || '—'}"
        end
        puts ""
      end

      puts "ÚLTIMOS INICIOS DE SESIÓN"
      ActivityLog.unscoped.where(action: "login").includes(:user)
                 .order(created_at: :desc).limit(10).each do |log|
        puts format("  %-16s %s", log.created_at.strftime("%d/%m %H:%M"), log.user&.email)
      end
      puts ""
    end
  end
end

# ⚠️ Fuera del namespace `demo`: esto no es de la demostración, es del correo
# que le avisa al equipo de SIGA que entró un cliente.
namespace :avisos do
  desc "Manda el aviso de colegio nuevo con un colegio real, para comprobar que sale (MOR-158)"
  task probar: :environment do
    destinatario = PlataformaMailer.destinatario

    if destinatario.blank?
      abort "\n🚫 SIGA_AVISOS_EMAIL no está configurada. Sin ella el aviso NO se manda\n" \
            "   —y no falla, que es lo peligroso: un colegio nuevo entra y nadie se entera.\n"
    end

    colegio, usuario = Current.sin_aislamiento do
      [ School.order(:id).first, User.order(:id).first ]
    end
    abort "🚫 No hay ningún colegio con el que probar." if colegio.nil?

    puts "Mandando el aviso a #{destinatario} con #{colegio.name}…"
    # `deliver_now` y no `deliver_later`: si se encola, esto termina diciendo
    # «listo» sin que el correo haya salido, que es justo lo que se comprueba.
    PlataformaMailer.colegio_registrado(colegio, usuario).deliver_now
    puts "✅ Salió. Si no llega en unos minutos, revisa el log y la carpeta de spam."
  end

  # ⚠️ De dónde salió cada colegio, para decidir sin adivinar (MOR-146).
  #
  # El inventario dice CUÁNTOS hay; esto dice QUIÉN los creó y CUÁNDO. La
  # diferencia importa cuando el guarda de `es_solo_demo` encuentra un colegio
  # inesperado: puede ser una prueba de Daniel o el trabajo de un broker
end
