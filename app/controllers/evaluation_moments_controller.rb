class EvaluationMomentsController < ApplicationController
  before_action :require_admin_access!
  before_action :set_evaluation_moment, only: [:edit, :update, :destroy]

  # ⚠️ Filtrado por el AÑO ESCOLAR DE LA SESIÓN (MOR-165).
  #
  # Antes listaba los lapsos de todos los años juntos, y con tres años cargados
  # eran nueve filas donde el año era la única diferencia. Ahora el recorte lo
  # da el selector de la barra, y «todos los años» sigue siendo una opción.
  def index
    lapsos = EvaluationMoment.includes(academic_period: :school)
                             .order(:academic_period_id, :starts_on, :id)
    lapsos = lapsos.where(academic_period_id: Current.academic_period_id) if Current.un_solo_anio?

    @pagy, @evaluation_moments = pagy(lapsos)
  end


  # El año escolar NO se pregunta: es el de la sesión.
  def new
    @evaluation_moment = EvaluationMoment.new(academic_period: Current.academic_period)
  end

  def edit; end

  def create
    @evaluation_moment = EvaluationMoment.new(evaluation_moment_params)
    if @evaluation_moment.save
      registrar_cambio(:creado, @evaluation_moment, @evaluation_moment.name)
      redirect_to evaluation_moments_path, notice: "Lapso creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @evaluation_moment.update(evaluation_moment_params)
      registrar_cambio(:actualizado, @evaluation_moment, @evaluation_moment.name)
      redirect_to evaluation_moments_path, notice: "Lapso actualizado."
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
      redirect_to evaluation_moments_url, notice: "Lapso eliminado."
    else
      redirect_to evaluation_moments_path, alert: @evaluation_moment.errors.full_messages.join(", ")
    end
  end

  private

  def set_evaluation_moment
    @evaluation_moment = EvaluationMoment.find(params[:id])
  end

  def evaluation_moment_params
    # `academic_period_id` NO se acepta del formulario: sale de la sesión. Si
    # viniera del request, alguien podría crear un lapso en el año de otro
    # colegio — que es exactamente de donde el inquilino nunca puede venir.
    params.require(:evaluation_moment).permit(:name, :starts_on, :ends_on)
          .merge(academic_period: Current.academic_period)
  end

  def require_admin_access!
    unless administrador? && can_manage_academic_config?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end
end
