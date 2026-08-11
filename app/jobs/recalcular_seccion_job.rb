# Recalcula las notas de una sección entera para una materia.
#
# Cambiar la ponderación de una evaluación no afecta a un alumno: afecta a los
# treinta. Si el examen pasa de valer 40 % a 50 %, el promedio del lapso cambia
# para toda la sección, y con él el anual.
#
# Esto SÍ va por job, al revés que el recálculo de una nota suelta: se midió en
# ~1 segundo para una sección de 20 alumnos con 11 materias. Un profesor que
# corrige un peso no puede quedarse un segundo mirando una pantalla trabada, y a
# diferencia de la nota que acaba de escribir, acá no está esperando ver un
# número puntual.
#
# El colegio viaja en el payload por `CarriesSchool` (MOR-88): un worker no tiene
# petición, y sin colegio este job vería cero filas.
#
# ⚠️ Con el adaptador `:async` de hoy, lo encolado se pierde si el proceso se
# reinicia. Para eso está `bin/rails notas:recalcular`, que repara sin tocar la
# base a mano.
#
# Ver MOR-96.
class RecalcularSeccionJob < ApplicationJob
  queue_as :default

  def perform(section, subject)
    return if section.nil? || subject.nil?

    section.enrollments.find_each do |inscripcion|
      EvaluationMoment.where(academic_period_id: section.academic_period_id).find_each do |lapso|
        GradeCalculator.calculate_moment_grade(
          enrollment: inscripcion, subject: subject, evaluation_moment: lapso
        )
      end

      GradeCalculator.calculate_final_grade(enrollment: inscripcion, subject: subject)
    end
  end
end
