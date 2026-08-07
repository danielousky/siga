class DemoRequestsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create, :success]
  before_action :require_admin_access!, only: [:index, :show, :update]
  before_action :set_demo_request, only: [:show, :update]

  def index
    @pagy, @demo_requests = pagy(DemoRequest.recent, items: 20)
    @pending_count = DemoRequest.pending.count
    @system_distribution = DemoRequest.current_system_distribution
    @named_systems = DemoRequest.where.not(current_system_detail: [nil, ""])
                                .group(:current_system_detail).count
                                .sort_by { |_name, count| -count }
  end

  def show
  end

  def new
    @demo_request = DemoRequest.new
  end

  def create
    @demo_request = DemoRequest.new(demo_request_params)

    if @demo_request.save
      redirect_to success_demo_requests_path, notice: "¡Solicitud enviada exitosamente! Nos pondremos en contacto pronto."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @demo_request.update(admin_update_params)
      redirect_to demo_request_path(@demo_request), notice: "Estado actualizado exitosamente."
    else
      redirect_to demo_request_path(@demo_request), alert: "Error al actualizar el estado."
    end
  end

  def success
    # Página de éxito después de enviar la solicitud
  end

  private

  def set_demo_request
    @demo_request = DemoRequest.find(params[:id])
  end

  def demo_request_params
    params.require(:demo_request).permit(:name, :email, :institution, :phone, :message,
                                         :current_system, :current_system_detail)
  end

  def admin_update_params
    params.require(:demo_request).permit(:status)
  end

  def require_admin_access!
    unless administrador? && (current_user.admin.desarrollador? || current_user.admin.director?)
      redirect_to root_path, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end
end
