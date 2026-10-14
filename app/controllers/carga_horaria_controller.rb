# La CARGA HORARIA: cuántas horas a la semana lleva cada área en cada grado
# (spec `horarios`, tanda 1).
#
#     Académico ▸ Horarios        [ Turnos | Carga horaria ]
#
# Debajo es `grade_subjects.weekly_hours`: el pensum, que ya decía QUÉ áreas
# cursa un grado, ahora dice también CUÁNTO.
#
# ## ⚠️ Se guarda TODO o NADA
#
# Es una matriz de cuarenta casillas con un solo «Guardar cambios». Si una está
# mal escrita y las otras treinta y nueve se guardaran, la pantalla diría
# «error» habiendo cambiado casi todo — la misma trampa que `/siga/ajustes`
# tuvo que aprender a decir con «No se guardó nada».
#
# ## ⚠️ El plan oficial se PROPONE, no se impone
#
# «Proponer las del plan oficial» llena solo las casillas vacías
# (`CargaHorariaOficial`). El plan pide 44 a 46 horas y un turno de mañana tiene
# 40: cada colegio lo ajusta, y esa decisión no se pisa con un botón.
class CargaHorariaController < ApplicationController
  before_action :require_admin_access!

  def show
    @carga = carga
  end

  def update
    escritas = params.fetch(:horas, {}).permit!.to_h
    errores = guardar(escritas)

    if errores.empty?
      log_activity(action: "carga_horaria_updated",
                   message: "#{current_user.nombre_completo} actualizó la carga horaria")
      redirect_to carga_horaria_path, notice: "Carga horaria guardada."
    else
      @carga = carga
      @escritas = escritas
      @errores = errores
      render :show, status: :unprocessable_entity
    end
  end

  def proponer
    resultado = CargaHorariaOficial.proponer!(GradeSubject.where(grade_id: grados.select(:id)))

    if resultado.propuestas.positive?
      log_activity(action: "carga_horaria_updated",
                   message: "#{current_user.nombre_completo} propuso la carga horaria del plan oficial")
    end

    redirect_to carga_horaria_path, notice: aviso_de(resultado)
  end

  private

  def carga = CargaHorariaDelColegio.new(grados: grados, anio: anio_de_trabajo)

  # Los grados del nivel de la sesión: la coordinadora de primaria no necesita
  # ver la carga de bachillerato para escribir la suya.
  def grados = Grade.del_nivel_de_la_sesion

  # `{ "id del renglón" => "4" }`. Un campo vacío es «nadie lo dijo», no cero.
  #
  # ⚠️ Se asigna el TEXTO, no un entero: «4.5» convertido con `to_i` sería un 4
  # guardado en silencio. Así lo ve la validación, que exige un entero.
  def guardar(escritas)
    renglones = GradeSubject.where(id: escritas.keys).includes(:grade, :subject).index_by { |r| r.id.to_s }
    errores = []

    GradeSubject.transaction(requires_new: true) do
      escritas.each do |id, valor|
        renglon = renglones[id] or next
        renglon.weekly_hours = valor.to_s.strip.presence
        next unless renglon.changed?
        next if renglon.save

        errores << "#{renglon.subject.name} en #{renglon.grade.name}: " \
                   "#{renglon.errors.full_messages.to_sentence}"
      end

      raise ActiveRecord::Rollback if errores.any?
    end

    errores
  end

  def aviso_de(resultado)
    return "No había casillas vacías que el plan oficial pudiera llenar." if resultado.nada?

    partes = []
    if resultado.propuestas.positive?
      partes << "Se propusieron #{helpers.contar(resultado.propuestas, 'casilla', 'casillas')} con las horas del plan oficial."
    end
    if resultado.fuera_del_plan.any?
      partes << "El plan no dice nada de #{resultado.fuera_del_plan.to_sentence}: escríbalas a mano."
    end
    partes.join(" ")
  end

  def require_admin_access!
    return if administrador? && can_manage_sections?

    redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
  end
end
