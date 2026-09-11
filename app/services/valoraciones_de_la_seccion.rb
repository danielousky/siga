# Las valoraciones descriptivas de una sección de Educación Inicial.
#
# Daniel, 10 de septiembre de 2026: *«los niños en Inicial no sacan ni A, ni B,
# ni C, ni PC, ni AP, ni 5, ni 20, entonces la calificación es descriptiva»*.
#
#     ┌─ CALIFICAR · 1er Nivel U · 1er Lapso ─────────────────────┐
#     │  Bastidas Bermúdez, Valeria                               │
#     │    FORMACIÓN PERSONAL Y SOCIAL                            │
#     │    │Se integró al grupo con facilidad…│                   │
#     │    RELACIÓN CON EL AMBIENTE                               │
#     │    │escribe la valoración…│                               │
#     └───────────────────────────────────────────────────────────┘
#
# ## ⚠️ Por qué un servicio y no dos consultas en el controller
#
# Son tres áreas por niño y dieciséis niños: cuarenta y ocho casillas. Leerlas
# una por una son cuarenta y ocho consultas, y la pantalla es justamente la que
# la maestra abre para escribir las cuarenta y ocho. Acá se leen en DOS —las
# inscripciones y las valoraciones— y se cruzan en memoria.
#
# Es la misma forma de `LibretaDeLaSeccion`, que resuelve el mismo problema para
# la planilla de notas.
class ValoracionesDeLaSeccion
  # Una casilla: el niño, el área, y lo que haya escrito.
  Casilla = Data.define(:inscripcion, :area, :valoracion) do
    def texto = valoracion&.descripcion
    def escrita? = texto.present?

    # ⚠️ El id es de la CASILLA, no de la valoración: la fila puede no existir
    # todavía —es lo normal al abrir el lapso— y el campo necesita un nombre
    # igual. Sin esto no habría dónde escribir hasta que algo la creara.
    def id = "valoracion_#{inscripcion.id}_#{area.id}"
  end

  def self.para(seccion:, lapso:)
    new(seccion, lapso).armar
  end

  def initialize(seccion, lapso)
    @seccion = seccion
    @lapso = lapso
  end

  def armar
    { areas: areas, filas: filas, escritas: escritas, casillas: areas.size * inscripciones.size }
  end

  private

  attr_reader :seccion, :lapso

  # Las áreas del grado, que en Educación Inicial son las tres del currículo:
  # Formación Personal y Social · Relación con el Ambiente · Comunicación y
  # Representación. Salen del pensum, así que un colegio que las llame distinto
  # ve las suyas.
  def areas = @areas ||= seccion.grade.subjects.order(:name).to_a

  def inscripciones
    @inscripciones ||= Enrollment.en_orden_de_lista(seccion.enrollments)
  end

  def filas
    inscripciones.map do |inscripcion|
      { inscripcion: inscripcion,
        casillas: areas.map { |area| Casilla.new(inscripcion, area, escrita_en(inscripcion, area)) } }
    end
  end

  # ⚠️ UNA consulta para toda la pantalla, indexada por (inscripción, área).
  def escritas_por_casilla
    @escritas_por_casilla ||= MomentGrade
                              .where(enrollment_id: inscripciones.map(&:id), evaluation_moment_id: lapso&.id)
                              .index_by { |n| [ n.enrollment_id, n.subject_id ] }
  end

  def escrita_en(inscripcion, area) = escritas_por_casilla[[ inscripcion.id, area.id ]]

  # Cuántas casillas tienen algo escrito: es lo que la maestra quiere saber al
  # volver —«¿por dónde iba?»— y lo que dice si el lapso está listo.
  def escritas = escritas_por_casilla.values.count { |n| n.descripcion.present? }
end
