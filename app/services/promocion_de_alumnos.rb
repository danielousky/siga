# Quién pasa de grado, quién repite y quién egresa (MOR-169).
#
# ## Por qué es la otra mitad de la clonación
#
# `CopiarLaEstructura` arma el año nuevo —las secciones y quién dicta qué— y lo
# deja vacío. Esto lo llena. Daniel: *«debería ser una función muy ligada a la
# clonación, es casi automática»*.
#
#     1. Crear 2026-2027         →  nace con sus tres lapsos
#     2. Copiar la estructura    →  secciones + quién dicta qué
#     3. Promover a los alumnos  →  los inscribe en las secciones nuevas
#
# ## ⚠️ NO decide nada solo: propone y alguien confirma
#
# Es la misma decisión del importador: se muestra la cuenta —«181 pasan, 18
# repiten, 1 egresa»— y nada se escribe hasta que el director acepta. Promover a
# trescientos sesenta alumnos al grado equivocado no se deshace con un botón.
#
# ## Las cinco situaciones
#
#     PROMUEVE   aprobó todo, o arrastra dentro del tope   → el grado siguiente
#     REPITE     arrastra más que el tope                  → el mismo grado
#     EGRESA     el grado siguiente no lo dicta el colegio → no se inscribe
#     SIN DATOS  no tiene notas definitivas cargadas       → lo decide el director
#     RETIRADO   su inscripción no es `regular`            → no se toca
#
# ⚠️ **SIN DATOS es el caso NORMAL de un cliente nuevo**, no un error. Un colegio
# en su primer año con SIGA tiene las notas del año anterior en su sistema viejo
# o en papel. Si el diseño asumiera que siempre hay notas, la función no serviría
# para el único momento en que hace falta. Por eso `promover_igual:` existe: el
# director asume la decisión y SIGA la registra como suya.
#
# ## El grado siguiente sale del catálogo, sin casos especiales
#
# `GradoOficial::CATALOGO` tiene los quince grados en orden: «6to Grado» (9) va a
# «1er Año» (10) porque están uno detrás del otro. Y **egresar es simplemente que
# ese grado siguiente no está entre los del colegio** — un colegio de solo
# primaria egresa en 6to Grado sin que nadie lo configure.
class PromocionDeAlumnos
  SITUACIONES = %i[promueve repite egresa sin_datos].freeze

  # Una fila de la propuesta. `destino` es la sección donde quedaría, o nil.
  Propuesta = Data.define(:inscripcion, :situacion, :aplazadas, :destino, :grado_destino) do
    def alumno = inscripcion.student
    def seccion_actual = inscripcion.section
    def se_inscribe? = destino.present?
    def sin_seccion? = %i[promueve repite].include?(situacion) && destino.nil?
  end

  Resultado = Data.define(:inscritos, :egresados, :salteados, :avisos) do
    def hizo_algo? = inscritos.positive? || egresados.positive?
  end

  def initialize(origen, destino, promover_sin_datos: false)
    @origen = origen
    @destino = destino
    @promover_sin_datos = promover_sin_datos
  end

  def self.propuesta_de(origen, al:, promover_sin_datos: false)
    new(origen, al, promover_sin_datos: promover_sin_datos).propuesta
  end

  def self.aplicar(origen, al:, promover_sin_datos: false)
    new(origen, al, promover_sin_datos: promover_sin_datos).aplicar
  end

  # ¿Hay con qué decidir? Es lo primero que la pantalla pregunta: sin notas
  # definitivas no hay propuesta que hacer, hay una decisión que pedir.
  def self.hay_notas?(origen)
    FinalGradeBook.where(enrollment_id: Enrollment.where(section: Section.where(academic_period_id: origen.id)).select(:id))
                  .exists?
  end

  def propuesta
    @propuesta ||= inscripciones.map { |inscripcion| proponer(inscripcion) }
  end

  # Cuántos hay de cada situación, que es lo que se muestra antes de confirmar.
  def conteo
    propuesta.group_by(&:situacion).transform_values(&:size)
  end

  def aplicar
    inscritos, egresados, salteados, avisos = 0, 0, 0, []

    # ⚠️ Una transacción sola. Media promoción es peor que ninguna: el director
    # cree que ya está y descubre en octubre que faltan cuatro secciones.
    ActiveRecord::Base.transaction do
      propuesta.each do |fila|
        case fila.situacion
        when :egresa then egresados += 1
        when :sin_datos then (salteados += 1 unless @promover_sin_datos)
        end

        next unless fila.se_inscribe?

        if inscribir(fila)
          inscritos += 1
        else
          salteados += 1
          avisos << "#{fila.alumno.user.apellidos_y_nombres}: ya estaba inscrito en #{@destino.name}"
        end
      end
    end

    Resultado.new(inscritos: inscritos, egresados: egresados, salteados: salteados, avisos: avisos)
  end

  private

  attr_reader :origen, :destino

  # Solo los REGULARES: un alumno retirado se fue del colegio, y volver a
  # inscribirlo lo resucita en una lista donde no debería estar.
  def inscripciones
    @inscripciones ||=
      Enrollment.where(section: Section.where(academic_period_id: origen.id), status: :regular)
                .includes(:student, student: :user, section: :grade)
                .to_a
                .sort_by { |i| [ i.section.grade.orden.to_i, i.section.name, i.student.user.apellidos_y_nombres ] }
  end

  def proponer(inscripcion)
    aplazadas = aplazadas_de(inscripcion)
    situacion = decidir(inscripcion, aplazadas)
    grado = grado_de_destino(inscripcion, situacion)

    Propuesta.new(inscripcion: inscripcion, situacion: situacion, aplazadas: aplazadas,
                  destino: (seccion_de_destino(inscripcion, grado) if grado),
                  grado_destino: grado)
  end

  def decidir(inscripcion, aplazadas)
    return :sin_datos if libros_por_inscripcion[inscripcion.id].nil?
    # Egresar gana sobre repetir: quien está en el último grado del colegio y
    # aprobó, se va — no hay grado siguiente en el que ponerlo.
    return :egresa if aplazadas.size <= tope && siguiente_oficial(inscripcion).nil?
    return :promueve if aplazadas.size <= tope

    :repite
  end

  # ⚠️ Las materias que arrastra, por NOMBRE, no la cuenta: la pantalla las
  # muestra («Mat · Fís») y eso es lo que le permite al director discutir el
  # caso con el profesor antes de confirmar.
  def aplazadas_de(inscripcion)
    (libros_por_inscripcion[inscripcion.id] || []).select(&:aplazado?).map { |l| l.subject.name }.sort
  end

  # Una sola consulta para toda la promoción: pedirlo por alumno serían
  # trescientas sesenta.
  def libros_por_inscripcion
    @libros_por_inscripcion ||=
      FinalGradeBook.where(enrollment_id: inscripciones.map(&:id))
                    .includes(:subject)
                    .group_by(&:enrollment_id)
  end

  def tope = @tope ||= (origen.school || Current.school)&.tope_de_arrastre.to_i

  # El grado que sigue en el catálogo oficial, SI el colegio lo dicta. Nil si no
  # —y eso es exactamente «egresa».
  def siguiente_oficial(inscripcion)
    actual = inscripcion.section.grade
    return nil if actual.orden.nil?

    grados_del_colegio[actual.orden + 1]
  end

  def grado_de_destino(inscripcion, situacion)
    case situacion
    when :promueve then siguiente_oficial(inscripcion)
    when :repite   then inscripcion.section.grade
    # Sin datos: se propone el siguiente, pero solo se aplica si el director lo
    # pide explícitamente. Si está en el último grado, no hay a dónde.
    when :sin_datos then (siguiente_oficial(inscripcion) if @promover_sin_datos)
    end
  end

  def grados_del_colegio
    @grados_del_colegio ||= Grade.where(school_id: origen.school_id).index_by(&:orden)
  end

  # La sección de la MISMA letra si existe —«1er Año A» va a «2do Año A»— y si
  # no, la primera del grado. Un colegio que pasa de tres secciones a dos no
  # puede quedar con alumnos sin ubicar.
  def seccion_de_destino(inscripcion, grado)
    del_grado = secciones_del_destino[grado.id]
    return nil if del_grado.blank?

    del_grado.find { |s| s.name == inscripcion.section.name } || del_grado.first
  end

  def secciones_del_destino
    @secciones_del_destino ||= Section.where(academic_period_id: destino.id)
                                      .order(:name).group_by(&:grade_id)
  end

  # ⚠️ `find_or_create`: promover dos veces no duplica inscripciones. El índice
  # único de `enrollments` lo impediría igual, pero con un error que no explica
  # nada — acá se cuenta como «ya estaba» y se sigue.
  def inscribir(fila)
    return false if Enrollment.exists?(student_id: fila.alumno.id, section_id: fila.destino.id)

    Enrollment.create!(student_id: fila.alumno.id, section: fila.destino,
                       enrollment_date: Date.current, status: :regular)
    true
  end
end
