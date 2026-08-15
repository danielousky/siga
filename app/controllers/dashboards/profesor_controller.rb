# El panel del profesor (MOR-135).
#
# `MOR-135` lo dejó escrito: el profesor *"entra a CARGAR NOTAS. Semanal, con
# apuro, desde el teléfono."* El panel abría con cuatro conteos —secciones
# asignadas, estudiantes en total, materias distintas, grados liderados— que no
# le sirven para eso ni cambian de una semana a otra.
#
# Ahora lo primero es **lo que le falta corregir**, con el enlace directo a la
# planilla. Los conteos siguen abajo: son contexto, no tarea.
class Dashboards::ProfesorController < ApplicationController
  before_action :require_profesor!

  def index
    @teacher = current_user.teacher

    @teacher_sections = @teacher.teacher_sections
                                .includes(:subject, section: [ :grade, :academic_period, :enrollments ])
                                .order("grades.name, sections.name")

    @led_grades = @teacher.led_grades.includes(:sections)

    @total_sections = @teacher_sections.size
    @total_students = @teacher_sections.sum { |ts| ts.section.enrollments.size }
    @total_subjects = @teacher_sections.map(&:subject_id).uniq.size

    @sin_corregir = evaluaciones_sin_corregir
  end

  private

  # Las evaluaciones cuya fecha ya pasó y a las que les faltan notas.
  #
  # Se resuelve en DOS consultas y no en una por evaluación: la cuenta de notas
  # cargadas sale de un `group(:evaluation_activity_id).count`, y la de alumnos
  # inscritos ya vino con el `includes` de arriba. Con quince evaluaciones la
  # diferencia no se nota; con las de un año entero, sí — y este panel lo abre
  # un profesor desde el teléfono.
  def evaluaciones_sin_corregir
    secciones = @teacher_sections.map(&:section_id).uniq
    return [] if secciones.empty?

    evaluaciones = EvaluationActivity
      .where(section_id: secciones, subject_id: @teacher_sections.map(&:subject_id).uniq)
      .where(date_scheduled: ..Date.current)
      .includes(:subject, section: :grade)
      .order(date_scheduled: :desc)

    cargadas = ActivityGrade.where(evaluation_activity_id: evaluaciones.map(&:id))
                            .group(:evaluation_activity_id).count

    inscritos = @teacher_sections.to_h { |ts| [ ts.section_id, ts.section.enrollments.size ] }

    evaluaciones.filter_map do |e|
      total = inscritos[e.section_id].to_i
      puestas = cargadas[e.id].to_i
      next if total.zero? || puestas >= total

      { evaluacion: e, puestas: puestas, total: total }
    end.first(6)
  end

  def require_profesor!
    return if profesor?

    redirect_to root_path, alert: "Acceso no autorizado. Esta área es solo para profesores."
  end
end
