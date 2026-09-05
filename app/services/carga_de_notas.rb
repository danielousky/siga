# Qué evaluaciones están a medio cargar, y de quién (MOR-155).
#
# ## Las dos preguntas son la misma, vistas de dos lados
#
#     el PROFESOR   ¿qué me falta corregir?
#     la DIRECCIÓN  ¿a quién hay que llamarle la atención antes de cerrar?
#
# Debajo es el mismo cálculo: evaluaciones cuya fecha ya pasó y que tienen menos
# notas cargadas que alumnos inscritos. Vivía escrito en el panel del profesor;
# copiarlo al del director serían dos definiciones de «atrasado» que se van
# separando, y la dirección terminaría reclamándole a alguien que no debía.
#
# ## ⚠️ «Sin nota» no es cero, tampoco acá
#
# Se cuentan las notas que EXISTEN, no las que valen. Una evaluación con quince
# de treinta cargadas está a medio hacer aunque las quince sean ceros — y una
# con treinta cargadas está completa aunque todas sean uno.
#
# ## Por qué la fecha importa
#
# Solo cuentan las evaluaciones cuya fecha ya pasó. Reclamarle a un profesor por
# un examen que es la semana que viene es la forma más rápida de que la
# dirección deje de mirar esta pantalla.
class CargaDeNotas
  Faltante = Data.define(:evaluacion, :puestas, :total) do
    def faltan = total - puestas
    def porcentaje = total.zero? ? 0 : (puestas * 100.0 / total).round
  end

  Atrasado = Data.define(:profesor, :faltantes) do
    def evaluaciones = faltantes.size
    def alumnos_sin_nota = faltantes.sum(&:faltan)

    # La más vieja es la que ordena el reclamo: un examen de hace tres semanas
    # pesa más que uno de anteayer.
    def mas_vieja = faltantes.map { |f| f.evaluacion.date_scheduled }.min
  end

  # El estado de UNA sección, para pintarla de un vistazo (MOR-223).
  #
  # Daniel: *«en el panel de cada sección, además de un enlace al detalle, hay
  # un indicativo de si les falta por calificar alguna nota de esa sección o si
  # ya está calificada… si ya las tengo calificadas me aparece 20 de 20 y un
  # check en verde; si me falta me aparece 20 de 30 y en amarillo; si no tengo
  # nada calificado me aparece en rojo»*.
  Avance = Data.define(:puestas, :total, :primera_incompleta) do
    def completo? = total.positive? && puestas >= total
    def vacio?    = puestas.zero?
    def sin_nada_que_calificar? = total.zero?

    def estado
      return :sin_evaluaciones if sin_nada_que_calificar?
      return :completo if completo?
      return :vacio    if vacio?

      :a_medias
    end

    def porcentaje = total.zero? ? 0 : (puestas * 100.0 / total).round
  end

  class << self
    # El avance de cada asignación, para pintar la lista de secciones.
    #
    # ⚠️ Devuelve un mapa por `TeacherSection`, no por sección: un profesor
    # puede dictar DOS áreas en la misma sección, y su estado de calificación es
    # distinto en cada una. Agregarlas por sección escondería que Matemática
    # está al día y Castellano no.
    #
    # ⚠️ Cuenta TODAS las evaluaciones del año, no solo las vencidas. La
    # diferencia con `incompletas` es la pregunta: ésa es «¿a quién le reclamo?»
    # —y reclamar por un examen que es la semana que viene hace que nadie mire
    # la pantalla—; ésta es «¿cómo voy?», y ahí la de la semana que viene cuenta.
    def avance_por_asignacion(asignaciones)
      asignaciones = asignaciones.to_a
      return {} if asignaciones.empty?

      # ⚠️ El producto cartesiano trae DE MÁS —una evaluación de Castellano en
      # una sección donde este profesor solo da Matemática— y se filtra abajo,
      # por par. Es una consulta en vez de una por asignación, que es lo que
      # importa: este panel lo abre un profesor desde el teléfono.
      evaluaciones = EvaluationActivity
                     .where(section_id: asignaciones.map(&:section_id).uniq,
                            subject_id: asignaciones.map(&:subject_id).uniq)
                     .order(:date_scheduled, :id)
                     .to_a
      puestas = ActivityGrade.where(evaluation_activity_id: evaluaciones.map(&:id))
                             .group(:evaluation_activity_id).count
      inscritos = inscritos_por_seccion(asignaciones.map(&:section_id).uniq)

      asignaciones.index_with do |ts|
        suyas = evaluaciones.select { |e| e.section_id == ts.section_id && e.subject_id == ts.subject_id }
        por_evaluacion = inscritos[ts.section_id].to_i

        Avance.new(
          puestas: suyas.sum { |e| puestas[e.id].to_i },
          total: suyas.size * por_evaluacion,
          primera_incompleta: suyas.find { |e| puestas[e.id].to_i < por_evaluacion }
        )
      end
    end

    # Lo que le falta a un conjunto de asignaciones (`TeacherSection`).
    def incompletas(asignaciones)
      asignaciones = asignaciones.to_a
      return [] if asignaciones.empty?

      evaluaciones = evaluaciones_vencidas(asignaciones)
      return [] if evaluaciones.empty?

      puestas = ActivityGrade.where(evaluation_activity_id: evaluaciones.map(&:id))
                             .group(:evaluation_activity_id).count
      inscritos = inscritos_por_seccion(evaluaciones.map(&:section_id).uniq)

      evaluaciones.filter_map do |e|
        total = inscritos[e.section_id].to_i
        cargadas = puestas[e.id].to_i
        next if total.zero? || cargadas >= total

        Faltante.new(evaluacion: e, puestas: cargadas, total: total)
      end
    end

    # Lo mismo, agrupado por profesor: lo que la dirección necesita para llamar
    # a alguien por su nombre.
    def profesores_atrasados(periodo)
      return [] if periodo.nil?

      asignaciones = TeacherSection.joins(:section)
                                   .where(sections: { academic_period_id: periodo.id })
                                   .includes(:subject, teacher: :user, section: :grade)
                                   .to_a
      faltantes = incompletas(asignaciones)
      return [] if faltantes.empty?

      # ⚠️ Se cruza por (sección, materia) y no por la evaluación: una
      # `EvaluationActivity` apunta a la sección y a la materia, no al profesor.
      # Buscar el profesor de otra manera le adjudicaría el atraso a quien no es.
      docente_de = asignaciones.index_by { |a| [ a.section_id, a.subject_id ] }

      faltantes.group_by { |f| docente_de[[ f.evaluacion.section_id, f.evaluacion.subject_id ]] }
               .except(nil)
               .map { |asignacion, suyas| Atrasado.new(profesor: asignacion.teacher, faltantes: suyas) }
               .sort_by(&:mas_vieja)
    end

    private

    def evaluaciones_vencidas(asignaciones)
      EvaluationActivity
        .where(section_id: asignaciones.map(&:section_id).uniq,
               subject_id: asignaciones.map(&:subject_id).uniq)
        .where(date_scheduled: ..Date.current)
        .includes(:subject, section: :grade)
        .order(date_scheduled: :desc)
        .to_a
    end

    def inscritos_por_seccion(ids)
      Enrollment.where(section_id: ids, status: :regular).group(:section_id).count
    end
  end
end
