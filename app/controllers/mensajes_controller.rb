# El colegio le escribe a una familia (MOR-181).
#
# Daniel: *«la comunicación con el representante es fundamental. Allí mismo
# debemos poder componerle un correo y enviárselo»*.
#
# ## ⚠️ Lo que esto NO es
#
# No es una bandeja: no guarda un hilo, no recibe respuestas y no se puede
# releer un mensaje viejo palabra por palabra. Manda un correo y deja constancia
# de que se mandó, con su asunto, en el registro de actividad.
#
# Decirlo importa porque el nombre invita a suponer lo otro. El día que haga
# falta el hilo completo, eso es una tabla y una pantalla más — no un ajuste de
# esto.
#
# ## Y por qué no `mailto:`
#
# Un `mailto:` no necesita servidor y era la respuesta corta. Pero abre el
# cliente de correo de QUIEN mira, que en la computadora del colegio muchas veces
# no está configurado, y sobre todo **no deja rastro**: nadie puede contestar
# después «¿le avisamos a la mamá de Eduardo?».
class MensajesController < ApplicationController
  before_action :require_puede_escribir!
  before_action :set_representante

  def create
    asunto = params[:asunto].to_s.strip
    cuerpo = params[:cuerpo].to_s.strip

    if asunto.blank? || cuerpo.blank?
      return redirect_to representative_path(@representante),
                         alert: "Escriba el asunto y el mensaje antes de enviar."
    end

    if @representante.user.email.blank?
      return redirect_to representative_path(@representante),
                         alert: "#{@representante.user.nombre_completo} no tiene correo cargado."
    end

    enviar(asunto, cuerpo)

    redirect_to representative_path(@representante),
                notice: "Mensaje enviado a #{@representante.user.email}."
  end

  private

  def set_representante
    @representante = Representative.find(params[:id])
  end

  def enviar(asunto, cuerpo)
    # `deliver_later`: el envío no puede hacer esperar a quien escribió, y si el
    # servidor de correo tarda o falla, el trabajo se reintenta solo. El worker
    # existe (`Procfile`), y `/salud` avisa si se cayó.
    ComunicacionMailer.mensaje_del_colegio(
      destinatario: @representante.user, colegio: Current.school,
      remitente: current_user, asunto: asunto, cuerpo: cuerpo
    ).deliver_later

    auditar(asunto, cuerpo)
  end

  # ⚠️ Se guarda el ASUNTO y el largo, no el cuerpo entero.
  #
  # La pregunta que un colegio necesita contestar es «¿le avisamos, y cuándo?»,
  # y eso lo responde el asunto con su fecha. Volcar el mensaje completo en el
  # registro de actividad —que ve cualquier administrador— convertiría la
  # auditoría en un archivo de correspondencia con la familia, que es otra cosa
  # y merece otra decisión.
  def auditar(asunto, cuerpo)
    log_activity(
      action:  "mensaje_enviado",
      subject: @representante,
      message: "#{current_user.nombre_completo} le escribió a " \
               "#{@representante.user.nombre_completo}: «#{asunto}»",
      metadata: { asunto: asunto, caracteres: cuerpo.length,
                  correo: @representante.user.email }
    )
  end

  def require_puede_escribir!
    return if administrador? && can_manage_students?

    redirect_to dashboard_path_for_user,
                alert: "Acceso no autorizado. Esta función es solo para administradores."
  end
end
