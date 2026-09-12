class EnrollmentsController < ApplicationController
  before_action :require_admin_access!
  before_action :set_enrollment, only: [:edit, :update, :destroy]

  # Acá se busca al alumno, no a la inscripción: por eso son campos de `users`.
  CAMPOS_DE_BUSQUEDA = %w[users.first_name users.last_name users.second_last_name users.document].freeze

  def index
    scope = Enrollment.del_anio_de_la_sesion.del_nivel_de_la_sesion
                      .includes(student: :user, section: [:grade, :academic_period])
                      .joins(student: :user, section: :grade)
    if params[:q].present?
      scope = scope.where(*BusquedaSinAcentos.condicion(CAMPOS_DE_BUSQUEDA, params[:q]))
    end
    scope = scope.where(sections: { grade_id: params[:grade_id] }) if params[:grade_id].present?
    @pagy, @enrollments = pagy(scope.order("users.last_name, users.first_name"))
    @grades_options = helpers.grados_por_nivel
  end


  # Inscribir es UNA decisión: a quién.
  #
  #     ANTES                       AHORA
  #     Alumno   [Seleccione… ▾]    🔍 escriba el apellido
  #     Sección  [Seleccione… ▾]    ╭──╮ López Medina, Álvaro  [+ Inscribir]
  #     Estado   (Regular)(Retir.)  ╰──╯ sin inscripción
  #     Fecha    [11/09/2026]
  #
  # ⚠️ El ESTADO y la FECHA salieron del formulario, y no por gusto:
  #
  #   · una inscripción nace `regular` SIEMPRE. Retirar a alguien es otra
  #     acción, con otro momento y otra pantalla (`MOR-182`).
  #   · la fecha es un HECHO —cuándo se hizo el trámite—, no una decisión.
  #     Preguntarla invita a cambiarla, y una inscripción con fecha inventada
  #     descuadra la matrícula que se factura.
  #
  # ⚠️ Y la lista muestra también a los que YA están inscritos, apagados y con
  # dónde. Es lo que evita el error de septiembre: inscribir dos veces al mismo
  # niño porque no se sabía que ya estaba.
  def new
    @enrollment = Enrollment.new
    preparar_la_lista
  end

  def edit; end


  def create
    @enrollment = Enrollment.new(enrollment_params)
    # ⚠️ La fecha la pone el sistema: es cuándo se hizo el trámite. El
    # formulario ya no la pregunta (ver `new`), pero el campo sigue permitido
    # para el día que haga falta cargar una inscripción atrasada.
    @enrollment.enrollment_date ||= Date.current

    if @enrollment.save
      log_activity(
        action:  "enrollment_created",
        message: "#{current_user.nombre_completo} inscribió al alumno " \
                 "#{@enrollment.student.user.nombre_completo} en " \
                 "#{@enrollment.section.grade.name} – Sección #{@enrollment.section.name}",
        subject: @enrollment
      )
      registrar_cambio(:creado, @enrollment, "#{@enrollment.student.user.last_name}, #{@enrollment.student.user.first_name}")
      # ⚠️ Vuelve a la MISMA pantalla, no al listado. En septiembre se inscriben
      # veinte seguidos: mandar al listado obliga a volver a entrar veinte
      # veces, y a buscar otra vez la sección cada una.
      redirect_to new_enrollment_path(section_id: @enrollment.section_id),
                  notice: "#{@enrollment.student.user.apellidos_y_nombres} quedó inscrito."
    else
      preparar_la_lista
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @enrollment.update(enrollment_params)
      registrar_cambio(:actualizado, @enrollment, "#{@enrollment.student.user.last_name}, #{@enrollment.student.user.first_name}")
      redirect_to enrollments_path, notice: "Inscripción actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    student_name = "#{@enrollment.student.user.nombre_completo}"
    section_name = "#{@enrollment.section.grade.name} – Sección #{@enrollment.section.name}"
    if @enrollment.destroy
      log_activity(
        action:  "enrollment_destroyed",
        message: "#{current_user.nombre_completo} anuló la inscripción de " \
                 "#{student_name} en #{section_name}"
      )
      redirect_to enrollments_url, notice: "Inscripción eliminada exitosamente."
    else
      redirect_to enrollments_path, alert: @enrollment.errors.full_messages.join(", ")
    end
  end

  private

  # A quién se le puede inscribir, y dónde está cada uno ESTE año.
  #
  # ⚠️ Los ya inscritos también se listan, apagados y con su sección. Es lo que
  # evita el error de septiembre: inscribir dos veces al mismo niño porque no se
  # sabía que ya estaba.
  def preparar_la_lista
    @seccion = Section.del_anio_de_la_sesion.find_by(id: @enrollment&.section_id || params[:section_id])
    # Una consulta para las trescientas filas.
    @donde_esta = Enrollment.del_anio_de_la_sesion.includes(section: :grade).index_by(&:student_id)
    # ⚠️ Los que se pueden inscribir van PRIMERO. En un colegio con la matrícula
    # cargada están inscritos los trescientos sesenta, y el que acaba de
    # registrarse queda al final por apellido: hay que bajar toda la lista para
    # llegar al único que se puede tocar.
    @alumnos = Student.includes(:user).to_a
                      .sort_by { |a| [ @donde_esta.key?(a.id) ? 1 : 0, a.user.clave_alfabetica ] }
  end

  def set_enrollment
    @enrollment = Enrollment.find(params[:id])
  end

  # ⚠️ Al EDITAR, el alumno no se acepta (MOR-182).
  #
  # Daniel: «¿encuentras sentido en editar una inscripción? Lo que veo es el
  # cambio de estado o de sección. Nunca el cambio de estudiante».
  #
  # Tiene razón, y no es una preferencia: una inscripción ES «este alumno en esta
  # sección». Cambiarle el alumno no la corrige, la convierte en otra —y se lleva
  # consigo las notas, la asistencia y los boletines que colgaban de ella, que
  # son de la persona anterior—.
  #
  # La fecha tampoco: es un hecho, cuándo se hizo el trámite. Si está mal, se
  # anula la inscripción y se hace de nuevo.
  def enrollment_params
    permitidos = params.require(:enrollment).permit(:student_id, :section_id, :enrollment_date, :status)
    return permitidos unless @enrollment&.persisted?

    permitidos.slice(:section_id, :status)
  end

  def require_admin_access!
    unless administrador? && can_manage_sections?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end
end
