class GradesController < ApplicationController
  before_action :require_admin_access!
  before_action :set_grade, only: [:show, :edit, :update, :destroy]

  def index
    # ⚠️ `en_orden` y no el orden de inserción. Se veía en pantalla: «1er Año ·
    # 6to Grado · 1er Nivel», o sea las tres escaleras revueltas. `en_orden` los
    # ordena como los cursa un niño —preescolar, primaria, bachillerato— y es el
    # mismo scope que ya usan los desplegables.
    @pagy, @grades = pagy(Grade.del_nivel_de_la_sesion.en_orden.includes(:coordinator_teacher))
  end

  def show
    @grade_subjects = @grade.grade_subjects.includes(:subject)
    @available_subjects = Subject.where.not(id: @grade.subject_ids).order(:name)
  end

  def new
    @grade = Grade.new
  end

  def edit; end

  def create
    @grade = Grade.new(grade_params)
    if @grade.save
      redirect_to @grade, notice: "Grado creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @grade.update(grade_params)
      redirect_to @grade, notice: "Grado actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @grade.destroy
      redirect_to grades_url, notice: "Grado eliminado exitosamente."
    else
      redirect_to @grade, alert: @grade.errors.full_messages.join(", ")
    end
  end

  private

  def set_grade
    @grade = Grade.find(params[:id])
  end

  def grade_params
    # `school_id` NO se permite: el colegio sale de la sesión, nunca del request.
    params.require(:grade).permit(:name, :level, :escala, :coordinator_teacher_id)
          .merge(school_id: Current.school_id)
  end

  def require_admin_access!
    unless administrador? && can_manage_academic_config?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end
end
