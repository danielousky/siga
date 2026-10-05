# La planilla de reparación (MOR-168).
#
# ## El hueco que tapa
#
# El Artículo 112 estaba implementado **de la mitad para adelante**:
# `remedial_exam_score` se lee en el boletín, en la certificación 31059, en el
# panel del alumno y en el cálculo de la definitiva. Pero solo se ESCRIBÍA desde
# el importador de historial. Un colegio que usa SIGA en el año en curso no tenía
# dónde cargar una reparación.
#
# Lo encontró Daniel buscándola: *«por ningún lado vi dónde el profesor coloca la
# reparación»*. No la vio porque no existía.
#
# ## Una sola nota, sin importar cómo se llegó a ella
#
# La Circular 0007 del MPPE fija cuatro momentos para presentar una materia
# —octubre, diciembre, enero y junio— pero **lo que queda registrado es una
# nota**: «el examen versará sobre el 100 % del contenido y la calificación
# obtenida será la definitiva». Los cuatro intentos son procedimiento interno del
# colegio, y la ley no es clara sobre cómo llevarlos.
#
# Daniel: *«la reparación debe ir una sola nota. No importa los procesos que
# hagan, pero el final va una sola nota»*. Así que SIGA guarda una, y quien
# quiera dejar rastro de en cuál momento la aprobó lo escribe en el comentario.
#
# ## ⚠️ Solo aparecen los APLAZADOS
#
# Un alumno con 15 no repara nada. Listar la sección entera haría la planilla
# tres veces más larga y, sobre todo, pondría un campo editable al lado de una
# nota que ya está bien — que es como se le baja una nota a alguien por
# accidente.
class ReparacionesController < ApplicationController
  include PlanillaQueSeGuardaSola
  before_action :require_puede_calificar!
  before_action :set_seccion_y_materia, except: [ :index ]

  # Dónde hay reparaciones pendientes. Para un profesor, sus asignaciones; para
  # la dirección, todo el colegio.
  def index
    @grupos = grupos_con_aplazados
  end

  def show
    @aplazados = libros_aplazados.sort_by { |l| l.enrollment.student.user.apellidos_y_nombres }
    @cargadas = @aplazados.count { |l| l.remedial_exam_score.present? }
  end

  # Cada nota viaja sola, como en la planilla de notas: un formulario de treinta
  # campos que se envía al final es una promesa de perder el trabajo.
  def update
    libro = libros_aplazados.find { |l| l.enrollment.student_id.to_s == params[:student_id].to_s }
    return head(:not_found) if libro.nil?

    anterior = libro.remedial_exam_score
    nota = params[:score].to_s.strip

    # Vacío BORRA la reparación y devuelve la definitiva al promedio anual. No la
    # pone en 1: «sin reparación» no es una reparación mala.
    libro.remedial_exam_score = nota.presence
    libro.calcular_definitiva

    if libro.save
      auditar(libro, anterior)
      contestar(libro, nota.blank? ? :vacio : :guardado)
    else
      contestar(libro, :rechazado, libro.errors.full_messages.to_sentence,
                estado_http: :unprocessable_entity)
    end
  end

  private

  # ⚠️ Los libros del año de la SESIÓN de quien DEBE reparar.
  #
  # `debe_reparar?` y no `aplazado?`: el derecho a la segunda oportunidad lo da
  # el promedio ANUAL. Con la definitiva, un alumno desaparecía de la planilla
  # apenas se le cargaba una reparación aprobatoria y corregir un tipeo era
  # imposible.
  #
  # Se filtra en Ruby y no en SQL a propósito: el 10 del Art. 108 es la regla
  # del dominio, y escribirla también como un `where` la deja en dos lugares que
  # se van separando. Son treinta filas por sección.
  def libros_aplazados
    @libros_aplazados ||=
      FinalGradeBook.del_anio_de_la_sesion
                    .where(subject_id: @materia.id,
                           enrollment_id: @seccion.enrollments.select(:id))
                    .includes(enrollment: { student: :user })
                    .select(&:debe_reparar?)
  end

  # Sección + materia con al menos un aplazado, y cuántos. Es lo que convierte
  # «hay reparaciones» en «a García le faltan tres», que es lo accionable.
  def grupos_con_aplazados
    asignaciones = TeacherSection.del_anio_de_la_sesion
                                 .includes(:subject, :teacher, section: :grade)
    asignaciones = asignaciones.where(teacher_id: current_user.teacher&.id) if profesor? && !administrador?

    asignaciones.filter_map do |asignacion|
      libros = FinalGradeBook.del_anio_de_la_sesion
                             .where(subject_id: asignacion.subject_id,
                                    enrollment_id: asignacion.section.enrollments.select(:id))
                             .to_a
      aplazados = libros.select(&:debe_reparar?)
      next if aplazados.empty?

      { seccion: asignacion.section, materia: asignacion.subject,
        aplazados: aplazados.size,
        cargadas: aplazados.count { |l| l.remedial_exam_score.present? } }
    end.sort_by { |g| [ g[:seccion].grade.name, g[:seccion].name, g[:materia].name ] }
  end

  def set_seccion_y_materia
    # El `default_scope` hace el filtro: una sección de otro colegio no se
    # encuentra y da 404, no 403.
    @seccion = Section.del_anio_de_la_sesion.find(params[:seccion_id])
    @materia = Subject.find(params[:materia_id])

    return if administrador? || dicta?(@seccion, @materia)

    redirect_to reparaciones_path, alert: "Esa área no es suya en esa sección."
  end

  def dicta?(seccion, materia)
    TeacherSection.exists?(section_id: seccion.id, subject_id: materia.id,
                           teacher_id: current_user.teacher&.id)
  end

  # La misma auditoría fila-por-fila que la planilla de notas, y por la misma
  # razón: la pregunta que hay que poder contestar es «¿quién le cambió la nota
  # a mi hijo?», y la hace una madre por UNA nota, meses después.
  def auditar(libro, anterior)
    return if anterior.to_i == libro.remedial_exam_score.to_i

    alumno = libro.enrollment.student.user
    cambio = if libro.remedial_exam_score.nil? then "le borró la reparación (era #{anterior.to_i})"
             elsif anterior.nil?               then "le puso #{libro.remedial_exam_score.to_i} de reparación"
             else "le cambió la reparación de #{anterior.to_i} a #{libro.remedial_exam_score.to_i}"
             end

    log_activity(
      action:  "reparacion_registrada",
      subject: libro.enrollment,
      message: "#{current_user.nombre_completo} #{cambio} a #{alumno.apellidos_y_nombres} " \
               "en #{@materia.name} · #{@seccion.grade.name} #{@seccion.name}",
      metadata: { alumno_id: alumno.id, anterior: anterior&.to_i,
                  actual: libro.remedial_exam_score&.to_i, definitiva: libro.final_score&.to_i }
    )
  end

  # ⚠️ El stream lleva la DEFINITIVA además de la marca, y esa es la diferencia
  # con la planilla de notas.
  #
  # Un profesor que carga 14 sobre un 8 tiene que VER en el momento que el
  # alumno quedó en 14 — sin eso, el Artículo 112 es una promesa que no se
  # comprueba hasta que salga el boletín.
  def contestar(libro, estado, mensaje = nil, estado_http: :ok)
    response.status = estado_http
    alumno = libro.enrollment.student_id

    fila_de_la_planilla(
      id: "estado_#{alumno}", estado: estado, mensaje: mensaje,
      hechas: libros_aplazados.count { |l| l.remedial_exam_score.present? },
      total: libros_aplazados.size, nombre: "cargadas",
      extra: [ turbo_stream.replace("definitiva_#{alumno}",
                                    partial: "reparaciones/definitiva",
                                    locals: { alumno: alumno, libro: libro }) ]
    )
  end

  def require_puede_calificar!
    return if profesor? || (administrador? && can_manage_sections?)

    respond_to do |formato|
      formato.html { redirect_to dashboard_path_for_user, alert: "Esta pantalla es para quien califica." }
      formato.json { render json: { estado: "error", mensaje: "Sin permiso." }, status: :forbidden }
    end
  end
end
