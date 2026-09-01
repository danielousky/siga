class StudentsController < ApplicationController
  before_action :require_admin_access!
  before_action :set_student, only: [:show, :edit, :update, :destroy]

  # Dónde busca el buscador. La cédula y el carnet no llevan acentos, pero pasan
  # por la misma expresión igual: un solo camino es más fácil de sostener que dos,
  # y `translate()` sobre un texto sin acentos no le cambia nada.
  CAMPOS_DE_BUSQUEDA = %w[
    users.first_name users.last_name users.document students.school_card
  ].freeze

  def index
    scope = Student.includes(:user, :school)
    if params[:q].present?
      scope = scope.joins(:user).where(*BusquedaSinAcentos.condicion(CAMPOS_DE_BUSQUEDA, params[:q]))
    end
    # ⚠️ El filtro que el panel necesita para poder ENLAZAR su aviso (MOR-180).
    #
    # «200 alumnos no tienen representante registrado» era un número sin destino,
    # o sea una preocupación y no una tarea. Ahora el aviso lleva acá con el
    # filtro puesto, y desde cada ficha se resuelve.
    scope = scope.sin_representante if sin_representante?

    @sin_representante = sin_representante?
    @cuantos_sin_representante = Student.sin_representante.count
    @pagy, @students = pagy(scope.order("users.last_name, users.first_name"))
  end

  # Se lee del request y no de un `params[]` suelto en la vista: el filtro decide
  # qué se consulta Y cómo se pinta la pantalla, y las dos tienen que mirar lo
  # mismo.
  helper_method :sin_representante?
  def sin_representante? = params[:sin_representante].present?

  # La ficha del alumno.
  #
  # ## Para qué se abre esta pantalla, de verdad
  #
  # Antes era un `dl` del generador con cinco campos —nombre, apellido, cédula,
  # correo, carnet— que ya estaban todos en la fila de la lista. O sea: abrirla
  # no agregaba nada, y encima venía con clases de Bootstrap que esta app no
  # carga, así que salía sin estilo. Daniel la vio y dijo "eso está crudo".
  #
  # La secretaría la abre por tres motivos, en este orden:
  #
  #   1. **Llamar a la familia.** Es el motivo número uno y el dato no estaba
  #      por ningún lado: había que ir a Representantes y buscar al revés.
  #   2. Confirmar en qué sección está inscrito, para una constancia o un cupo.
  #   3. Ver cómo va, cuando el representante pregunta por teléfono.
  #
  # Por eso el orden de la pantalla es ese y no el del `schema.rb`.
  def show
    @inscripcion = @student.enrollments
                           .includes(section: [ :grade, :academic_period ])
                           .order(created_at: :desc)
                           .find(&:regular?)

    @responsables = StudentRepresentative
                      .where(student_id: @student.id)
                      .includes(representative: :user)
                      .order(principal: :desc)

    return if @inscripcion.nil?

    @lapsos = EvaluationMoment.where(academic_period_id: @inscripcion.section.academic_period_id)
                              .order(:id).to_a
    @lapso  = @lapsos.find { |l| l.id == params[:lapso].to_i } || @lapsos.first
    @boletin = ReportCardData.para(enrollment: @inscripcion, evaluation_moment: @lapso).to_h if @lapso
  end

  def new
    @student = Student.new
    @student.build_user
  end

  def edit; end

  def create
    @student = Student.new(student_params)
    if @student.save
      log_activity(
        action:  "student_created",
        message: "#{current_user.nombre_completo} registró al alumno " \
                 "#{@student.user.nombre_completo} (Exp: #{@student.school_card})",
        subject: @student
      )
      redirect_to @student, notice: "Alumno creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @student.update(student_params)
      log_activity(
        action:  "student_updated",
        message: "#{current_user.nombre_completo} actualizó los datos del alumno " \
                 "#{@student.user.nombre_completo}",
        subject: @student
      )
      redirect_to @student, notice: "Alumno actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    student_name = "#{@student.user.nombre_completo}"
    if @student.destroy
      log_activity(
        action:  "student_destroyed",
        message: "#{current_user.nombre_completo} eliminó al alumno #{student_name}"
      )
      redirect_to students_url, notice: "Alumno eliminado exitosamente."
    else
      redirect_to @student, alert: @student.errors.full_messages.join(", ")
    end
  end

  private

  def set_student
    @student = Student.find(params[:id])
  end

  def student_params
    # `school_id` NO se permite: el colegio sale de la sesión, nunca del request (MOR-86).
    params.require(:student).permit(:school_card,
      user_attributes: [:id, :first_name, :last_name, :second_last_name,
                        :document, :document_type, :cedula_escolar,
                        :birth_date, :sex, :birth_place,
                        :email, :password, :password_confirmation])
          .merge(school_id: Current.school_id)
  end

  def require_admin_access!
    unless administrador? && can_manage_students?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end
end
