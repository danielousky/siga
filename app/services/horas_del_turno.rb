# El timbre de un turno, armado con cuatro números.
#
#     HorasDelTurno.new(entrada: "7:10", minutos_por_hora: 40, horas_al_dia: 8,
#                       receso_minutos: 30, receso_tras: 4).filas
#
#     1ra  7:10 – 7:50        5ta  10:20 – 11:00
#     2da  7:50 – 8:30        6ta  11:00 – 11:40
#     3ra  8:30 – 9:10        7ma  11:40 – 12:20
#     4ta  9:10 – 9:50        8va  12:20 –  1:00
#          Receso 9:50 – 10:20
#
# Ese ejemplo no es inventado: es el horario del cuaderno de un alumno que
# Daniel mandó el 13 de octubre de 2026, y es el «bloque de 80 minutos» de la
# Resolución DM-029/2022 —dos horas de 40 seguidas—.
#
# ## Por qué se GENERA y no se llena fila por fila
#
# Un colegio no piensa su timbre como nueve renglones: piensa «entramos a las
# 7:10, las horas son de 40, hay ocho y el receso es después de la cuarta».
# Pedirle los nueve es pedirle una cuenta que el sistema hace mejor, y la
# primera hora mal sumada corre a todas las demás.
#
# ⚠️ Es un PUNTO DE PARTIDA. Lo que sale son `TimeSlot` normales: después cada
# hora se corrige en su fila —un segundo receso, una última hora más corta—.
#
# ⚠️ Los errores van escritos a mano y completos (`errors.add(:base, …)`), no
# armados con el nombre del atributo: son cuatro números con un sentido muy
# concreto, y «Minutos por hora debe ser mayor que 20» no le dice a nadie qué
# escribir.
class HorasDelTurno
  include ActiveModel::Model
  include ActiveModel::Attributes

  HORAS_POSIBLES = (1..TimeSlot::ORDINALES.size)
  MINUTOS_POSIBLES = (20..120)
  RECESO_POSIBLE = (5..120)

  attribute :entrada, :string, default: "07:00"
  attribute :minutos_por_hora, :integer, default: 40
  attribute :horas_al_dia, :integer, default: 8
  attribute :receso_minutos, :integer, default: 30
  # Después de cuál hora va el receso. Cero es «sin receso».
  attribute :receso_tras, :integer, default: 4

  Fila = Data.define(:starts_min, :ends_min, :kind)

  validate :la_entrada_se_entiende
  validate :las_horas_tienen_sentido
  validate :el_receso_cae_entre_dos_horas
  validate :termina_el_mismo_dia

  def con_receso? = receso_tras.to_i.positive?

  # Las filas del timbre, en orden. Vacío si lo pedido no tiene sentido: quien
  # llama pregunta `valid?` primero y muestra los errores.
  def filas
    return [] unless valid?

    cursor = HoraDelDia.a_minutos(entrada)

    (1..horas_al_dia).flat_map do |numero|
      hora = Fila.new(starts_min: cursor, ends_min: cursor + minutos_por_hora, kind: "clase")
      cursor = hora.ends_min
      next [ hora ] unless con_receso? && numero == receso_tras

      receso = Fila.new(starts_min: cursor, ends_min: cursor + receso_minutos, kind: "receso")
      cursor = receso.ends_min
      [ hora, receso ]
    end
  end

  private

  def la_entrada_se_entiende
    return if HoraDelDia.a_minutos(entrada)

    errors.add(:base, "La hora de entrada no se entiende: escríbala como 7:10.")
  end

  def las_horas_tienen_sentido
    unless HORAS_POSIBLES.cover?(horas_al_dia)
      errors.add(:base, "Un turno tiene entre #{HORAS_POSIBLES.first} y #{HORAS_POSIBLES.last} horas al día.")
    end

    return if MINUTOS_POSIBLES.cover?(minutos_por_hora)

    errors.add(:base, "Cada hora dura entre #{MINUTOS_POSIBLES.first} y #{MINUTOS_POSIBLES.last} minutos.")
  end

  def el_receso_cae_entre_dos_horas
    return unless con_receso?

    unless RECESO_POSIBLE.cover?(receso_minutos)
      errors.add(:base, "El receso dura entre #{RECESO_POSIBLE.first} y #{RECESO_POSIBLE.last} minutos.")
    end

    # Después de la última hora ya no es un receso: es la salida.
    return if horas_al_dia.nil? || receso_tras < horas_al_dia

    errors.add(:base, "El receso va entre dos horas de clase: después de la última ya es la salida.")
  end

  def termina_el_mismo_dia
    return if errors.any?

    final = HoraDelDia.a_minutos(entrada) + (horas_al_dia * minutos_por_hora) +
            (con_receso? ? receso_minutos : 0)
    return if final < HoraDelDia::MINUTOS_DEL_DIA

    errors.add(:base, "Con esas horas el turno terminaría después de la medianoche.")
  end
end
