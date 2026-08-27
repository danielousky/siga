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
      "comparacion" => comparacion,
      "asistencia"  => asistencia,
      "puesto"      => puesto,
      "emitido"  => Date.current.to_s
    }
  end

  private

  # Cuántos días faltó, en el lapso que este boletín certifica.
  #
  # Un lapso **es** un rango de fechas —"del 16 de septiembre al 20 de
  # diciembre"— y hasta `MOR-135` el modelo no las guardaba. Donde el colegio no
  # las cargó se cuenta el año escolar completo y **el papel lo dice**: un número
  # de inasistencias sin su período no se puede interpretar, y en el boletín del
  # segundo lapso arrastraría las faltas del primero sin avisar.
  def asistencia
    rango = @lapso ? @lapso.rango : (@seccion.academic_period.start_date..@seccion.academic_period.end_date)

    conteo = Attendance.where(enrollment_id: @enrollment.id, date: rango).group(:status).count
    dias   = conteo.values.sum
    return nil if dias.zero?

    {
      "dias"      => dias,
      "presentes" => conteo["presente"].to_i,
      "ausentes"  => conteo["ausente"].to_i,
      "tardes"    => conteo["tarde"].to_i,
      "desde"     => rango.first.to_s,
      "hasta"     => rango.last.to_s,
      # Para que el boletín pueda aclarar de qué período habla.
      "del_lapso" => (@lapso&.fechas_propias? || false)
    }
  end

  # En qué puesto quedó el alumno dentro de su sección, y cuántos son.
  #
  # ## Por qué el empate comparte puesto
  #
  # Dos alumnos con 17 están **los dos** en el mismo puesto: darle el 3 a uno y
  # el 4 al otro por el orden alfabético inventa una diferencia que no existe, y
  # esa diferencia se imprime en un papel que la familia guarda.
  #
  # Solo cuentan los alumnos que TIENEN promedio: quien no tiene ninguna nota
  # cargada no está último, está sin evaluar.
  def puesto
    return nil if @lapso.nil? || promedio.nil?

    # Una consulta, no una por compañero. La versión anterior instanciaba un
    # `ReportCardData` por inscripción y tardaba 200 ms en una sección de veinte
    # — y esto corre al emitir los boletines de la sección ENTERA, así que era
    # 200 ms × 20 en el mismo pedido.
    promedios = MomentGrade
                  .where(enrollment_id: @seccion.enrollments.select(:id), evaluation_moment_id: @lapso.id)
                  .where.not(final_moment_score: nil)
                  .group(:enrollment_id)
                  .average(:final_moment_score)

    ajenos = promedios.except(@enrollment.id).values.map { |p| GradeCalculator.redondear(p) }
    return nil if ajenos.empty?

    promedios = ajenos

    { "puesto"   => promedios.count { |p| p > promedio } + 1,
      "de"       => promedios.size + 1,
      "empatado" => promedios.count { |p| p == promedio }.positive? }
  end

  # Dónde queda el alumno respecto de su sección, materia por materia.
  #
  # ## Por qué esto se congela con el resto
  #
  # El promedio de una sección **cambia** cada vez que un profesor carga una
  # nota. Si el boletín lo calculara al imprimirlo, reemitir en marzo el
  # boletín de diciembre lo compararía contra una clase distinta: el papel que
  # la familia tiene en la mano diría una cosa y la verificación pública otra.
  # Es exactamente lo que `MOR-98` vino a evitar, aplicado a un dato nuevo.
  #
  # ## Por qué seis niveles y no un porcentaje
  #
  # Es la forma del boletín que usan los colegios de aquí —el de la U.E. Centro
  # Educativo APUCV, entre otros—: seis bandas, con el promedio de la clase en
  # el medio. Un número tipo "percentil 63" no le dice nada a una familia; "está
  # por encima del promedio de su sección" sí.
  #
  # Los cortes van en PUNTOS de diferencia y no en desviaciones estándar. Con
  # veinte alumnos y a veces tres notas cargadas, la desviación es ruido: una
  # sección donde todos sacaron 14 y 15 tendría σ≈0,5 y cualquiera con 16
  # aparecería como "muy alto", que es falso y además se lo dirías a la familia
  # por escrito.
  NIVELES = [
    [ -Float::INFINITY, -4.0, "Muy bajo" ],
    [ -4.0,             -2.0, "Bajo" ],
    [ -2.0,              0.0, "Medio bajo" ],
    [  0.0,              2.0, "Medio alto" ],
    [  2.0,              4.0, "Alto" ],
    [  4.0,  Float::INFINITY, "Muy alto" ]
  ].freeze

  ETIQUETAS_DE_NIVEL = NIVELES.map(&:last).freeze

  def comparacion
    return nil if @lapso.nil?   # el anual compara contra tres lapsos, no contra la clase

    promedios = promedios_de_la_seccion
    return nil if promedios.empty?

    filas = materias.filter_map do |m|
      media = promedios[m["materia"]]
      next if m["nota"].nil? || media.nil?

      { "materia" => m["materia"], "nota" => m["nota"], "seccion" => media,
        "nivel" => nivel_de(m["nota"] - media) }
    end
    return nil if filas.empty?

    media_general = promedios.values.sum / promedios.size
    {
      "niveles"  => ETIQUETAS_DE_NIVEL,
      "materias" => filas,
      "general"  => { "nota" => promedio, "seccion" => media_general.round(2),
                      "nivel" => (nivel_de(promedio - media_general) if promedio) }
    }
  end

  def nivel_de(diferencia)
    NIVELES.each_with_index do |(desde, hasta, _), i|
      return i if diferencia >= desde && diferencia < hasta
    end
    NIVELES.size - 1
  end

  # El promedio de CADA materia en la sección, en este lapso.
  #
  # Solo cuentan las notas que existen: una materia sin corregir no arrastra a
  # la clase hacia abajo, por la misma razón que un alumno sin nota no lleva
  # cero (Art. 108). Y hace falta más de un alumno con nota — si no, el
  # "promedio de la sección" sería el propio alumno comparándose consigo mismo.
  def promedios_de_la_seccion
    filas = MomentGrade
              .where(enrollment_id: @seccion.enrollments.select(:id), evaluation_moment_id: @lapso.id)
              .where.not(final_moment_score: nil)
              .group(:subject_id)
              .pluck(Arel.sql("subject_id, AVG(final_moment_score), COUNT(*)"))

    nombres = Subject.where(id: filas.map(&:first)).pluck(:id, :name).to_h

    filas.each_with_object({}) do |(subject_id, media, cuantos), acc|
      next if cuantos < 2

      acc[nombres[subject_id]] = media.to_f.round(2)
    end
  end

  def colegio
    escuela = @seccion.grade.school
    { "nombre" => escuela.name, "dea" => escuela.dea_code, "ubicacion" => escuela.location }
  end

  def alumno
    usuario = @alumno.user
    {
      "nombre" => "#{usuario.last_name}, #{usuario.first_name}",
      "carnet" => @alumno.school_card,
      "cedula" => usuario.document
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

    # ⚠️ Del BOLETÍN, no del grado (MOR-152). `grade.subjects` es el pensum de
    # hoy y no distingue períodos: agregar una materia le aparecía a un alumno de
    # 2021 que nunca la vio. Ver `Enrollment#materias_del_boletin`.
    @enrollment.materias_del_boletin.map do |materia|
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
