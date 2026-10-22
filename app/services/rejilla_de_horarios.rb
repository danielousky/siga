# La rejilla de una semana —los días en columnas, las horas en filas y el
# receso atravesado— para cualquier mirada (spec `horarios`, decisión 22):
#
#    DeLaSeccion   cada casilla dice el área y el profesor; al armar, si se puede
#    DelProfesor   la sección y el área
#    DelArea       las secciones que la tienen a esa hora, y con quién
#
# Las tres leen la MISMA tabla de clases, y cada una con UNA consulta: lo que
# cambia es qué se escribe en la casilla. Por eso dicen siempre lo mismo.
#
# Una clase de dos horas seguidas del mismo bloque se dibuja unida: es el
# bloque de 80 minutos de la Resolución DM-029.
class RejillaDeHorarios
  DIAS = (1..Lesson::DIAS.size).to_a.freeze

  # `numero` es la posición entre las horas de CLASE (0 = la 1ra); el receso no
  # tiene número.
  Fila = Data.define(:hora, :numero) do
    def receso? = numero.nil?
  end

  # `clave` decide qué casillas van unidas: dos horas del mismo bloque con la
  # misma clave son una sola clase de 80 minutos. Una casilla vacía no tiene.
  Celda = Data.define(:tipo, :clave, :datos) do
    def self.de(tipo, clave: nil, **datos) = new(tipo:, clave:, datos:)
  end

  attr_reader :turno, :filas

  def initialize(turno)
    @turno = turno
    numero = -1
    @filas = turno.time_slots.sort_by(&:starts_min).map do |hora|
      Fila.new(hora:, numero: hora.receso? ? nil : (numero += 1))
    end
  end

  def horas = @horas ||= filas.reject(&:receso?)
  def dias = DIAS

  def celda(dia, numero) = (@celdas ||= {})[[ dia, numero ]] ||= calcular_celda(dia, numero)

  # La otra hora del bloque: la 1ra con la 2da, la 3ra con la 4ta… contando
  # desde la entrada o desde el último receso. Un bloque no cruza el receso ni
  # el final del día, así que una hora suelta no tiene pareja.
  def pareja_de(numero) = parejas[numero]

  # Si esta casilla va unida con la siguiente: es la primera mitad de un bloque
  # cuyas dos horas tienen la misma clase.
  def unida?(dia, numero)
    pareja = pareja_de(numero)
    return false unless pareja && pareja > numero

    clave = celda(dia, numero).clave
    !clave.nil? && clave == celda(dia, pareja).clave
  end

  # La segunda mitad de un bloque unido: no se dibuja, la cubre la primera.
  def tapada?(dia, numero)
    pareja = pareja_de(numero)
    !pareja.nil? && pareja < numero && unida?(dia, pareja)
  end

  # La fila que suena ahora, o nil (antes de entrar, después de salir).
  def fila_de(minutos) = filas.find { |fila| fila.hora.starts_min <= minutos && minutos < fila.hora.ends_min }

  private

  def parejas
    @parejas ||= begin
      parejas = {}
      tramo = []
      cerrar = lambda do
        tramo.each_slice(2) { |a, b| (parejas[a] = b) && (parejas[b] = a) if b }
        tramo = []
      end
      filas.each { |fila| fila.receso? ? cerrar.call : tramo << fila.numero }
      cerrar.call
      parejas
    end
  end

  def hora_de(numero) = horas[numero].hora

  # Las clases de esta rejilla, por casilla. Solo un turno guardado tiene
  # clases: el de la foto sin guardar se dibuja vacío.
  def por_casilla(clases)
    return {} unless turno.persisted?

    clases.index_by { |clase| [ clase.day, clase.time_slot_id ] }
  end

  # ── Las miradas ──────────────────────────────────────────────────────────

  class DeLaSeccion < RejillaDeHorarios
    attr_reader :seccion, :carga, :elegida, :profesor

    # `elegida` es el área que se está ubicando (su `subject_id`), y `marcada`
    # la casilla rayada que se acaba de tocar: el mensaje habla de ella.
    def initialize(seccion, turno, armando: false, elegida: nil, marcada: nil, solo_publicada: false)
      super(turno)
      @seccion = seccion
      @armando = armando
      @marcada = marcada
      @visible = !solo_publicada || seccion.timetable_published_at.present?
      @clases = @visible ? por_casilla(Lesson.where(section: seccion).includes(:subject, teacher: :user)) : {}
      @carga = CargaDeLaSeccion.new(seccion)
      @elegida = armando && elegida.present? ? @carga.de(elegida) : nil
      @profesor = @elegida&.profesor
    end

    def armando? = @armando
    def visible? = @visible

    # Dónde dicta el profesor del área elegida, en las OTRAS secciones del año:
    # una sola consulta para toda la rejilla.
    def ocupaciones
      return @ocupaciones if defined?(@ocupaciones)

      @ocupaciones = []
      return @ocupaciones unless @profesor

      @ocupaciones = Lesson.where(teacher_id: @profesor.id, academic_period_id: seccion.academic_period_id)
                           .where.not(section_id: seccion.id).includes(:subject, section: :grade).to_a
    end

    private

    def calcular_celda(dia, numero)
      hora = hora_de(numero)
      if (clase = @clases[[ dia, hora.id ]])
        return Celda.de(:clase, clave: [ :clase, clase.subject_id ], clase:, elegida: clase.subject_id == @elegida&.materia&.id)
      end
      return Celda.de(:vacia) unless @armando
      return Celda.de(:libre_sin_area) if @elegida.nil?

      if (otra = ocupaciones.find { |c| c.day == dia && c.starts_min < hora.ends_min && c.ends_min > hora.starts_min })
        return Celda.de(:bloqueada, otra:, profesor: @profesor, marcada: @marcada == [ dia, numero ])
      end
      return Celda.de(:libre_sin_area) if @elegida.sin_horas? || @elegida.completa?

      Celda.de(:libre, hora:, area: @elegida)
    end
  end

  class DelProfesor < RejillaDeHorarios
    def initialize(profesor, turno, anio, solo_publicadas: false)
      super(turno)
      clases = Lesson.where(teacher: profesor, academic_period: anio).includes(:subject, section: :grade)
      clases = clases.joins(:section).where.not(sections: { timetable_published_at: nil }) if solo_publicadas
      @clases = por_casilla(clases)
    end

    private

    def calcular_celda(dia, numero)
      clase = @clases[[ dia, hora_de(numero).id ]]
      return Celda.de(:libre_del_profesor) unless clase

      Celda.de(:del_profesor, clave: [ :clase, clase.section_id, clase.subject_id ], clase:)
    end
  end

  # Un día de todo el colegio —«Todas, un mismo día» y «Todos, un mismo
  # día»—: un renglón por sección o por profesor, una casilla por hora, y el
  # bloque de 80 minutos unido, ahora de lado. Las clases llegan ya agrupadas,
  # de UNA consulta.
  class DelDia < RejillaDeHorarios
    Renglon = Data.define(:de, :casillas, :horas)
    Casilla = Data.define(:clase, :ancho, :receso) do
      def receso? = receso
    end

    attr_reader :renglones

    def initialize(turno, quienes, &clases_de)
      super(turno)
      @renglones = quienes.map { |quien| renglon(quien, clases_de.call(quien)) }
    end

    private

    def renglon(quien, clases)
      por_hora = clases.index_by(&:time_slot_id)
      casillas = []
      tapada = false
      filas.each do |fila|
        if fila.receso?
          casillas << Casilla.new(clase: nil, ancho: 1, receso: true)
        elsif tapada
          tapada = false
        else
          clase = por_hora[fila.hora.id]
          pareja = pareja_de(fila.numero)
          otra = por_hora[horas[pareja].hora.id] if pareja && pareja > fila.numero
          tapada = !clase.nil? && !otra.nil? && [ clase.section_id, clase.subject_id ] == [ otra.section_id, otra.subject_id ]
          casillas << Casilla.new(clase:, ancho: tapada ? 2 : 1, receso: false)
        end
      end
      Renglon.new(de: quien, casillas:, horas: clases.size)
    end
  end

  class DelArea < RejillaDeHorarios
    def initialize(materia, turno, anio)
      super(turno)
      @clases = {}
      return unless turno.persisted?

      @clases = Lesson.where(subject: materia, academic_period: anio).includes(teacher: :user, section: :grade)
                      .group_by { |clase| [ clase.day, clase.time_slot_id ] }
    end

    private

    def calcular_celda(dia, numero)
      clases = @clases[[ dia, hora_de(numero).id ]]
      return Celda.de(:vacia) if clases.blank?

      clases = clases.sort_by { |c| [ c.section.grade.orden || 99, c.section.name ] }
      Celda.de(:del_area, clave: [ :area, clases.map(&:section_id) ], clases:)
    end
  end
end
