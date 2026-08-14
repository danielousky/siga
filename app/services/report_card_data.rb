# Lo que va impreso en un boletín, congelado en el momento de emitirlo.
#
# El PDF se dibuja SIEMPRE desde este hash, nunca desde la base. Es lo que hace
# que un boletín entregado en diciembre siga diciendo lo que decía en diciembre
# aunque el profesor corrija una nota en marzo: el papel que la familia tiene en
# la mano y la verificación pública tienen que coincidir.
#
# Ver MOR-98.
class ReportCardData
  # `evaluation_moment` en nil arma el boletín anual.
  def self.para(enrollment:, evaluation_moment: nil)
    new(enrollment, evaluation_moment).to_h
  end

  def initialize(enrollment, evaluation_moment)
    @enrollment = enrollment
    @lapso      = evaluation_moment
    @seccion    = enrollment.section
    @alumno     = enrollment.student
  end

  def to_h
    {
      "colegio"  => colegio,
      "alumno"   => alumno,
      "seccion"  => seccion,
      "tipo"     => @lapso ? "lapso" : "anual",
      "lapso"    => @lapso&.name,
      "lapsos"   => lapsos.map(&:name),
      "materias" => materias,
      "promedio" => promedio,
      "emitido"  => Date.current.to_s
    }
  end

  private

  def colegio
    escuela = @seccion.grade.school
    { "nombre" => escuela.name, "dea" => escuela.dea_code, "ubicacion" => escuela.location }
  end

  def alumno
    usuario = @alumno.user
    {
      "nombre" => "#{usuario.last_name}, #{usuario.name}",
      "carnet" => @alumno.school_card,
      "cedula" => usuario.id_card
    }
  end

  # `escala` va en el snapshot y no se lee de la base al imprimir, por la misma
  # razón que todo lo demás de acá: el boletín es el ARCHIVO. Si mañana el
  # colegio cambia la escala del grado, un boletín emitido en diciembre tiene que
  # seguir diciendo lo que decía en diciembre — si no, la verificación pública
  # dejaría de coincidir con el papel que la familia tiene en la mano (MOR-129).
  def seccion
    {
      "grado"   => @seccion.grade.name,
      "seccion" => @seccion.name,
      "periodo" => @seccion.academic_period.name,
      "escala"  => @seccion.grade.escala
    }
  end

  def lapsos
    @lapsos ||= EvaluationMoment.where(academic_period_id: @seccion.academic_period_id).order(:id).to_a
  end

  def materias
    notas_de_lapso = MomentGrade.where(enrollment_id: @enrollment.id)
                                .index_by { |mg| [mg.subject_id, mg.evaluation_moment_id] }
    libros = FinalGradeBook.where(enrollment_id: @enrollment.id).index_by(&:subject_id)

    @seccion.grade.subjects.order(:name).map do |materia|
      fila = { "materia" => materia.name }

      if @lapso
        fila["nota"] = notas_de_lapso[[materia.id, @lapso.id]]&.final_moment_score&.to_i
      else
        libro = libros[materia.id]
        fila["lapsos"]     = lapsos.map { |l| notas_de_lapso[[materia.id, l.id]]&.final_moment_score&.to_i }
        fila["anual"]      = libro&.annual_average&.to_i
        fila["reparacion"] = libro&.remedial_exam_score&.to_i
        fila["definitiva"] = libro&.final_score&.to_i
      end

      fila
    end
  end

  # El promedio de las materias QUE TIENEN nota. Las que no, no cuentan como
  # cero: es la misma regla del cálculo oficial (Art. 108) y de la pantalla del
  # alumno. Un boletín que promedia ceros falsos es peor que uno sin promedio.
  def promedio
    valores = materias.filter_map { |m| @lapso ? m["nota"] : m["definitiva"] }
    return nil if valores.empty?

    GradeCalculator.redondear(valores.sum / valores.size.to_d)
  end
end
