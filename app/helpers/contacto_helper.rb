# El WhatsApp por el que SIGA atiende (MOR-135).
#
# ## Por qué es una variable de entorno y no una constante en el repo
#
# Es un número de teléfono personal. Va en el entorno por lo mismo que las
# credenciales de la base: el repo es privado hoy, pero un dato de contacto real
# escrito en el código viaja a cada clon, a cada respaldo y a cada máquina de
# quien colabore algún día.
#
# **Si no está puesto, el botón no aparece.** No hay número de relleno: un botón
# de WhatsApp que abre un chat con nadie es peor que no tener botón — la
# directora ya hizo el gesto de escribir y se queda esperando una respuesta que
# no puede llegar.
#
#     export SIGA_WHATSAPP="584241234567"    # país + operadora + número, solo dígitos
module ContactoHelper
  SIGA_WHATSAPP = ENV["SIGA_WHATSAPP"].to_s.gsub(/\D/, "").freeze

  MENSAJE_INICIAL = "Hola, dirijo un colegio y me gustaría ver SIGA.".freeze

  # `wa.me` con el mensaje ya escrito: quien toca el botón cae en un chat con el
  # primer renglón puesto, y no en una pantalla en blanco donde hay que pensar
  # cómo empezar. Ese renglón en blanco es donde se pierde la conversación.
  def enlace_de_whatsapp(mensaje = MENSAJE_INICIAL)
    return nil if SIGA_WHATSAPP.blank?

    "https://wa.me/#{SIGA_WHATSAPP}?text=#{CGI.escape(mensaje)}"
  end

  def whatsapp_configurado? = SIGA_WHATSAPP.present?
end
