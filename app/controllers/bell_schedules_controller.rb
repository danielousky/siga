# Los TURNOS: a qué hora suena el timbre (spec `horarios`, tanda 1).
#
#     Académico ▸ Horarios        [ Turnos | Carga horaria ]
#
# ## Un turno se registra con cuatro números
#
# La entrada, cuánto dura cada hora, cuántas son y dónde va el receso. Las filas
# las arma `HorasDelTurno`; pedirlas una por una es pedirle al colegio una
# cuenta que el sistema hace mejor.
#
# ## ⚠️ Y se corrige en su propia ficha, no en un «editar»
#
# El nombre, cada hora en su fila y las secciones que lo usan viven en `show`.
# Son tres cosas que se tocan por separado y en momentos distintos: una pantalla
# de edición las juntaría en un solo «Guardar» que nadie sabría qué guardó.
#
# ## ⚠️ Son del año escolar de la sesión
#
# Con «Todos los años» elegido se cae en `anio_de_trabajo`, el que tiene clases:
# un turno sin año no existe.
class BellSchedulesController < ApplicationController
  el_nivel_no_aplica "un turno le sirve a secciones de cualquier nivel"

  before_action :require_admin_access!
  before_action :exigir_un_anio, only: [ :new, :create ]
  before_action :set_turno, only: [ :show, :update, :destroy ]

  def index
    @anio = anio_de_trabajo
    @turnos = @anio ? BellSchedule.where(academic_period: @anio).includes(:time_slots).order(:name).to_a : []
    @secciones_por_turno = Section.where(bell_schedule_id: @turnos.map(&:id)).group(:bell_schedule_id).count
  end

  # ⚠️ También es la VISTA PREVIA: el formulario lo vuelve a pedir, con lo
  # escrito, cada vez que cambia un número, y de acá sale el «Así queda». Una
  # sola cuenta —la de `HorasDelTurno`— para lo que se muestra y para lo que
  # después se guarda.
  def new
    @bell_schedule = BellSchedule.new(name: nombre_escrito)
    @timbre = HorasDelTurno.new(timbre_params)
  end

  def create
    @bell_schedule = BellSchedule.new(name: nombre_escrito, academic_period: anio_de_trabajo)
    @timbre = HorasDelTurno.new(timbre_params)

    # Las dos preguntas, siempre: si el nombre falta Y el timbre no cabe, la
    # persona tiene que leer los dos errores de una vez.
    if [ @timbre.valid?, @bell_schedule.valid? ].all?
      @bell_schedule.time_slots.build(@timbre.filas.map(&:to_h))
      @bell_schedule.save!
      registrar_cambio(:creado, @bell_schedule, @bell_schedule.name)
      redirect_to @bell_schedule, notice: "Turno «#{@bell_schedule.name}» registrado. Ahora marque qué secciones lo usan."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @horas = @bell_schedule.horas_con_nombre
    @secciones = Section.where(academic_period_id: @bell_schedule.academic_period_id)
                        .includes(:grade, :bell_schedule).to_a
                        .sort_by { |seccion| [ seccion.grade.orden || 99, seccion.grade.name, seccion.name ] }
  end

  # El nombre y las secciones llegan por formularios distintos, y cada uno trae
  # solo lo suyo: lo que no viene, no se toca.
  def update
    cambios = params.fetch(:bell_schedule, {}).permit(:name, section_ids: [])

    BellSchedule.transaction do
      @bell_schedule.update!(name: cambios[:name]) if cambios.key?(:name)
      asignar_secciones(cambios[:section_ids]) if cambios.key?(:section_ids)
    end

    registrar_cambio(:actualizado, @bell_schedule, @bell_schedule.name)
    redirect_to @bell_schedule, notice: "Turno actualizado."
  rescue ActiveRecord::RecordInvalid
    redirect_to @bell_schedule, alert: @bell_schedule.errors.full_messages.to_sentence
  end

  def destroy
    nombre = @bell_schedule.name

    if @bell_schedule.destroy
      registrar_cambio(:eliminado, @bell_schedule, nombre)
      redirect_to bell_schedules_path, notice: "Turno «#{nombre}» eliminado."
    else
      redirect_to @bell_schedule, alert: @bell_schedule.errors.full_messages.to_sentence
    end
  end

  private

  def set_turno
    @bell_schedule = BellSchedule.includes(:time_slots).find(params[:id])
  end

  def nombre_escrito = params.dig(:bell_schedule, :name)

  def timbre_params
    params.fetch(:timbre, {}).permit(:entrada, :minutos_por_hora, :horas_al_dia, :receso_minutos, :receso_tras)
  end

  # Las marcadas pasan a este turno; las que lo tenían y ya no están marcadas,
  # se quedan sin ninguno.
  #
  # ⚠️ Solo entre las secciones de SU año: un id de otro año —o de otro colegio,
  # que el `default_scope` ya deja fuera— no entra aunque venga en el formulario.
  def asignar_secciones(ids)
    del_anio = Section.where(academic_period_id: @bell_schedule.academic_period_id)
    marcadas = del_anio.where(id: Array(ids).compact_blank)

    @bell_schedule.sections.where.not(id: marcadas.select(:id)).update_all(bell_schedule_id: nil)
    marcadas.update_all(bell_schedule_id: @bell_schedule.id)
  end

  def exigir_un_anio
    return if anio_de_trabajo

    redirect_to bell_schedules_path, alert: "Antes hace falta registrar el año escolar: un turno es de un año."
  end

  def require_admin_access!
    return if administrador? && can_manage_sections?

    redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
  end
end
