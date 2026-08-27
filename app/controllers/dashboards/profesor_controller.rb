# El panel del profesor (MOR-135).
#
# `MOR-135` lo dejó escrito: el profesor *"entra a CARGAR NOTAS. Semanal, con
# apuro, desde el teléfono."* El panel abría con cuatro conteos —secciones
# asignadas, alumnos en total, materias distintas, secciones que guía— que no
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

    # Las secciones de las que es GUÍA — no los grados (MOR-150). El guía es de
    # la sección; el grado, si acaso, tiene un coordinador.
    @led_sections = @teacher.led_sections.includes(:grade, :enrollments)

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
  # ⚠️ El cálculo NO vive acá (MOR-155).
  #
  # La dirección necesita exactamente lo mismo, agregado por profesor, para
  # saber a quién llamarle la atención antes de cerrar el lapso. Con dos copias
  # habría dos definiciones de «atrasado» que se van separando, y el director
  # terminaría reclamándole a alguien que sí cargó.
  def evaluaciones_sin_corregir
    CargaDeNotas.incompletas(@teacher_sections).first(6)
  end

  def require_profesor!
    return if profesor?

    redirect_to root_path, alert: "Acceso no autorizado. Esta área es solo para profesores."
  end
end
