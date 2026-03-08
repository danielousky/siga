class InicioController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    # Si está autenticado, redirigir a su dashboard
    if user_signed_in?
      case current_user_type
      when :administrador
        redirect_to dashboards_administrador_path and return
      when :profesor
        redirect_to dashboards_profesor_path and return
      when :estudiante
        redirect_to dashboards_estudiante_path and return
      else
        # Usuario sin rol asignado, mostrar mensaje
        flash.now[:alert] = "Tu cuenta no tiene un rol asignado. Contacta al administrador."
      end
    end
    # Si no está autenticado, mostrar página de inicio pública (landing page)
  end
end
