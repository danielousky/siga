# El WhatsApp por el que SIGA atiende (MOR-135).
#
# ## De dónde sale el número
#
# De `Setup` —nombre y valor—, que el fundador cambia desde `/siga/ajustes`
# (spec `del-registro-al-cobro`, decisiones 20 y 35). Hasta el 12 de octubre de
# 2026 era la variable de entorno `SIGA_WHATSAPP`, leída UNA vez al arrancar:
# cambiar de número era reiniciar la app. La variable sigue sirviendo de valor
# inicial —`Setup.whatsapp`— para que el botón no desapareciera el día del
# cambio, y para la muestra, donde nadie entra a `/siga`.
#
# La razón por la que el número nunca estuvo en el repo —es un teléfono
# personal— sigue cumplida: en la base tampoco está en el repo.
#
# **Si no está puesto, el botón no aparece.** No hay número de relleno: un botón
# de WhatsApp que abre un chat con nadie es peor que no tener botón — la
# directora ya hizo el gesto de escribir y se queda esperando una respuesta que
# no puede llegar.
module ContactoHelper
  MENSAJE_INICIAL = "Hola, dirijo un colegio y me gustaría ver SIGA.".freeze

  # `wa.me` con el mensaje ya escrito: quien toca el botón cae en un chat con el
  # primer renglón puesto, y no en una pantalla en blanco donde hay que pensar
  # cómo empezar. Ese renglón en blanco es donde se pierde la conversación.
  def enlace_de_whatsapp(mensaje = MENSAJE_INICIAL)
    Setup.whatsapp_url(mensaje)
  end

  def whatsapp_configurado? = Setup.whatsapp?
end
