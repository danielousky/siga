class TeachersController < ApplicationController
  include GeneraCodigosDeAcceso

  genera_codigos_de_acceso_para :teacher
  before_action :require_admin_access!
  before_action :set_teacher, only: [:show, :edit, :update, :destroy, :generar_codigo]

  # Buscar por los datos de la PERSONA, no de la fila: quien busca tiene el
  # apellido o la cédula en la mano, nunca el id del rol.
  CAMPOS_DE_BUSQUEDA = %w[
    users.first_name users.last_name users.second_last_name
    users.document users.email
  ].freeze

  def index
    scope = Teacher.includes(:user, :school)
    if params[:q].present?
      ids = User.where(*BusquedaSinAcentos.condicion(CAMPOS_DE_BUSQUEDA, params[:q])).pluck(:id)
      scope = scope.where(user_id: ids)
    end

    @pagy, @teachers = pagy(scope.joins(:user).order("users.last_name, users.first_name"))
  end

  # La ficha del profesor.
  #
  # La pregunta que se hace quien la abre es "¿qué dicta y dónde?" — para
  # repartir carga, cubrir una ausencia o saber a quién llamar por una sección.
  # El `dl` anterior contestaba nombre, apellido, cédula y correo: las cuatro
  # cosas que ya estaban en la fila de la lista.
  def show
    @asignaciones = TeacherSection.del_anio_de_la_sesion.where(teacher_id: @teacher.id)
                                  .includes(:subject, section: [ :grade, :academic_period ])
                                  .to_a
                                  .sort_by { |a| [ a.section.grade.name, a.section.name, a.subject.name ] }

    # Los dos cargos, que son distintos (MOR-150): guía de una SECCIÓN —pasa
    # lista— y coordinador de un GRADO, que es opcional y casi nadie tiene.
    @guia_de = @teacher.led_sections.del_anio_de_la_sesion.includes(:grade).order("grades.name", :name).to_a
    @coordina = @teacher.coordinated_grades.order(:name).to_a
  end

  def new
    @teacher = Teacher.new
    @teacher.build_user
  end

  def edit; end

  def create
    @teacher = Teacher.new(teacher_params)
    if @teacher.save
      registrar_cambio(:creado, @teacher, "#{@teacher.user.nombre_completo}")
      redirect_to @teacher, notice: "Profesor creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @teacher.update(teacher_params)
      registrar_cambio(:actualizado, @teacher, "#{@teacher.user.nombre_completo}")
      redirect_to @teacher, notice: "Profesor actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # El nombre, antes de borrar: después el objeto ya no puede
    # resolver sus asociaciones para armar el mensaje.
    nombre = "#{@teacher.user.nombre_completo}"

    if @teacher.destroy
      registrar_cambio(:eliminado, @teacher, nombre)
      redirect_to teachers_url, notice: "Profesor eliminado exitosamente."
    else
      redirect_to @teacher, alert: @teacher.errors.full_messages.join(", ")
    end
  end

  private

  def set_teacher
    @teacher = Teacher.find(params[:id])
  end

  def teacher_params
    # `school_id` NO se permite: el colegio sale de la sesión, nunca del request (MOR-86).
    params.require(:teacher).permit(
      user_attributes: [:id, :first_name, :last_name, :second_last_name,
                        :document, :document_type, :cedula_escolar,
                        :birth_date, :sex, :birth_place,
                        :email, :password, :password_confirmation])
          .merge(school_id: Current.school_id)
  end

  def require_admin_access!
    unless administrador? && can_manage_teachers?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end
end
