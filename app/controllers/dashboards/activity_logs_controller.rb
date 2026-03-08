class Dashboards::ActivityLogsController < ApplicationController
  before_action :require_admin!

  def index
    @logs = ActivityLog.includes(:user)
                       .recent

    @logs = @logs.by_user(params[:user_id])   if params[:user_id].present?
    @logs = @logs.by_action(params[:action])  if params[:action].present?

    if params[:from].present?
      to = params[:to].present? ? Date.parse(params[:to]) : Date.today
      @logs = @logs.in_range(Date.parse(params[:from]), to)
    end

    @pagy, @logs = pagy(@logs, items: 50)
    @users        = User.order(:last_name, :name).select(:id, :name, :last_name)
  end

  private

  def require_admin!
    unless administrador?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado."
    end
  end
end
