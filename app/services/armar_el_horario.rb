# Arma el horario de varias secciones a la vez, sin un choque (spec
# `horarios`). Lo usa la siembra de la muestra; el armado automático de un
# colegio —«Completar lo que falta»— es la tanda 5, con su propio spec.
#
#     ArmarElHorario.new(secciones, turno).armar!   # => clases ubicadas
#
# ## Cómo: colorear las aristas de un grafo
#
# Cada bloque de 80 minutos de un área es una arista entre su sección y su
# profesor; el color es la casilla de la semana. Que ni la sección ni el
# profesor repitan color es exactamente «una sección, una clase a la vez» y
# «un profesor, un sitio a la vez». En un grafo bipartito, con cadenas de Kempe
# siempre alcanzan tantos colores como el mayor número de bloques de una
# sección o de un profesor (König): si cabe, lo encuentra.
#
# Lo que no cabe —un profesor con más horas que la semana— se queda «por
# ubicar», y la pantalla lo dice. Da el mismo resultado con los mismos datos:
# la semilla es fija.
class ArmarElHorario
  def initialize(secciones, turno, semilla: 2026)
    @secciones = secciones
    @turno = turno
    @rng = Random.new(semilla)
    @rejilla = RejillaDeHorarios.new(turno)
  end

  def armar!
    colorear
    clases = 0
    Lesson.transaction do
      @color.each do |i, casilla|
        arista = @aristas[i]
        dia, horas = casilla
        horas.each do |hora|
          Lesson.create!(section: arista[:seccion], subject: arista[:materia], day: dia, time_slot: hora)
          clases += 1
        end
      end
    end
    clases
  end

  private

  # Las casillas de la semana: cada bloque de dos horas de cada día. El último
  # del viernes queda al final de la lista: si sobra una casilla, es esa —el
  # viernes se sale antes, como en la foto—.
  def casillas
    @casillas ||= begin
      bloques = @rejilla.horas.filter_map do |fila|
        pareja = @rejilla.pareja_de(fila.numero)
        [ fila.hora, @rejilla.horas[pareja].hora ] if pareja && pareja > fila.numero
      end
      todas = RejillaDeHorarios::DIAS.flat_map { |dia| bloques.map { |horas| [ dia, horas ] } }
      todas.partition { |dia, horas| dia == RejillaDeHorarios::DIAS.last && horas == bloques.last }.reverse.flatten(1)
    end
  end

  def aristas
    @aristas ||= @secciones.flat_map do |seccion|
      next [] if Lesson.where(section: seccion).exists?

      CargaDeLaSeccion.new(seccion).areas.flat_map do |area|
        profesor = area.profesor ? "p#{area.profesor.id}" : "nadie-#{seccion.id}-#{area.materia.id}"
        Array.new(area.horas.to_i / 2) { { seccion:, materia: area.materia, s: "s#{seccion.id}", t: profesor } }
      end
    end
  end

  def colorear
    @aristas = aristas
    @color = {}
    @en = Hash.new { |h, k| h[k] = {} }
    colores = (0...casillas.size).to_a
    carga = @aristas.map { |a| a[:t] }.tally

    @aristas.each_index.sort_by { |i| [ -carga[@aristas[i][:t]], @rng.rand ] }.each do |i|
      a = @aristas[i]
      libres_s = colores.reject { |c| @en[a[:s]].key?(c) }
      libres_t = colores.reject { |c| @en[a[:t]].key?(c) }
      next if libres_s.empty? || libres_t.empty? # no cabe: queda «por ubicar»

      ambos = libres_s & libres_t
      c = ambos.any? ? preferido(ambos, a) : cadena_de_kempe(a, preferido(libres_s, a), libres_t.first)
      pintar(i, c)
    end
    @color.transform_values! { |c| casillas[c] }
  end

  # Mejor un día en que la sección todavía no tiene esa área, y mejor no el
  # último bloque del viernes: si sobra una casilla, que sea esa.
  def preferido(colores, arista)
    dias = @en[arista[:s]].filter_map { |c, j| casillas[c].first if @aristas[j][:materia] == arista[:materia] }
    colores.min_by { |c| [ dias.include?(casillas[c].first) ? 1 : 0, c == casillas.size - 1 ? 1 : 0, @rng.rand ] }
  end

  # `a` está libre en la sección y `b` en el profesor: se intercambian `a` y `b`
  # a lo largo del camino que sale del profesor, y `a` queda libre en los dos.
  def cadena_de_kempe(arista, a, b)
    camino = []
    vertice = arista[:t]
    color = a
    loop do
      j = @en[vertice][color]
      break unless j

      camino << j
      vertice = vertice == @aristas[j][:t] ? @aristas[j][:s] : @aristas[j][:t]
      color = color == a ? b : a
    end
    camino.each { |j| despintar(j) }
    camino.each { |j| pintar(j, @color_previo[j] == a ? b : a) }
    a
  end

  def pintar(i, c)
    @color[i] = c
    @en[@aristas[i][:s]][c] = i
    @en[@aristas[i][:t]][c] = i
  end

  def despintar(j)
    (@color_previo ||= {})[j] = @color[j]
    @en[@aristas[j][:s]].delete(@color[j])
    @en[@aristas[j][:t]].delete(@color[j])
  end
end
