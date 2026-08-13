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

  # ⚠️ Las solicitudes de demo son de SIGA, no de ningún colegio.
  #
  # Hasta acá esto dejaba pasar a cualquier `director`, o sea que **el director de
  # un colegio cliente veía el pipeline comercial completo**: el nombre, el correo,
  # el teléfono y el sistema que usa hoy cada colegio que pidió una demo. Entre
  # esos colegios hay competidores entre sí, y varios podrían ser clientes futuros
  # que todavía no firmaron.
  #
  # Ninguna de las dos capas de aislamiento lo tapaba, y no podían: `demo_requests`
  # **no tiene `school_id`**. Es dato de la plataforma, no de un inquilino — así
  # que `SchoolScoped` no aplica y el RLS tampoco. Es el mismo hueco que el
  # `School.all` de los formularios: la defensa en profundidad protege los datos
  # DEL inquilino, no el catálogo DE inquilinos.
  #
  # `desarrollador` es un parche, no la solución: hoy ese rol cuelga de un colegio
  # como cualquier otro admin. Lo que corresponde es un panel de SIGA separado del
  # de los colegios — ver el proyecto "Apreciaciones Iniciales de la
  # Implementación", milestone "División de Admins".
  def require_admin_access!
    return if administrador? && current_user.admin.desarrollador?

    redirect_to dashboard_path_for_user,
                alert: "Esta sección es de la administración de SIGA."
  end
end
