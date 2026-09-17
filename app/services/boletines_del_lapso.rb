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

  private

  def inscripciones
    @inscripciones ||= Enrollment.where(section_id: @seccion.id)
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
