# Recálculo total de las notas derivadas.
#
# `moment_grades` y `final_grade_books` se mantienen solas desde MOR-96, pero hay
# caminos por los que se pueden quedar viejas:
#
#   · un `RecalcularSeccionJob` que se perdió al reiniciar el proceso (hoy el
#     adaptador es `:async`, que no persiste la cola);
#   · una importación masiva que escribió notas con `insert_all`, saltándose los
#     callbacks de ActiveRecord — el camino de MOR-126;
#   · un arreglo a mano en la base.
#
# Es idempotente: correrla dos veces da lo mismo que correrla una.
#
#   bin/rails notas:recalcular                 # todos los colegios
#   bin/rails notas:recalcular COLEGIO=3       # uno solo
#
# Ver MOR-96.
namespace :notas do
  desc "Recalcula las notas de lapso y las definitivas de todos los colegios"
  task recalcular: :environment do
    colegios = Current.sin_aislamiento do
      ENV["COLEGIO"] ? School.where(id: ENV["COLEGIO"]).to_a : School.order(:name).to_a
    end

    abort "No hay colegios que recalcular." if colegios.empty?

    total_inscripciones = 0
    comenzado = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    colegios.each do |colegio|
      # El contexto va en las DOS capas, igual que en una petición: el
      # `default_scope` de la app y la variable de sesión del RLS. Sin la segunda
      # esta tarea vería cero filas.
      Current.school = colegio
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql_array(
          ["SELECT set_config('siga.school_id', ?, false)", colegio.id.to_s]
        )
      )

      puts "· #{colegio.name}"

      Section.includes(:enrollments, :grade).find_each do |seccion|
        next if seccion.enrollments.empty?

        GradeCalculator.calculate_all_for_section(seccion)
        total_inscripciones += seccion.enrollments.size
        puts "    #{seccion.grade.name} – #{seccion.name}".ljust(28) +
             "#{seccion.enrollments.size} inscripciones"
      end
    end

    Current.reset
    ActiveRecord::Base.connection.execute("SELECT set_config('siga.school_id', '', false)")

    segundos = Process.clock_gettime(Process::CLOCK_MONOTONIC) - comenzado

    # `unscoped` se salta el `default_scope` de la app, NO el RLS de la base. Sin
    # contexto de colegio, Postgres devuelve cero filas — que es exactamente el
    # modo correcto de fallar, y la razón por la que contar acá necesita pedir
    # permiso explícito.
    lapsos, definitivas = Current.sin_aislamiento do
      [MomentGrade.unscoped.count, FinalGradeBook.unscoped.count]
    end

    puts ""
    puts "✓ #{total_inscripciones} inscripciones recalculadas en #{segundos.round(1)} s."
    puts "  #{lapsos} notas de lapso · #{definitivas} definitivas."
  end
end
