class AcademicPeriodsController < ApplicationController
  before_action :require_admin_access!
  before_action :set_academic_period, only: [:edit, :update, :destroy]

  def index
    # ⚠️ Del más RECIENTE al más viejo. Sin orden salían por id, o sea por el
    # orden en que se crearon — y el año que se está armando, que es el que se
    # viene a tocar, quedaba al final de la lista.
    @pagy, @academic_periods = pagy(AcademicPeriod.includes(:school).order(start_date: :desc))
  end


  def new
    @academic_period = AcademicPeriod.new
  end

  def edit; end

  # ⚠️ El año escolar se construye a partir de UN número (MOR-163).
  #
  # `AcademicPeriod.para_el_anio` arma el nombre y las dos fechas: el formulario
  # pregunta qué año empieza y nada más. Las fechas solo llegan si el colegio
  # abrió «mi calendario no es el de siempre», y entonces ganan.
  def create
    @academic_period = AcademicPeriod.para_el_anio(params[:anio])
    @academic_period.assign_attributes(fechas_propias) if fechas_propias.any?

    if @academic_period.save
      # ⚠️ Los lapsos nacen CON el año (MOR-163). Son tres, se llaman igual
      # siempre y reparten el año en tercios: pedirle al director que los cree
      # es pedirle que escriba lo que el sistema ya sabe. Si un feriado corre
      # una fecha, la corrige.
      @academic_period.sembrar_lapsos
      registrar_cambio(:creado, @academic_period, @academic_period.name)
      redirect_to academic_periods_path, notice: "Año escolar creado, con sus tres lapsos. Ajuste las fechas si su calendario es otro."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @academic_period.update(academic_period_params)
      registrar_cambio(:actualizado, @academic_period, @academic_period.name)
      redirect_to academic_periods_path, notice: "Año escolar actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # El nombre, antes de borrar: después el objeto ya no puede
    # resolver sus asociaciones para armar el mensaje.
    nombre = @academic_period.name

    if @academic_period.destroy
      registrar_cambio(:eliminado, @academic_period, nombre)
      redirect_to academic_periods_url, notice: "Año escolar eliminado."
    else
      redirect_to academic_periods_path, alert: @academic_period.errors.full_messages.join(", ")
    end
  end

  private

  # Solo lo que el colegio escribió a mano. Un campo vacío NO pisa la fecha que
  # calculó el modelo: mandaría un año sin duración, que es lo que este cambio
  # vino a arreglar.
  def fechas_propias
    @fechas_propias ||= params.fetch(:academic_period, {})
                              .permit(:start_date, :end_date)
                              .to_h.compact_blank
  end

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
