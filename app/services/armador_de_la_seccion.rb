# Lo que pasa al tocar una casilla en «Armar», y el mensaje que lo cuenta
# (spec `horarios`, decisiones 23 y 24).
#
#     armador = ArmadorDeLaSeccion.new(seccion)
#     armador.ubicar(materia, dia: 4, hora:, en_bloques: true)
#     # => Mensaje «Listo: Inglés el jueves de 10:20 a 11:40. Van 4 de 4. Sigue Arte (0 de 2).»
#     armador.quitar(clase)
#
# El mensaje tiene tipo —«ok» lo que quedó guardado, «aviso» por qué no se
# pudo— y el área que sigue elegida después.
#
# ## ⚠️ Cada clase se guarda en su `SAVEPOINT`
#
# Si dos personas llenan la misma casilla a la vez, la segunda choca con el
# `EXCLUDE` de la base, y una restricción violada ABORTA la transacción —que en
# SIGA es la petición entera—. En su SAVEPOINT, el choque se vuelve un mensaje
# en vez de un error 500.
class ArmadorDeLaSeccion
  Mensaje = Data.define(:texto, :tipo, :area)

  def initialize(seccion)
    @seccion = seccion
  end

  def ubicar(materia, dia:, hora:, en_bloques:)
    area = carga.de(materia)
    return aviso("#{materia.name} no es un área de #{nombre}.", nil) unless area
    return aviso("#{materia.name} todavía no tiene horas a la semana: súbalas con +.", materia) if area.sin_horas?
    if area.completa?
      return aviso("#{materia.name} ya tiene sus #{area.horas} horas. Para ponerle otra, súbale la carga con +.", materia)
    end

    primera = guardar(materia, dia, hora)
    return aviso(primera, materia) if primera.is_a?(String)

    puestas = [ primera ]
    nota = nil
    if en_bloques && area.faltan >= 2 && (pareja = pareja_de(hora))
      segunda = guardar(materia, dia, pareja)
      segunda.is_a?(String) ? nota = " Solo cupo una hora. #{segunda}" : puestas << segunda
    end

    contar_de_nuevo
    area = carga.de(materia)
    desde, hasta = puestas.map(&:starts_min).min, puestas.map(&:ends_min).max
    texto = "Listo: #{materia.name} el #{Lesson::DIAS[dia - 1].downcase} de #{HoraDelDia.texto(desde)} a " \
            "#{HoraDelDia.texto(hasta)}. Van #{area.ubicadas} de #{area.horas}.#{nota}"
    sigue = materia
    if area.completa?
      siguiente = carga.primera_pendiente
      sigue = siguiente&.materia
      texto += siguiente ? " Sigue #{siguiente.materia.name} (#{siguiente.ubicadas} de #{siguiente.horas})." : " #{nombre} quedó completa."
    end
    Mensaje.new(texto:, tipo: nota ? "aviso" : "ok", area: sigue)
  end

  # Quita la clase entera: las dos horas de su bloque, si van juntas.
  def quitar(clase)
    pareja = pareja_de(clase.time_slot)
    otra = pareja && Lesson.find_by(section: @seccion, day: clase.day, time_slot: pareja, subject_id: clase.subject_id)
    fuera = [ clase, otra ].compact.sort_by(&:starts_min)
    Lesson.where(id: fuera.map(&:id)).delete_all

    contar_de_nuevo
    area = carga.de(clase.subject)
    texto = "Se quitó #{clase.subject.name} del #{clase.dia.downcase} " \
            "(#{HoraDelDia.rango(fuera.first.starts_min, fuera.last.ends_min)}). " \
            "Vuelve a «Por ubicar»: #{area&.ubicadas.to_i} de #{area&.horas.to_i}."
    Mensaje.new(texto:, tipo: "ok", area: clase.subject)
  end

  private

  def nombre = "#{@seccion.grade.name} #{@seccion.name}"
  def carga = @carga ||= CargaDeLaSeccion.new(@seccion)
  def contar_de_nuevo = @carga = nil
  def aviso(texto, area) = Mensaje.new(texto:, tipo: "aviso", area:)

  def rejilla = @rejilla ||= RejillaDeHorarios.new(@seccion.bell_schedule)

  def pareja_de(hora)
    fila = rejilla.horas.find { |f| f.hora.id == hora.id }
    numero = fila && rejilla.pareja_de(fila.numero)
    numero && rejilla.horas[numero].hora
  end

  # La clase guardada, o el porqué de que no se pudo (un texto).
  def guardar(materia, dia, hora)
    clase = Lesson.new(section: @seccion, subject: materia, day: dia, time_slot: hora)
    return clase if Lesson.transaction(requires_new: true) { clase.save }

    clase.errors.full_messages.to_sentence
  rescue ActiveRecord::ExclusionViolation
    "#{Lesson::DIAS[dia - 1]} a las #{HoraDelDia.texto(hora.starts_min)}: alguien acaba de llenar esa casilla."
  end
end
