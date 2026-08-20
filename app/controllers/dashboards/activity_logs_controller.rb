class Dashboards::ActivityLogsController < ApplicationController
  before_action :require_admin!

  # Sin prefijo de tabla: la consulta sale de `User`, sin joins.
  CAMPOS_DE_BUSQUEDA = %w[first_name last_name email document].freeze

  def index
    @logs = ActivityLog.includes(:user).recent

    if params[:usuario_q].present?
      user_ids = User.where(*BusquedaSinAcentos.condicion(CAMPOS_DE_BUSQUEDA, params[:usuario_q])).pluck(:id)
      @logs = @logs.where(user_id: user_ids)
      @usuario_match = User.where(id: user_ids).order(:last_name, :first_name).limit(5)
    end

    @logs = @logs.by_action(params[:activity_action]) if params[:activity_action].present?

    if params[:from].present?
      to = params[:to].present? ? Date.parse(params[:to]) : Date.today
      @logs = @logs.in_range(Date.parse(params[:from]), to)
    end

    @pagy, @logs = pagy(@logs, items: 50)
  end

  private

  def require_admin!
    unless administrador?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado."
    end
  end
end
