# El mapa de los planes de evaluación del colegio, en UN lapso: una tabla por
# nivel, una fila por sección y una casilla por área.
#
#     EDUCACIÓN PRIMARIA   CNA  CSO  EDF  EST  ING  LEN  MAT
#     1er Grado A           ✓    ✓   70   70    ✓    ✓    ✓
#     2do Grado A           ✓    ✓    ✓    ✓    ·    ✓    ✓
#
# Era una barra por sección × área × lapso, y de los DOS años escolares: 588 en
# la muestra, casi todas en 100 %. Daniel, el 13 de octubre de 2026: *«debe
# haber una mejor manera de mostrarlo»*. Entre tres dibujos eligió este: el
# colegio entero cabe en una pantalla, y lo que falta se ve porque rompe el
# patrón de las casillas completas.
#
# ⚠️ Una casilla es un PLAN: cuánto pesan las evaluaciones de esa área, en esa
# sección y en ese lapso. Hay casilla donde el área se DICTA —tiene profesor, o
# tiene evaluaciones aunque nadie la tenga asignada, como en
# `Section#materias_dictadas`— y donde no se dicta queda en blanco. Un punto
# dice «se dicta y no tiene evaluaciones»; el blanco, «aquí no se dicta».
#
# ⚠️ Educación Inicial no entra: no planifica (`Grade#planifica?`). Y Técnica
# Media va en su propia tabla: su sexto año tiene áreas que el resto de la Media
# no tiene, y juntas serían columnas casi vacías.
class MapaDeEvaluaciones
  Casilla = Data.define(:peso, :profesor) do
    def completa? = peso >= 100
    def sin_evaluaciones? = peso.zero?
  end

  # `filas` es una lista de `[seccion, { area_id => Casilla }]`.
  Grupo = Data.define(:nivel, :areas, :filas)

  # El lapso que se abre sin elegir: el que corre hoy, si el colegio cargó las
  # fechas; si no, el último que ya tiene evaluaciones —en octubre, el
  # primero—; y si ninguno tiene, el primero.
  def self.lapso_por_defecto(lapsos)
    hoy = Date.current
    lapsos.find { |lapso| lapso.fechas_propias? && lapso.rango.cover?(hoy) } ||
      lapsos.reverse.find { |lapso| EvaluationActivity.exists?(evaluation_moment_id: lapso.id) } ||
      lapsos.first
  end

  attr_reader :lapso

  def initialize(lapso:, secciones:)
    @lapso = lapso
    @secciones = secciones.includes(:grade).to_a.select { |seccion| seccion.grade.planifica? }
                          .sort_by { |seccion| [ seccion.grade.orden || 99, seccion.name ] }
  end

  def grupos
    @grupos ||= @secciones.group_by { |seccion| seccion.grade.level.to_sym }
                          .sort_by { |nivel, _| GradoOficial::NIVELES.index(nivel) || 99 }
                          .map { |nivel, secciones| grupo(nivel, secciones) }
  end

  def vacio? = grupos.empty?

  private

  def grupo(nivel, secciones)
    filas = secciones.map do |seccion|
      dictadas = casillas.select { |(seccion_id, _), _| seccion_id == seccion.id }
      [ seccion, dictadas.transform_keys { |(_, area_id)| area_id } ]
    end
    ids = filas.flat_map { |_, casillas_de_la_fila| casillas_de_la_fila.keys }.uniq
    Grupo.new(nivel: nivel, areas: areas.values_at(*ids).compact.sort_by { |area| [ area.code, area.name ] },
              filas: filas)
  end

  # Cada par sección–área que se dicta, con lo que pesa su plan en el lapso.
  def casillas
    @casillas ||= begin
      profesores = asignaciones.to_h { |ts| [ [ ts.section_id, ts.subject_id ], ts.teacher ] }
      (profesores.keys | pesos.keys).to_h do |par|
        [ par, Casilla.new(peso: pesos.fetch(par, 0).to_f, profesor: profesores[par]) ]
      end
    end
  end

  def asignaciones
    TeacherSection.where(section_id: @secciones.map(&:id)).includes(teacher: :user)
  end

  def pesos
    @pesos ||= EvaluationActivity.where(section_id: @secciones.map(&:id), evaluation_moment_id: @lapso.id)
                                 .group(:section_id, :subject_id).sum(:weight_percentage)
  end

  def areas
    @areas ||= Subject.where(id: casillas.keys.map(&:last)).index_by(&:id)
  end
end
