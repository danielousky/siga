# El WhatsApp por el que SIGA atiende (MOR-135).
#
# ## De dónde sale el número
#
# De los ajustes de la plataforma, que el fundador cambia desde `/siga/ajustes`
# (spec `del-registro-al-cobro`, decisión 20). Hasta el 12 de octubre de 2026
# era la variable de entorno `SIGA_WHATSAPP`, leída UNA vez al arrancar:
# cambiar de número era reiniciar la app. La variable sigue sirviendo de valor
# inicial —`SigaSetting.actuales`— para que el botón no desapareciera el día
# del cambio.
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
    ajustes_de_siga.whatsapp_url(mensaje)
  end

  def whatsapp_configurado? = ajustes_de_siga.whatsapp?

  # Una consulta por página, aunque la página pregunte tres veces.
  def ajustes_de_siga
    @ajustes_de_siga ||= SigaSetting.actuales
  end
end
