# Ubicar y quitar clases desde «Armar» (spec `horarios`, decisión 23).
#
# Las dos acciones vuelven a la rejilla de la sección con su mensaje —lo que
# quedó guardado, o por qué no se pudo—, que brinca al llegar (decisión 24).
# El porqué lo escribe `ArmadorDeLaSeccion`, y cada clase se guarda en su
# SAVEPOINT: si dos llenan la misma casilla a la vez, la segunda lee un
# mensaje y no un error 500.
class LessonsController < ApplicationController
  el_nivel_no_aplica "el horario se arma sección por sección"

  before_action :solo_quien_arma
  before_action :set_seccion

  def create
    materia = Subject.find(params[:subject_id])
    hora = @seccion.bell_schedule&.time_slots&.find_by(id: params[:time_slot_id])
    return volver(ArmadorDeLaSeccion::Mensaje.new(texto: "Esa hora no es del turno de la sección.", tipo: "aviso", area: materia)) unless hora

    volver ArmadorDeLaSeccion.new(@seccion).ubicar(materia, dia: params[:dia].to_i, hora:,
                                                   en_bloques: session.fetch(:horario_en_bloques, true))
  end

  def destroy
    volver ArmadorDeLaSeccion.new(@seccion).quitar(@seccion.lessons.find(params[:id]))
  end

  private

  def volver(mensaje)
    flash[:horario] = { "texto" => mensaje.texto, "tipo" => mensaje.tipo }
    redirect_to horarios_path(seccion: @seccion.id, armar: 1, area: mensaje.area&.id)
  end

  def set_seccion
    @seccion = Section.find(params[:section_id])
  end

  def solo_quien_arma
    return if administrador? && can_manage_sections?

    redirect_to dashboard_path_for_user, alert: "Armar el horario es de quien administra las secciones."
  end
end
