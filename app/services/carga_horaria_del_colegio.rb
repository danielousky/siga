# La matriz de la carga horaria: una tabla por nivel, una fila por área, una
# columna por grado, y en cada casilla cuántas horas a la semana lleva esa área
# en ese grado.
#
#     EDUCACIÓN MEDIA GENERAL     1er Año  2do Año  3er Año  4to Año  5to Año
#     Castellano                     4        4        4        4        4
#     Ciencias Naturales             6        6        ·        ·        ·
#     Total                         44       44       46       46       46
#     La semana tiene               40       40       40       40       40
#
# Es el mismo dibujo que el mapa de evaluaciones (`MapaDeEvaluaciones`): el
# colegio entero en una pantalla, y lo que no cierra se ve porque rompe el patrón.
#
# ⚠️ El punto dice «esa área no se cursa en ese grado» —no hay renglón de
# pensum—, y es distinto de una casilla vacía, que es «se cursa y nadie dijo
# cuántas horas».
#
# ⚠️ Educación Inicial no entra: no se organiza en horas por área (decisión 14
# del spec `horarios`).
class CargaHorariaDelColegio
  Grupo = Data.define(:nivel, :grados, :areas, :casillas) do
    def casilla(area, grado) = casillas[[ area.id, grado.id ]]
  end

  def initialize(grados:, anio:)
    @grados = grados.where.not(level: :preescolar).en_orden.to_a
    @anio = anio
  end

  def grupos
    @grupos ||= @grados.group_by { |grado| grado.level.to_sym }
                       .sort_by { |nivel, _| GradoOficial::NIVELES.index(nivel) || 99 }
                       .map { |nivel, grados| grupo(nivel, grados) }
                       .reject { |grupo| grupo.areas.empty? }
  end

  def vacio? = grupos.empty?

  # Las horas que ya tiene escritas un grado, sumadas.
  def total_de(grado)
    renglones.select { |renglon| renglon.grade_id == grado.id }.sum { |renglon| renglon.weekly_hours.to_i }
  end

  # Cuántas horas de clase caben en la semana del grado: las de su turno.
  #
  # ⚠️ Si sus secciones tienen turnos distintos, el MÁS CORTO: es el que primero
  # se queda sin espacio. `nil` si ninguna sección del año tiene turno todavía —
  # y entonces no hay contra qué comparar, que no es lo mismo que «cabe»—.
  def semana_de(grado)
    turnos_por_grado[grado.id]&.map(&:horas_a_la_semana)&.min
  end

  # Cuántas horas sobran, o `nil` si caben (o si todavía no se sabe).
  def sobran_en(grado)
    semana = semana_de(grado)
    return nil if semana.nil?

    exceso = total_de(grado) - semana
    exceso if exceso.positive?
  end

  private

  def grupo(nivel, grados)
    ids = grados.map(&:id)
    suyos = renglones.select { |renglon| ids.include?(renglon.grade_id) }
    areas = suyos.map(&:subject).uniq.sort_by { |area| Normaliza.limpiar(area.name) }

    Grupo.new(nivel: nivel, grados: grados, areas: areas,
              casillas: suyos.index_by { |renglon| [ renglon.subject_id, renglon.grade_id ] })
  end

  def renglones
    @renglones ||= GradeSubject.where(grade_id: @grados.map(&:id)).includes(:subject).to_a
  end

  def turnos_por_grado
    @turnos_por_grado ||= begin
      secciones = @anio ? Section.where(academic_period: @anio, grade_id: @grados.map(&:id))
                                 .where.not(bell_schedule_id: nil)
                                 .includes(bell_schedule: :time_slots) : Section.none

      secciones.group_by(&:grade_id).transform_values { |suyas| suyas.map(&:bell_schedule).uniq }
    end
  end
end
