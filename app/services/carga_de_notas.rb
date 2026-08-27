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

  class << self
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
