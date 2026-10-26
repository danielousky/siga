# «Ahora» y «Después» en el inicio del profesor (spec `horarios`): qué clase
# tiene en este momento y cuál le sigue, con la hora de Venezuela.
#
#     momento = MomentoDelProfesor.new(clases)
#     momento.ahora    # => Bloque(1er Año A, Matemática, 8:30 → 9:50), o nil
#     momento.despues  # => el siguiente bloque de HOY, o nil
#
# Dos horas seguidas de la misma clase son un bloque de 80 minutos: «hasta las
# 9:50», no «hasta las 9:10». Seguidas quiere decir pegadas: el receso parte.
class MomentoDelProfesor
  Bloque = Data.define(:seccion, :materia, :desde, :hasta)

  attr_reader :ahora, :despues, :minutos

  def initialize(clases, momento = HoraDeVenezuela.ahora)
    @habil = HoraDeVenezuela.dia_habil?(momento)
    @minutos = HoraDeVenezuela.minutos(momento)
    @bloques = @habil ? bloques_de(clases.select { |clase| clase.day == momento.wday }) : []
    @ahora = @bloques.find { |b| b.desde <= @minutos && @minutos < b.hasta }
    @despues = @bloques.find { |b| b.desde >= (@ahora&.hasta || @minutos) }
  end

  def habil? = @habil
  def clases_hoy? = @bloques.any?
  def terminado? = clases_hoy? && @bloques.last.hasta <= @minutos
  def antes_de_empezar? = clases_hoy? && @minutos < @bloques.first.desde

  private

  def bloques_de(clases)
    clases.sort_by(&:starts_min).each_with_object([]) do |clase, bloques|
      ultimo = bloques.last
      if ultimo && ultimo.seccion == clase.section && ultimo.materia == clase.subject && ultimo.hasta == clase.starts_min
        bloques[-1] = ultimo.with(hasta: clase.ends_min)
      else
        bloques << Bloque.new(seccion: clase.section, materia: clase.subject, desde: clase.starts_min, hasta: clase.ends_min)
      end
    end
  end
end
