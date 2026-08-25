namespace :importaciones do
  desc "Borra los archivos de las importaciones de más de 30 días (la fila queda)"
  task purgar: :environment do
    cuantas = PurgarPlanillasJob.perform_now

    puts "#{cuantas} #{cuantas == 1 ? 'planilla encolada' : 'planillas encoladas'} para borrar."
  end
end
