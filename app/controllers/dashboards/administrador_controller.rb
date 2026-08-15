# El panel del director (MOR-135).
#
# ## Qué contestaba antes
#
# Cuatro conteos que no cambian de un día para otro, **seis tarjetas que eran
# una segunda copia del menú lateral** —Estudiantes, Profesores, Secciones,
# Períodos, Materias, Departamentos, todas ya en el sidebar, con un emoji cada
# una— y las últimas inscripciones.
#
# El propio `MOR-135` lo había escrito: el director *"entra a MIRAR CÓMO VA"*.
# Nada de eso contestaba cómo va.
#
# ## Qué contesta ahora
#
# Primero **lo que hay que atender**, que es lo único accionable, y solo si hay
# algo. Después los números, que son contexto. Un panel que siempre dice lo
# mismo se deja de leer, y el día que dice otra cosa tampoco se lee.
class Dashboards::AdministradorController < ApplicationController
  before_action :require_admin!

  def index
    @admin = current_user.admin

    @total_students = Student.count
    @total_teachers = Teacher.count
    @total_sections = Section.count
    @total_admins   = Admin.count

    @pendientes = pendientes_de_atencion

    if show_recent_activity?
      @recent_enrollments = Enrollment.includes(student: :user, section: :grade)
                                      .order(created_at: :desc).limit(10)
    end
  end

  private

  # El año escolar **con inscripciones**, no `AcademicPeriod.vigente`.
  #
  # Es la misma trampa que ya mordió en `Subscription.matricula_de`: en agosto
  # el período vigente es el año que arranca en septiembre, que todavía no
  # tiene ni una sección. El panel diría "0 secciones" con el colegio lleno.
  def periodo_en_curso
    @periodo_en_curso ||= AcademicPeriod
      .where(id: Section.joins(:enrollments).select(:academic_period_id))
      .order(:start_date).last
  end

  # Lo que un director puede resolver hoy. Cada uno enlaza a donde se resuelve:
  # un número sin destino es una preocupación, no una tarea.
  def pendientes_de_atencion
    return [] if periodo_en_curso.nil?

    [ secciones_sin_profesor, alumnos_sin_representante ].compact
  end

  # Una sección a la que le falta profesor en alguna materia de su grado: nadie
  # puede cargar esas notas, y se descubre en diciembre cuando no hay boletín.
  def secciones_sin_profesor
    secciones = Section.where(academic_period_id: periodo_en_curso.id)
                       .includes(grade: :subjects).includes(:teacher_sections)

    cuantas = secciones.count do |seccion|
      seccion.grade.subjects.map(&:id).sort != seccion.teacher_sections.map(&:subject_id).uniq.sort
    end
    return nil if cuantas.zero?

    { cuantas: cuantas, singular: "sección tiene una materia sin profesor",
      plural: "secciones tienen alguna materia sin profesor",
      ruta: sections_path }
  end

  # Sin representante, el colegio no tiene a quién llamar. Es el dato que la
  # secretaría termina buscando por fuera del sistema.
  def alumnos_sin_representante
    cuantos = Student.where.not(user_id: StudentRepresentative.select(:student_id)).count
    return nil if cuantos.zero?

    { cuantas: cuantos, singular: "alumno no tiene representante registrado",
      plural: "alumnos no tienen representante registrado",
      ruta: representatives_path }
  end

  def require_admin!
    return if administrador?

    redirect_to root_path, alert: "Acceso no autorizado. Esta área es solo para administradores."
  end
end
