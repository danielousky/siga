module Siga
  # Dar de alta un colegio nuevo.
  #
  # Es uno de los criterios de aceptación de `MOR-133`, y hoy se hace **por
  # consola** — está escrito así en `DESPLIEGUE.md`. Un alta que exige abrir una
  # terminal contra producción no escala más allá del primer cliente, y cada vez
  # que se hace hay un superusuario tocando la base de todos los colegios.
  class ColegiosController < BaseController
    include NormalizaLaUbicacion
    before_action :exigir_fundador!, only: [:new, :create]
    before_action :set_colegio, only: [:show]

    def index
      @colegios = School.order(:name).to_a
      @alumnos  = Student.group(:school_id).count
    end

    def show
      @alumnos    = Student.where(school_id: @colegio.id).count
      @profesores = Teacher.where(school_id: @colegio.id).count
      @secciones  = Section.where(school_id: @colegio.id).count
      @periodos   = AcademicPeriod.where(school_id: @colegio.id).order(:start_date)
      @admins     = Admin.includes(:user).where(school_id: @colegio.id)
    end

    def new
      @colegio = School.new
      # También el director: el formulario los pide juntos, y el parcial de
      # errores necesita un objeto aunque todavía no haya nada que mostrar.
      @usuario = User.new
    end

    # Crea el colegio Y su primer director en la misma transacción.
    #
    # Un colegio sin nadie que pueda entrar no sirve para nada, y dejarlo en dos
    # pasos garantiza que alguna vez quede uno a medias — el alta se hace una vez
    # por cliente y nadie recuerda el segundo paso.
    def create
      @colegio = School.new(con_la_ubicacion_resuelta(colegio_params))
      @usuario = User.new(usuario_params)

      School.transaction do
        @colegio.save!
        # Sin contraseña, a propósito. Antes se le ponía una aleatoria de 14
        # caracteres que NADIE conocía —ni el director ni quien lo dio de alta—,
        # así que el primer cliente de un colegio nuevo quedaba sin poder entrar
        # y la nota del formulario lo admitía. Ahora se activa como todos
        # (`MOR-143`), y el código sale abajo.
        @usuario.save!
        Admin.create!(user: @usuario, school: @colegio, role: :director)
      end

      codigo = @usuario.generar_codigo_de_acceso!
      AccesoMailer.activacion(@usuario, codigo, @colegio).deliver_later

      redirect_to siga_colegio_path(@colegio),
                  flash: { codigo: codigo,
                           notice: "Colegio dado de alta. Hágale llegar este enlace a #{@usuario.first_name}." }
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    private

    def colegio_params
      params.require(:school).permit(:name, :dea_code, :location, :school_type,
                                     :entidad_federal, :municipio, :municipio_libre,
                                     :parroquia, :parroquia_libre,
                                     :direccion, :telefono)
    end

    def usuario_params
      params.require(:director).permit(:first_name, :last_name, :second_last_name, :email,
                                :document, :document_type, :cedula_escolar,
                                :birth_date, :sex)
    end

    def set_colegio
      @colegio = School.find(params[:id])
    end

    def exigir_fundador!
      return if siga_staff.puede_dar_de_alta_colegios?

      redirect_to siga_colegios_path, alert: "Dar de alta colegios es de fundador."
    end
  end
end
