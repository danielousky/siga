class SectionsController < ApplicationController
  include PreparaLaAsistencia
  include MuestraElPlan

  PESTANAS = [ :show, :alumnos, :asistencia, :planificar ].freeze

  before_action :require_admin_access!, except: PESTANAS
  before_action :require_read_access!, only: PESTANAS
  before_action :set_section, only: PESTANAS + [ :edit, :update, :destroy ]
  before_action :cargar_la_seccion, only: PESTANAS

  # Por el nombre del grado o el de la sección: quien escribe «1er» quiere todas
  # las de primer año, y quien escribe «A» quiere las secciones A.
  CAMPOS_DE_BUSQUEDA = %w[grades.name sections.name].freeze

  def index
    # ⚠️ El año escolar ya NO se elige acá (MOR-165): lo fija el selector de la
    # barra de arriba, y vale para todas las pantallas a la vez. Este tenía su
    # propio desplegable «Todos los períodos» que contradecía al de la barra —dos
    # controles para lo mismo, en la misma pantalla.
    scope = Section.del_anio_de_la_sesion.del_nivel_de_la_sesion
                   .includes(:grade, :academic_period, leader_teacher: :user).joins(:grade, :academic_period)
    scope = scope.where(grade_id: params[:grade_id]) if params[:grade_id].present?
    # El campo de texto se suma al selector de grado, no lo reemplaza: buscar
    # «1er» y además acotar a un grado son dos preguntas distintas.
    scope = scope.where(*BusquedaSinAcentos.condicion(CAMPOS_DE_BUSQUEDA, params[:q])) if params[:q].present?
    @pagy, @sections = pagy(scope.order("grades.name, sections.name"))
    # Agrupados por nivel: `order(:name)` intercala las tres escaleras
    # («1er Año · 1er Grado · 1er Nivel · 2do Año…») y no hay quien lo lea.
    @grades_options = helpers.grados_por_nivel
  end

  # `show` es la pestaña CALIFICAR (etapa ③). Las otras tres son
  # `alumnos` acá al lado, `asistencias#show` y `competencies#index`.
  def show
    preparar_la_libreta
  end

  # ⚠️ «Alumnos» dejó de ser un panel que alterna con `hidden` y pasó a tener
  # su URL. Las otras tres pestañas son pantallas de verdad, y media fila que
  # navega y media que alterna no se le puede explicar a nadie: el botón de
  # atrás funcionaría en unas y en otras no.
  def alumnos; end

  # ⚠️ La asistencia DENTRO de la sección, no en otra pantalla.
  #
  # Es la misma planilla de `/asistencia/:seccion_id` —el parcial y la
  # preparación son compartidos (`PreparaLaAsistencia`)— para que las dos no se
  # separen: la de allá ordenaría por apellido y la de acá no, y nadie se
  # enteraría hasta que un profesor comparara las dos.
  def asistencia
    return redirect_to(section_path(@section), alert: "Solo el profesor guía toma asistencia.") unless puede_tomar_asistencia?

    preparar_la_asistencia(@section)
  end

  # Y el plan de evaluación, igual: mismo parcial, misma preparación
  # (`MuestraElPlan`). La diferencia con `/competencias` es que acá la sección y
  # el área ya vienen del árbol del menú, así que la escalera se reduce al lapso.
  def planificar
    return redirect_to(section_path(@section), alert: "Elige primero un área.") if asignacion.nil?

    @competencias = Competency.del_plan(asignacion.section_id, asignacion.subject_id, lapso&.id)
                              .includes(:indicators, :evaluation_activities)
  end

  def new
    @section = Section.new
  end

  def edit; end

  def create
    @section = Section.new(section_params)
    if @section.save
      registrar_cambio(:creado, @section, "#{@section.grade.name} – #{@section.name}")
      redirect_to @section, notice: "Sección creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @section.update(section_params)
      registrar_cambio(:actualizado, @section, "#{@section.grade.name} – #{@section.name}")
      redirect_to @section, notice: "Sección actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # El nombre, antes de borrar: después el objeto ya no puede
    # resolver sus asociaciones para armar el mensaje.
    nombre = "#{@section.grade.name} – #{@section.name}"

    if @section.destroy
      registrar_cambio(:eliminado, @section, nombre)
      redirect_to sections_url, notice: "Sección eliminada exitosamente."
    else
      redirect_to @section, alert: @section.errors.full_messages.join(", ")
    end
  end

  private

  # La libreta: todas las notas de esta sección en una tabla (MOR-223).
  #
  # Daniel: *«debería tener una vista en la que aparezcan todas las evaluaciones
  # y él pueda ir ajustando durante el lapso… una tabla donde la primera columna
  # es la lista de los estudiantes y las siguientes columnas son las
  # evaluaciones»*.
  #
  # ⚠️ Las áreas que se ofrecen son las que ESTA PERSONA califica, no las de la
  # sección. Daniel, ratificándolo con Cyndi: *«califica el profe de la materia.
  # Incluso el guía… ¿cómo sabes cuáles califica? guía + áreas asignadas»*.
  #
  # La dirección las ve todas: no califica, supervisa.
  # Lo que las dos pestañas de esta pantalla necesitan siempre: quiénes dictan
  # acá y quiénes están inscritos.
  def cargar_la_seccion
    @teacher_sections = @section.teacher_sections.includes(teacher: :user, subject: {})
    @enrollments = @section.enrollments.where(status: :regular)
                           .includes(student: :user).order("users.last_name")

    return unless administrador?

    asignadas = @teacher_sections.pluck(:subject_id)
    @available_subjects = @section.grade.subjects.where.not(id: asignadas).order(:name)
    @available_teachers = Teacher.includes(:user).order("users.last_name")
  end

  # El área por la que entré, que es la que el árbol del menú trajo en la URL.
  # Es lo que decide qué libreta se abre y a qué plan lleva «Planificar».
  # ── Lo que `MuestraElPlan` y `PreparaLaAsistencia` necesitan ──────────────

  # La asignación de la que habla esta pantalla: esta sección, el área que trajo
  # el árbol del menú. ⚠️ Se busca entre las de ESTE profesor, y eso es lo que
  # autoriza: un área que no dicta no está en la lista y devuelve nil.
  def asignacion
    return @asignacion if defined?(@asignacion)

    @asignacion = mis_asignaciones.find { |ts| ts.subject_id == area_de_la_pestana&.id }
  end
  helper_method :asignacion

  # ⚠️ TODAS las del profesor, no solo las de esta sección.
  #
  # Estaba filtrando sobre `@teacher_sections` —las de la sección abierta— y
  # eso dejaba a `otras_secciones` y `hermanas_sin_plan` vacías: **la opción de
  # copiar el plan a las hermanas desapareció de la pestaña sin que nada
  # fallara**. Las hermanas son, por definición, de OTRA sección.
  #
  # Lo destapó un test que contaba el formulario de copiar, no la pantalla.
  def mis_asignaciones
    @mis_asignaciones ||= current_user.teacher&.teacher_sections
                                      &.del_anio_de_la_sesion
                                      &.includes(section: :grade, subject: {})&.to_a || []
  end
  helper_method :mis_asignaciones

  def desde_donde = "seccion"

  # Los formularios del plan vuelven a la pestaña, no a `/competencias`.
  def plan_path
    planificar_section_path(@section, area: area_de_la_pestana&.id, lapso: lapso&.id)
  end
  helper_method :plan_path

  # Quién puede pasar lista: el guía de la sección, o la dirección.
  def puede_tomar_asistencia?
    can_manage_sections? || @section.leader_teacher_id == current_user.teacher&.id
  end

  # ⚠️ Cae en la PRIMERA que califico cuando la URL no la trae.
  #
  # Entrando por «Soy guía de» el enlace va sin área —la asistencia es de la
  # sección entera, sin área— y ahí «Planificar» rebotaba con «Elige primero un
  # área» mientras la libreta de al lado mostraba Matemática tan campante: las
  # dos deducían distinto.
  #
  # Es «no preguntemos lo deducible»: en una sección donde dicto una sola área
  # no hay nada que elegir, y donde dicto dos la primera es tan buena como
  # pedirla — las pestañas la llevan de ahí en adelante.
  def area_de_la_pestana
    return @area_de_la_pestana if defined?(@area_de_la_pestana)

    @area_de_la_pestana = areas_que_califico.find { |s| s.id.to_s == params[:area] } ||
                          areas_que_califico.first
  end
  helper_method :area_de_la_pestana

  def preparar_la_libreta
    @areas_que_califico = areas_que_califico
    return if @areas_que_califico.empty?

    @lapsos_de_la_libreta = EvaluationMoment
                            .where(academic_period_id: @section.academic_period_id)
                            .order(:starts_on, :id).to_a
    # ⚠️ La MISMA que las pestañas, no una deducción paralela: cuando eran dos,
    # la libreta abría en Matemática y «Planificar» decía que faltaba elegir.
    @area_de_la_libreta = area_de_la_pestana
    @lapso_de_la_libreta = @lapsos_de_la_libreta.find { |l| l.id.to_s == params[:lapso] } ||
                           lapso_en_curso || @lapsos_de_la_libreta.first
    return if @lapso_de_la_libreta.nil?

    @libreta = LibretaDeLaSeccion.para(seccion: @section, materia: @area_de_la_libreta,
                                       lapso: @lapso_de_la_libreta)
  end

  def areas_que_califico
    return @section.grade.subjects.order(:name).to_a if can_manage_sections?
    return [] unless profesor?

    @teacher_sections.select { |ts| ts.teacher_id == current_user.teacher&.id }
                     .map(&:subject).uniq.sort_by(&:name)
  end

  # ⚠️ El lapso que se está cursando, no el primero.
  #
  # Es la misma trampa que `AcademicPeriod.en_operacion` para el año escolar,
  # cuarta o quinta aparición: abrir en el primero es abrirle a un profesor de
  # marzo la libreta de octubre, que ya cerró.
  def lapso_en_curso
    hoy = Date.current
    @lapsos_de_la_libreta.find { |l| l.starts_on && l.ends_on && (l.starts_on..l.ends_on).cover?(hoy) }
  end

  def set_section
    @section = Section.find(params[:id])
  end

  # ⚠️ El año escolar NO viaja en el formulario cuando se puede deducir (MOR-165).
  #
  # Al crear sale de la sesión; al editar no se toca, porque mover una sección de
  # año arrastraría inscripciones, asistencia y notas que son de ese año.
  # El único caso en que se acepta del request es cuando la sesión mira «Todos
  # los años» y no hay nada que deducir — y ahí lo valida el `belongs_to` contra
  # el `default_scope`, no un `if`.
  def section_params
    permitidos = params.require(:section).permit(:name, :grade_id, :capacity, :classroom, :leader_teacher_id)
    return permitidos if @section&.persisted?

    permitidos.merge(academic_period_id: Current.academic_period_id ||
                                         params[:section][:academic_period_id])
  end

  def require_admin_access!
    unless administrador? && can_manage_sections?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end

  # Profesores pueden ver sus propias secciones; admins pueden ver cualquiera
  def require_read_access!
    if administrador?
      # ok
    elsif profesor?
      section = Section.find(params[:id])
      unless current_user.teacher.sections.include?(section)
        redirect_to dashboard_path_for_user, alert: "No tienes acceso a esta sección."
      end
    else
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado."
    end
  end
end
