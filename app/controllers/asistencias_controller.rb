# La toma de asistencia del día (MOR-111).
#
# ## La restricción que define todo: un minuto
#
# Un profesor toma asistencia de pie, con treinta alumnos entrando, al empezar
# la clase. **Si tarda más de un minuto, no se hace.** Y una asistencia que no se
# toma es peor que no tenerla: el colegio cree que la tiene.
#
# De ahí las dos decisiones de la pantalla:
#
#   · **Todos presentes por defecto.** La mayoría de los días faltan dos o tres.
#     Marcar 27 presencias para registrar 3 ausencias es lo que hace que nadie la
#     use. Se tocan las excepciones.
#   · **Una sola pantalla**, sin paginación y sin buscador. Treinta nombres
#     entran; hacer scroll es más rápido que filtrar.
#
# ## Por qué acá SÍ hay botón "Guardar", y en la planilla de notas no
#
# Parece una inconsistencia y es deliberada. En `ActivityGradesController` cada
# nota viaja sola porque son treinta valores tipeados: media hora de trabajo que
# un envío final fallido tira a la basura.
#
# Acá el trabajo son tres toques y veinte segundos. Con una conexión mala,
# **una sola petición chica tiene muchísima más probabilidad de llegar que
# treinta**, y si falla se reintenta sin haber perdido nada. La regla no es
# "guardado incremental siempre": es "que el profesor no pierda su trabajo", y
# acá se cumple al revés.
class AsistenciasController < ApplicationController
  before_action :require_puede_tomar_asistencia!
  before_action :set_seccion, only: [:show, :create]

  # Elegir sección. Un profesor guía normalmente tiene una sola y entra directo.
  def index
    @secciones = secciones_a_cargo

    return redirect_to seccion_asistencia_path(@secciones.first, dia: Date.current) if @secciones.one?

    @tomadas_hoy = Attendance.del_dia(Date.current)
                             .where(enrollment: Enrollment.where(section: @secciones))
                             .distinct.pluck(:enrollment_id)
  end

  def show
    @dia = dia_pedido
    @inscripciones = @seccion.enrollments.includes(student: :user).to_a
                             .sort_by { |i| [i.student.user.last_name, i.student.user.name] }

    @asistencias = Attendance.del_dia(@dia)
                             .where(enrollment_id: @inscripciones.map(&:id))
                             .index_by(&:enrollment_id)

    @ya_tomada = @asistencias.any?
  end

  # Guarda el día entero de una vez: las excepciones que vinieron marcadas, y
  # todos los demás como presentes.
  def create
    @dia = dia_pedido
    return render(json: { estado: "error", mensaje: "No se puede tomar asistencia de un día que no llegó." },
                  status: :unprocessable_entity) if @dia > Date.current

    marcados = params.fetch(:estados, {}).to_unsafe_h
    inscripciones = @seccion.enrollments.to_a

    guardadas = 0
    Attendance.transaction do
      inscripciones.each do |inscripcion|
        estado = marcados[inscripcion.id.to_s].presence || "presente"
        next unless Attendance.statuses.key?(estado)

        registro = Attendance.find_or_initialize_by(enrollment_id: inscripcion.id, date: @dia)
        registro.status      = estado
        registro.recorded_by = current_user
        registro.save!
        guardadas += 1
      end
    end

    render json: {
      estado: "ok",
      guardadas: guardadas,
      ausentes: marcados.values.count("ausente"),
      tarde: marcados.values.count("tarde"),
      mensaje: resumen(guardadas, marcados)
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { estado: "error", mensaje: e.record.errors.full_messages.to_sentence },
           status: :unprocessable_entity
  end

  # Quiénes acumulan faltas. Es lo que el colegio necesita para ACTUAR: llamar
  # al representante antes de que el alumno pierda el año, no enterarse en julio.
  #
  # Cuenta solo las ausencias sin justificar. Un alumno con seis faltas
  # justificadas por una internación no es el mismo caso que uno con seis sin
  # aviso, y mezclarlos hace que el reporte no sirva para decidir nada.
  def reporte
    @desde = fecha_o(params[:desde], Date.current - 30)
    @hasta = fecha_o(params[:hasta], Date.current)
    del_periodo = Attendance.where(date: @desde..@hasta)

    faltas    = del_periodo.sin_justificar.group(:enrollment_id).count
    @tardanzas = del_periodo.where(status: :tarde).group(:enrollment_id).count

    # Entran los dos casos, no solo el de las faltas. Un alumno que llega tarde
    # cinco veces y no falta nunca es exactamente el que el colegio quiere ver
    # antes de que se convierta en el otro — y filtrando solo por ausencias era
    # invisible.
    @filas = Enrollment.where(id: (faltas.keys | @tardanzas.keys))
                       .includes(student: :user, section: :grade)
                       .map { |i| { inscripcion: i, faltas: faltas[i.id] || 0 } }
                       .sort_by { |f| [-f[:faltas], -(@tardanzas[f[:inscripcion].id] || 0),
                                       f[:inscripcion].student.user.last_name] }
  end

  # El historial de un alumno. Lo usa el colegio, y va a usarlo el portal de
  # representantes (MOR-110): es la misma pregunta hecha por dos personas.
  def historial
    @inscripcion = Enrollment.includes(student: :user, section: :grade).find(params[:enrollment_id])
    del_alumno   = Attendance.where(enrollment_id: @inscripcion.id)

    @asistencias = del_alumno.order(date: :desc).limit(90)

    # Consulta aparte, sin el `order`. Encadenar `.group` sobre la relación
    # anterior arrastra su `ORDER BY date`, y Postgres rechaza ordenar por una
    # columna que no está agrupada ni agregada.
    @resumen = del_alumno.group(:status).count
  end

  private

  def fecha_o(valor, defecto)
    Date.parse(valor.to_s)
  rescue ArgumentError, TypeError
    defecto
  end

  def resumen(guardadas, marcados)
    faltas = marcados.values.count { |e| e != "presente" }
    return "Asistencia guardada: los #{guardadas} presentes." if faltas.zero?

    "Asistencia guardada: #{contar(guardadas - faltas, 'presente', 'presentes')}, " \
      "#{contar(marcados.values.count('ausente'), 'ausente', 'ausentes')}" \
      "#{", #{marcados.values.count('tarde')} con retraso" if marcados.values.include?('tarde')}."
  end

  def contar(n, singular, plural)
    "#{n} #{n == 1 ? singular : plural}"
  end

  def dia_pedido
    Date.parse(params[:dia].to_s)
  rescue ArgumentError, TypeError
    Date.current
  end

  def set_seccion
    # `Section` es SchoolScoped: pedir la sección de otro colegio da 404, no 403.
    @seccion = secciones_a_cargo.find { |s| s.id == params[:seccion_id].to_i || s.id == params[:id].to_i }
    raise ActiveRecord::RecordNotFound if @seccion.nil?
  end

  # El profesor guía de un grado toma la asistencia de sus secciones. La
  # dirección puede tomarla de cualquiera: el día que el guía falta, alguien
  # tiene que poder hacerlo.
  def secciones_a_cargo
    @secciones_a_cargo ||=
      if administrador?
        Section.includes(:grade, :academic_period).order("grades.name", :name).to_a
      else
        Section.includes(:grade, :academic_period)
               .where(grade: Grade.where(leader_teacher_id: current_user.id))
               .order("grades.name", :name).to_a
      end
  end

  def require_puede_tomar_asistencia!
    return if profesor? || can_manage_sections?

    redirect_to dashboard_path_for_user, alert: "No tenés secciones a cargo."
  end
end
