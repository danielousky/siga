# La hora del colegio, no la del servidor (spec `horarios`, § 7).
#
# La app corre en UTC: desde las 8 de la noche de Caracas, «hoy» ya sería
# mañana, y el «Ahora» del profesor diría la clase equivocada. Todo lo que el
# horario dice de HOY y de AHORA sale de aquí, nunca de `Date.current`.
module HoraDeVenezuela
  ZONA = "America/Caracas"

  module_function

  def ahora = Time.current.in_time_zone(ZONA)

  # 1 = lunes … 5 = viernes. El sábado y el domingo abren en el lunes: es el
  # próximo día con clases, y una pantalla vacía no le sirve a nadie.
  def dia_de_clases(momento = ahora) = momento.wday.between?(1, 5) ? momento.wday : 1

  def dia_habil?(momento = ahora) = momento.wday.between?(1, 5)

  def minutos(momento = ahora) = momento.hour * 60 + momento.min
end
