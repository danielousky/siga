# El plan del lapso con el nivel que alcanzó UN alumno (MOR-136, segunda mitad).
#
# ## Qué contesta
#
#     Matemática                                   17     PA
#       • Resuelve problemas de adición                   PA   ← la competencia
#           – Suma con reagrupación                       PA   ← el indicador
#           – Estima antes de calcular                    PA
#           – Resuelve en dos pasos                       PI
#
# ## ⚠️ El nivel de un INDICADOR es una lectura, no una cuenta
#
# Hasta el 17 de septiembre esto era imposible, y la razón estaba escrita en
# `Indicator`: *«agregar niveles de indicador a un nivel de competencia exigiría
# una regla —moda, promedio, mínimo— que ninguna norma define»*. Una regla
# inventada es una regla que la maestra le tiene que defender a una mamá en la
# puerta del salón.
#
# La regla de Daniel —*«los indicadores no se repiten entre evaluaciones»*—
# disolvió la objeción:
#
#     ANTES   indicador ──► competencia ──► N evaluaciones ──► ¿qué nivel?
#     AHORA   indicador ──► 1 evaluación ──► 1 nota ──► 1 nivel
#
# No hay nada que promediar. Y no cuesta trabajo extra a nadie: no se captura
# un dato nuevo, se lee el que la maestra ya cargó.
#
# ## ⚠️ Solo los indicadores que se MIDIERON
#
# Decisión de Daniel, 18 de septiembre. Un indicador que ninguna evaluación
# midió este lapso no sale en la boleta: no tiene nivel que mostrar y el
# renglón vacío hace más larga una boleta que ya tiene ocho materias. El plan
# completo se sigue viendo en la pantalla del profesor, que es donde sirve.
#
# ## ⚠️ Vive acá y no en dos sitios
#
# `ReportCardData` y `RepresentanteController` calculaban el promedio ponderado
# de una competencia con el mismo método escrito dos veces. Son dos lecturas de
# lo mismo —el documento congelado y la pantalla de hoy— y al agregarles el
# nivel por indicador se habrían separado en el primer arreglo.
class PlanEvaluado
  # `student_id` en vez de la inscripción: las notas cuelgan del ALUMNO
  # (`activity_grades.student_id`), y los dos llamadores tienen ese id a mano.
  def self.de(section_id:, subject_id:, evaluation_moment_id:, student_id:, rubricas:)
    new(section_id, subject_id, evaluation_moment_id, student_id, rubricas).competencias
  end

  # ⚠️ Un boletín EMITIDO no cambia, y los viejos guardaron los indicadores como
  # una lista de TEXTOS. Leerlos como hashes devolvería `nil` en cada renglón y
  # la boleta de diciembre saldría con los indicadores en blanco.
  #
  # Se normaliza al leer y no se migra el `snapshot`: reescribir un documento
  # emitido es exactamente lo que el snapshot existe para impedir.
  def self.indicadores_de(competencia)
    Array(competencia["indicadores"]).map do |indicador|
      next indicador if indicador.is_a?(Hash)

      { "texto" => indicador, "nivel_de_rubrica" => nil }
    end
  end

  def initialize(section_id, subject_id, evaluation_moment_id, student_id, rubricas)
    @section_id = section_id
    @subject_id = subject_id
    @evaluation_moment_id = evaluation_moment_id
    @student_id = student_id
    @rubricas = rubricas
  end

  def competencias
    plan.map do |competencia|
      { "texto" => competencia.descripcion,
        "nivel_de_rubrica" => nivel(nota_de_la_competencia(competencia)),
        "indicadores" => indicadores_medidos(competencia) }
    end
  end

  private

  attr_reader :section_id, :subject_id, :evaluation_moment_id, :student_id, :rubricas

  def plan
    @plan ||= Competency.where(section_id: section_id, subject_id: subject_id,
                               evaluation_moment_id: evaluation_moment_id)
                        .includes(:indicators).order(:orden, :id).to_a
  end

  # ⚠️ Los que MIDIÓ alguna evaluación, y cada uno con el nivel de ESA.
  #
  # `indicators` ya viene ordenada y precargada; filtrar en Ruby evita una
  # consulta por competencia en una boleta de ocho materias.
  def indicadores_medidos(competencia)
    competencia.indicators.select(&:medido?).map do |indicador|
      { "texto" => indicador.descripcion,
        "nivel_de_rubrica" => nivel(notas[indicador.evaluation_activity_id]) }
    end
  end

  # El promedio ponderado de las actividades que evalúan esta competencia.
  #
  # ⚠️ Devuelve `nil` —no cero— cuando el alumno no tiene ninguna nota en ellas.
  # Sin nota no es reprobado: es que nadie evaluó todavía, y confundirlos le
  # pone un «NP» a un niño al que no le tomaron nada.
  def nota_de_la_competencia(competencia)
    actividades = competencia.evaluation_activities_con_peso
    return nil if actividades.empty?

    suyas = notas.slice(*actividades.keys)
    return nil if suyas.empty?

    peso = suyas.keys.sum { |id| actividades[id] }
    return nil if peso.zero?

    GradeCalculator.redondear(suyas.sum { |id, nota| nota * actividades[id] } / peso)
  end

  # ⚠️ TODAS las notas del alumno en el lapso, de una sola consulta.
  #
  # Antes se consultaba por competencia; con el nivel por indicador serían dos
  # por competencia —una para el promedio y otra para cada indicador— o sea
  # cuarenta y ocho consultas en una boleta de ocho materias.
  def notas
    @notas ||= ActivityGrade
               .where(student_id: student_id)
               .where(evaluation_activity_id: EvaluationActivity.where(
                 section_id: section_id, subject_id: subject_id,
                 evaluation_moment_id: evaluation_moment_id
               ).select(:id))
               .pluck(:evaluation_activity_id, :score).to_h
  end

  def nivel(nota)
    return nil if nota.blank? || rubricas.empty?

    Rubric.para(nota, rubricas)&.code
  end
end
