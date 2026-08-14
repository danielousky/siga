module Siga
  # El pipeline comercial (`demo_requests`), en su lugar.
  #
  # Acá es donde el problema se ve entero. Este dato **es de SIGA**: quién pidió
  # una demo, su correo, su teléfono y qué sistema usa hoy — con colegios que
  # compiten entre sí en la misma lista, y prospectos que todavía no firmaron.
  #
  # Vivía en el panel de los colegios y se tapó tres veces:
  #
  #   1. `require_admin_access!` dejaba pasar a cualquier `director`
  #   2. el panel seguía mostrando CUÁNTAS solicitudes había pendientes
  #   3. y el enlace del menú delataba que la sección existía
  #
  # Ninguna de las dos capas de aislamiento lo alcanzaba, y no podían:
  # `demo_requests` **no tiene `school_id`**. La defensa en profundidad protege
  # los datos DEL inquilino, no el catálogo DE inquilinos ni los de la
  # plataforma.
  #
  # Moverlo acá no es cosmético: **el panel del colegio deja de tener este
  # controller**. No hay pantalla que tapar.
  class SolicitudesController < BaseController
    before_action :set_solicitud, only: [:show, :update]

    def index
      scope = params[:estado].present? ? DemoRequest.where(status: params[:estado]) : DemoRequest.all
      @pagy, @solicitudes = pagy(scope.recent, items: 25)

      @pendientes   = DemoRequest.pending.count
      @por_sistema  = DemoRequest.current_system_distribution
      @nombrados    = DemoRequest.where.not(current_system_detail: [nil, ""])
                                 .group(:current_system_detail).count
                                 .sort_by { |_nombre, cuantos| -cuantos }
    end

    def show
    end

    def update
      if @solicitud.update(estado_params)
        redirect_to siga_solicitud_path(@solicitud), notice: "Estado actualizado."
      else
        redirect_to siga_solicitud_path(@solicitud), alert: "No se pudo actualizar el estado."
      end
    end

    private

    def set_solicitud
      @solicitud = DemoRequest.find(params[:id])
    end

    def estado_params
      params.require(:demo_request).permit(:status)
    end
  end
end
