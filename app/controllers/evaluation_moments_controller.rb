class EvaluationMomentsController < ApplicationController
  before_action :require_admin_access!
  before_action :set_evaluation_moment, only: [:edit, :update, :destroy]

  def index
    @pagy, @evaluation_moments = pagy(
      EvaluationMoment.includes(academic_period: :school).order(:academic_period_id, :id)
    )
  end


  def new
    @evaluation_moment = EvaluationMoment.new
  end

  def edit; end

  def create
    @evaluation_moment = EvaluationMoment.new(evaluation_moment_params)
    if @evaluation_moment.save
      registrar_cambio(:creado, @evaluation_moment, @evaluation_moment.name)
      redirect_to evaluation_moments_path, notice: "Momento de evaluación creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @evaluation_moment.update(evaluation_moment_params)
      registrar_cambio(:actualizado, @evaluation_moment, @evaluation_moment.name)
      redirect_to evaluation_moments_path, notice: "Momento de evaluación actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # El nombre, antes de borrar: después el objeto ya no puede
    # resolver sus asociaciones para armar el mensaje.
    nombre = @evaluation_moment.name

    if @evaluation_moment.destroy
      registrar_cambio(:eliminado, @evaluation_moment, nombre)
      redirect_to evaluation_moments_url, notice: "Momento de evaluación eliminado exitosamente."
    else
      redirect_to evaluation_moments_path, alert: @evaluation_moment.errors.full_messages.join(", ")
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
