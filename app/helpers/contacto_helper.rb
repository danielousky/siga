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

  # El enlace de acceso de una persona, mandado por WhatsApp de un toque.
  #
  # Hasta el 16 de octubre de 2026 la secretaria lo copiaba, tocaba [WhatsApp]
  # junto al teléfono —que abría el chat con un saludo y SIN el enlace— y lo
  # pegaba. Daniel lo eligió para el video de los representantes: *«generarle
  # el enlace para enviárselo por WhatsApp… es algo novedoso y fácil»*.
  #
  # ⚠️ Nombra al colegio y a los hijos. Un enlace que llega de un número
  # desconocido es lo que una mamá aprendió a no abrir; con el nombre de su hija,
  # sabe de quién es.
  #
  # ⚠️ Los plazos salen de `User::ACTIVACION_VALIDA_POR`: escritos aquí a mano,
  # el día que cambien el mensaje prometería horas que el enlace ya no tiene.
  #
  # `nil` si el teléfono no es un celular: un fijo no tiene WhatsApp.
  def whatsapp_con_el_enlace(telefono, enlace, hijos: [])
    nombres = hijos.filter_map { |nombre| Normaliza.titulo(nombre.to_s.split.first).presence }.uniq
    de_quien = nombres.any? ? "las notas de #{nombres.to_sentence(two_words_connector: ' y ', last_word_connector: ' y ')}" : "las notas de su representado"
    horas = (User::ACTIVACION_VALIDA_POR / 1.hour).to_i

    Contacto.whatsapp_url(telefono, <<~TEXTO.strip)
      Buenos días. Le escribimos de #{Current.school.name}.

      Para consultar en SIGA #{de_quien}, abra este enlace:
      #{enlace}

      Sirve por #{horas} horas y una sola vez.
    TEXTO
  end
end
