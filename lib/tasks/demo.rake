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

  # ⚠️ Esta es la comprobación que el issue pide ANTES de tocar nada, y no es
  # ceremonia: `db:seed:replant` trunca. Si para entonces hay un colegio real
  # cargado, se lo lleva por delante.
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
