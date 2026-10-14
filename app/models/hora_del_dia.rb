# Una hora del día, guardada en MINUTOS desde la medianoche.
#
#     HoraDelDia.a_minutos("7:10")    # => 430
#     HoraDelDia.texto(430)           # => "7:10"
#     HoraDelDia.texto(780)           # => "1:00"         el reloj de 12, como lo escribe un colegio
#     HoraDelDia.con_meridiano(780)   # => "1:00 p. m."
#     HoraDelDia.del_campo(430)       # => "07:10"        lo que espera un <input type="time">
#     HoraDelDia.rango(430, 470)      # => "7:10 – 7:50"
#
# ⚠️ No es un `Time`, a propósito. La app corre en UTC y Venezuela está cuatro
# horas atrás: una hora de Ruby arrastra una fecha y una zona que acá no
# existen —«la 1ra hora es a las 7:10» no es de ningún día— y cada conversión es
# una oportunidad de que las siete de la mañana se lean como las once.
module HoraDelDia
  module_function

  MINUTOS_DEL_DIA = 24 * 60
  MEDIODIA = 12 * 60

  # `nil` si no se entiende: quien llama decide qué decirle a la persona.
  def a_minutos(valor)
    return valor if valor.is_a?(Integer)

    partes = valor.to_s.strip.match(/\A(\d{1,2}):(\d{2})\z/)
    return nil unless partes

    horas = partes[1].to_i
    minutos = partes[2].to_i
    return nil if horas > 23 || minutos > 59

    horas * 60 + minutos
  end

  def texto(minutos)
    return nil if minutos.nil?

    horas, resto = (minutos % MINUTOS_DEL_DIA).divmod(60)
    en_doce = horas % 12
    en_doce = 12 if en_doce.zero?

    format("%d:%02d", en_doce, resto)
  end

  # Para donde la mañana y la tarde se pueden confundir: el resumen de un turno.
  # En la rejilla no hace falta —nadie duda de que la 1ra hora es de mañana— y
  # ocho «a. m.» seguidos son ruido.
  def con_meridiano(minutos)
    return nil if minutos.nil?

    "#{texto(minutos)} #{minutos % MINUTOS_DEL_DIA < MEDIODIA ? 'a. m.' : 'p. m.'}"
  end

  def del_campo(minutos)
    return nil if minutos.nil?

    format("%02d:%02d", *(minutos % MINUTOS_DEL_DIA).divmod(60))
  end

  def rango(desde, hasta) = "#{texto(desde)} – #{texto(hasta)}"
end
