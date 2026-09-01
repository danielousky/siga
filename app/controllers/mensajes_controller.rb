# El colegio le escribe a una familia (MOR-181).
#
# Daniel: *«la comunicación con el representante es fundamental. Allí mismo
# debemos poder componerle un correo y enviárselo»*.
#
# ## Lo que guarda, y lo que no
#
# Cada envío queda como un `Mensaje`: a quién, quién, qué, cuándo y a qué
# dirección. Eso es el seguimiento que pidió Daniel — *«simple, pero que al
# menos diga qué y cuándo se envió»*— y se ve en la ficha de la persona.
#
# ⚠️ Sigue sin ser una bandeja: no recibe respuestas ni arma un hilo. La familia
# responde al correo y eso llega al buzón de quien escribió, fuera de SIGA.
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
    # ⚠️ Se GUARDA antes de encolar, y en ese orden.
    #
    # `deliver_later` mete el trabajo en la cola; si el registro fallara después,
    # el correo ya estaría saliendo y no habría rastro de él. Al revés, un envío
    # que no se pudo encolar deja una fila de más — que se ve, se explica y se
    # puede reintentar. De los dos errores posibles, ese es el que se puede
    # arreglar.
    Mensaje.create!(school: Current.school, destinatario: @representante.user,
                    remitente: current_user, asunto: asunto, cuerpo: cuerpo,
                    correo: @representante.user.email)

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
