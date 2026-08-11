class EvaluationMomentsController < ApplicationController
  before_action :require_admin_access!
  before_action :set_evaluation_moment, only: [:show, :edit, :update, :destroy]

  def index
    @pagy, @evaluation_moments = pagy(
      EvaluationMoment.includes(academic_period: :school).order(:academic_period_id, :id)
    )
  end

  def show; end

  def new
    @evaluation_moment = EvaluationMoment.new
  end

  def edit; end

  def create
    @evaluation_moment = EvaluationMoment.new(evaluation_moment_params)
    if @evaluation_moment.save
      redirect_to @evaluation_moment, notice: "Momento de evaluación creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @evaluation_moment.update(evaluation_moment_params)
      redirect_to @evaluation_moment, notice: "Momento de evaluación actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @evaluation_moment.destroy
      redirect_to evaluation_moments_url, notice: "Momento de evaluación eliminado exitosamente."
    else
      redirect_to @evaluation_moment, alert: @evaluation_moment.errors.full_messages.join(", ")
    end
  end

  private

  def set_evaluation_moment
    @evaluation_moment = EvaluationMoment.find(params[:id])
  end

  def evaluation_moment_params
    params.require(:evaluation_moment).permit(:academic_period_id, :name, :weight)
  end

  def require_admin_access!
    unless administrador? && can_manage_academic_config?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end
end
