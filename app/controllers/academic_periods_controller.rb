class AcademicPeriodsController < ApplicationController
  before_action :require_admin_access!
  before_action :set_academic_period, only: [:show, :edit, :update, :destroy]

  def index
    @pagy, @academic_periods = pagy(AcademicPeriod.includes(:school))
  end

  def show; end

  def new
    @academic_period = AcademicPeriod.new
  end

  def edit; end

  def create
    @academic_period = AcademicPeriod.new(academic_period_params)
    if @academic_period.save
      redirect_to @academic_period, notice: "Período académico creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @academic_period.update(academic_period_params)
      redirect_to @academic_period, notice: "Período académico actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @academic_period.destroy
      redirect_to academic_periods_url, notice: "Período académico eliminado exitosamente."
    else
      redirect_to @academic_period, alert: @academic_period.errors.full_messages.join(", ")
    end
  end

  private

  def set_academic_period
    @academic_period = AcademicPeriod.find(params[:id])
  end

  def academic_period_params
    # `school_id` NO se permite: el colegio sale de la sesión, nunca del request (MOR-86).
    params.require(:academic_period).permit(:name, :start_date, :end_date)
          .merge(school_id: Current.school_id)
  end

  def require_admin_access!
    unless administrador? && can_manage_academic_config?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end
end
