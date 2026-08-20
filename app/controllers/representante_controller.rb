# El portal del representante (MOR-110).
#
# ## Es la superficie más visible del producto
#
# Los demás usuarios son personal del colegio: unos pocos administrativos y
# quince profesores. **Los representantes son cientos por colegio** — dos por
# alumno, ~700 en uno de 350—, y son quienes le dan al director la sensación de
# que el sistema vale la pena. Cuando una madre le dice a la directora "qué bueno
# que ahora veo las notas desde el teléfono", eso es lo que renueva la
# suscripción.
#
# ## Entra a UNA cosa, tres veces al año, desde un teléfono
#
# No es un tablero: es una respuesta. La pantalla abre directamente en el hijo
# —si hay uno solo, que es el caso más común— con la nota del lapso arriba de
# todo. Nada de menús, nada de configurar.
#
# ## Estrictamente de lectura
#
# No hay una sola acción que escriba. Y no alcanza con no poner botones: el
# controller no expone ningún verbo que no sea GET, así que aunque alguien
# construya la petición a mano no hay nada que llamar.
class RepresentanteController < ApplicationController
  before_action :require_representante!
  before_action :set_representante

  # Los hijos. Con uno solo —el caso común— se entra directo a su detalle: un
  # paso menos para quien entra tres veces al año.
  #
  # ⚠️ Pero **solo si además tiene un solo colegio.** Una madre con un hijo en
  # cada colegio tiene un hijo por pantalla, y saltear esta vista la dejaría
  # encerrada en el primero sin forma de llegar al otro: el selector de colegio
  # vive acá. Lo encontré probando exactamente ese caso con los seeds.
  def index
    @hijos = hijos_con_datos

    redirect_to hijo_representante_path(@hijos.first[:student]) if @hijos.one? && colegios_del_representante.one?
  end

  def hijo
    @hijo = hijos_con_datos.find { |h| h[:student].id == params[:id].to_i }
    raise ActiveRecord::RecordNotFound if @hijo.nil?

    @inscripcion = @hijo[:inscripcion]
    return if @inscripcion.nil?

    @lapsos  = EvaluationMoment.where(academic_period_id: @inscripcion.section.academic_period_id).order(:id).to_a
    @lapso   = @lapsos.find { |l| l.id == params[:lapso].to_i } || @lapsos.first
    @anual   = params[:lapso] == "anual"

    @materias    = materias_con_notas(@inscripcion, @lapso)
    @asistencia  = resumen_de_asistencia(@inscripcion)
    @boletines   = ReportCard.where(enrollment_id: @inscripcion.id).order(created_at: :desc).limit(5)
  end

  # Cambiar de colegio cuando se tienen hijos en más de uno.
  #
  # Guarda el id en la sesión y nada más: quien decide si ese id vale es
  # `colegio_del_representante`, contrastándolo contra los colegios donde esta
  # persona verificadamente representa a alguien. Mandar un id ajeno no hace nada.
  def cambiar_colegio
    session[:colegio_elegido_id] = params[:colegio_id].to_i

    redirect_to representante_path
  end

  private

  def hijos_con_datos
    @hijos_con_datos ||= @representante.students.includes(:user).map do |alumno|
      inscripcion = Enrollment.includes(section: [:grade, :academic_period])
                              .where(student_id: alumno.id)
                              .order(enrollment_date: :desc).first
      { student: alumno, inscripcion: inscripcion }
    end.sort_by { |h| h[:student].user.first_name }
  end

  # Las notas del lapso, o las definitivas del año. Es la misma pregunta que
  # responde el panel del alumno, hecha por otra persona (MOR-97).
  def materias_con_notas(inscripcion, lapso)
    grado = inscripcion.section.grade
    notas = MomentGrade.where(enrollment_id: inscripcion.id).index_by { |m| [m.subject_id, m.evaluation_moment_id] }
    libros = FinalGradeBook.where(enrollment_id: inscripcion.id).index_by(&:subject_id)

    grado.subjects.order(:name).map do |materia|
      {
        materia: materia,
        lapso: @anual ? nil : notas[[materia.id, lapso&.id]]&.final_moment_score&.to_i,
        definitiva: libros[materia.id]&.final_score&.to_i,
        escala: grado.escala
      }
    end
  end

  def resumen_de_asistencia(inscripcion)
    registros = Attendance.where(enrollment_id: inscripcion.id)
    {
      presente: registros.presente.count,
      ausente:  registros.ausente.count,
      tarde:    registros.tarde.count,
      sin_justificar: registros.sin_justificar.count,
      ultimas: registros.faltas.order(date: :desc).limit(5)
    }
  end

  def set_representante
    @representante = Representative.find_by(user_id: current_user.id)
    raise ActiveRecord::RecordNotFound if @representante.nil?
  end

  def require_representante!
    return if representante?

    redirect_to dashboard_path_for_user, alert: "Esta sección es para representantes."
  end
end
