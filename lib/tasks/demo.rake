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
  # ⚠️ El orden va de HIJOS a PADRES. Cambiarlo no rompe en silencio: revienta
  # contra una FK, que es exactamente lo que se quiere.
  EN_ORDEN_DE_BORRADO = %w[
    activity_grades moment_grades final_grade_books report_cards attendances
    evaluation_activities teacher_sections student_representatives enrollments
    grade_subjects sections evaluation_moments academic_periods
    subjects departments grades
    students teachers admins representatives
    subscriptions importaciones activity_logs addresses
    users schools
  ].freeze

  desc "Borra TODA la demo y la vuelve a sembrar (MOR-146). Exige respaldo previo."
  task limpiar: :environment do
    Rake::Task["demo:es_solo_demo"].invoke

    unless ENV["SIGA_RESPALDO_VERIFICADO"] == "1"
      abort "\n🚫 Falta SIGA_RESPALDO_VERIFICADO=1.\n" \
            "   No es burocracia: esto no se puede deshacer.\n" \
            "   Exporta la base, restáurala en otra aparte, cuenta las filas, y entonces sí.\n"
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

    puts ""
    puts "✅ Base vacía. Antes había #{antes[0]} colegios y #{antes[1]} personas."
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
      encontrados = School.order(:id).pluck(:name)

      problemas = []
      problemas << "hay #{School.count} colegios y se esperaban 2" if School.count != 2
      inesperados = encontrados - esperados
      problemas << "colegios que NO son de la demo: #{inesperados.join(', ')}" if inesperados.any?

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
end
