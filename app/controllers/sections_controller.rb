class SectionsController < ApplicationController
  before_action :require_admin_access!, except: [:show]
  before_action :require_read_access!, only: [:show]
  before_action :set_section, only: [:show, :edit, :update, :destroy]

  # Por el nombre del grado o el de la sección: quien escribe «1er» quiere todas
  # las de primer año, y quien escribe «A» quiere las secciones A.
  CAMPOS_DE_BUSQUEDA = %w[grades.name sections.name].freeze

  def index
    # ⚠️ El año escolar ya NO se elige acá (MOR-165): lo fija el selector de la
    # barra de arriba, y vale para todas las pantallas a la vez. Este tenía su
    # propio desplegable «Todos los períodos» que contradecía al de la barra —dos
    # controles para lo mismo, en la misma pantalla.
    scope = Section.del_anio_de_la_sesion
                   .includes(:grade, :academic_period, leader_teacher: :user).joins(:grade, :academic_period)
    scope = scope.where(grade_id: params[:grade_id]) if params[:grade_id].present?
    # El campo de texto se suma al selector de grado, no lo reemplaza: buscar
    # «1er» y además acotar a un grado son dos preguntas distintas.
    scope = scope.where(*BusquedaSinAcentos.condicion(CAMPOS_DE_BUSQUEDA, params[:q])) if params[:q].present?
    @pagy, @sections = pagy(scope.order("grades.name, sections.name"))
    @grades_options = [["Todos los grados", ""]] + Grade.order(:name).pluck(:name, :id)
  end

  def show
    @teacher_sections = @section.teacher_sections.includes(teacher: :user, subject: {})
    @enrollments = @section.enrollments.where(status: :regular).includes(student: :user).order("users.last_name")

    # Solo los admins necesitan los datos de gestión
    if administrador?
      assigned_subject_ids = @teacher_sections.pluck(:subject_id)
      @available_subjects = @section.grade.subjects.where.not(id: assigned_subject_ids).order(:name)
      @available_teachers = Teacher.includes(:user).order("users.last_name")
    end
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
