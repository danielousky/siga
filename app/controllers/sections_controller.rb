class SectionsController < ApplicationController
  before_action :require_admin_access!, except: [:show]
  before_action :require_read_access!, only: [:show]
  before_action :set_section, only: [:show, :edit, :update, :destroy]

  def index
    @pagy, @sections = pagy(Section.includes(:grade, :academic_period).order("grades.name, sections.name"))
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
      redirect_to @section, notice: "Sección creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @section.update(section_params)
      redirect_to @section, notice: "Sección actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @section.destroy
      redirect_to sections_url, notice: "Sección eliminada exitosamente."
    else
      redirect_to @section, alert: @section.errors.full_messages.join(", ")
    end
  end

  private

  def set_section
    @section = Section.find(params[:id])
  end

  def section_params
    params.require(:section).permit(:name, :grade_id, :academic_period_id, :capacity, :classroom)
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
