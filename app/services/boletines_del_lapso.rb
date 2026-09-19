# Los boletines de una sección en un lapso, con lo que hace falta para revisarlos.
#
# Daniel: *«las boletas deberán pasar por una revisión por parte de Admin antes
# de ser mostradas al representante… debería poder ver una por una y cuando
# considere que todo está OK, liberar con un solo clic»*.
#
#     BoletinesDelLapso.de(seccion, lapso).fichas
#     #=> [#<Ficha alumno: …, boletin: …, completo?: true, liberado?: false>, …]
class BoletinesDelLapso
  # Lo que la pantalla necesita saber de cada alumno, junto.
  Ficha = Data.define(:inscripcion, :boletin, :con_nota, :materias) do
    def alumno = inscripcion.student.user

    # ⚠️ «Completo» es tener nota en TODAS sus materias, no un porcentaje.
    #
    # Un boletín al 90 % no es un boletín casi listo: es uno que va a salir con
    # una materia en blanco, y la familia va a preguntar por esa.
    def completo? = materias.positive? && con_nota >= materias

    def emitido? = boletin.present?
    def liberado? = boletin&.liberado? || false
    def faltan = [ materias - con_nota, 0 ].max
  end

  def self.de(seccion, lapso) = new(seccion, lapso)

  def initialize(seccion, lapso)
    @seccion = seccion
    @lapso = lapso
  end

  def fichas
    @fichas ||= inscripciones.map do |inscripcion|
      Ficha.new(inscripcion: inscripcion,
                boletin: boletines[inscripcion.id],
                con_nota: con_nota[inscripcion.id].to_i,
                materias: materias_del_grado)
    end
  end

  def completos   = fichas.select(&:completo?)
  def incompletos = fichas.reject(&:completo?)
  def emitidos    = fichas.select(&:emitido?)
  def liberados   = fichas.select(&:liberado?)

  def todo_liberado? = emitidos.any? && emitidos.all?(&:liberado?)
  def hay_para_liberar? = emitidos.any? { |f| !f.liberado? }

  # ── En qué estado está el lapso de esta sección ──────────────────────────
  #
  # Daniel: *«por defecto está en "Por calificar"; cuando el profe califica pasa
  # a calificada, y cuando CE corrobora pasa a "Cerrada"»*.
  #
  # ⚠️ Los dos primeros se DEDUCEN de las notas y el tercero se guarda. Guardar
  # los tres sería un segundo lugar donde vive la misma verdad: el día que
  # entre la nota que faltaba, la columna seguiría diciendo «por calificar».
  ESTADOS = {
    por_calificar: "Por calificar",
    calificada:    "Calificada",
    cerrada:       "Cerrada"
  }.freeze

  def estado
    return :cerrada if cerrada?
    return :calificada if fichas.any? && incompletos.empty?

    :por_calificar
  end

  def nombre_del_estado = ESTADOS.fetch(estado)

  def cierre
    return @cierre if defined?(@cierre)

    @cierre = SectionClosure.find_by(section_id: @seccion.id, evaluation_moment_id: @lapso.id)
  end

  def cerrada? = cierre.present?

  # ⚠️ Se cierra con las notas COMPLETAS y el informe de cada alumno escrito.
  #
  # Dos cambios de criterio, los dos de Daniel:
  #
  #   1 · Liberar dejaba salir lo emitido aunque faltaran notas en otros, para
  #       no perseguir a un profesor. *«Admin debe validar que TODAS las boletas
  #       están completas»*: cerrar no es entregar veinte boletines, es declarar
  #       terminado el lapso, y uno con una materia en blanco no lo está.
  #
  #   2 · El informe descriptivo era un aviso. *«Sí, el informe debe ser
  #       obligatorio para cerrar»* (19 de septiembre). Una boleta sin una línea
  #       del docente es una factura: el «PA» dice en qué banda cayó el niño, y
  #       el informe dice que lee mejor que en octubre.
  def se_puede_cerrar? = estado == :calificada && sin_informe.empty?

  # Los alumnos que NO tienen todavía su informe descriptivo.
  #
  # ⚠️ IMPIDE cerrar, no solo avisa — cambió el 19 de septiembre. El informe
  # sigue siendo opcional en el MODELO: un lapso a medias tiene alumnos sin
  # informe y eso no es un error. Lo que no se puede es dar por TERMINADO el
  # lapso mientras falte uno.
  def sin_informe
    @sin_informe ||= begin
      escritos = Informe.where(enrollment_id: fichas.map { |f| f.inscripcion.id },
                               evaluation_moment_id: @lapso.id)
                        .where.not(cuerpo: [ nil, "" ]).pluck(:enrollment_id).to_set
      fichas.reject { |f| escritos.include?(f.inscripcion.id) }
    end
  end

  private

  # ⚠️ Solo los REGULARES, y eso es lo que hace que un lapso se pueda cerrar.
  #
  # Un alumno retirado en octubre no tiene notas de diciembre y nunca las va a
  # tener: contándolo, la sección se quedaba en «por calificar» para siempre y
  # el visto bueno de Control de Estudio no llegaba nunca. Tampoco se le emite
  # boletín —`ReportCardsController` ya filtra por `regular`— así que contarlo
  # acá era, además, contar algo que no se iba a imprimir.
  def inscripciones
    @inscripciones ||= Enrollment.where(section_id: @seccion.id, status: :regular)
                                 .includes(student: :user)
                                 .then { |scope| Enrollment.en_orden_de_lista(scope) }
  end

  # ⚠️ Una consulta para todos, no una por alumno: una sección son treinta.
  def boletines
    @boletines ||= ReportCard.where(enrollment_id: inscripciones.map(&:id),
                                    evaluation_moment_id: @lapso.id)
                             .recientes.index_by(&:enrollment_id)
  end

  # Cuántas materias tienen ya su nota de lapso.
  #
  # ⚠️ Se cuenta sobre `MomentGrade` —la nota YA CALCULADA del lapso— y no sobre
  # las evaluaciones: un profesor puede tener el 100 % de sus notas cargadas y
  # la del lapso sin recalcular todavía. Lo que decide si el boletín está
  # completo es lo que el boletín va a imprimir.
  def con_nota
    @con_nota ||= MomentGrade.where(enrollment_id: inscripciones.map(&:id),
                                    evaluation_moment_id: @lapso.id)
                             .where.not(final_moment_score: nil)
                             .group(:enrollment_id).count
  end

  def materias_del_grado
    @materias_del_grado ||= @seccion.grade.subjects.count
  end
end
