# El RESUMEN FINAL DEL RENDIMIENTO ESTUDIANTIL, formato `RR-DEA-04-03`.
#
# Es el acta que el colegio le manda a la zona educativa al cerrar el año, y es
# el documento de fin de año de **Educación Media** — el hermano del certificado
# de primaria y de la certificación de Inicial.
#
# ## ⚠️ Es de la SECCIÓN, no de un alumno
#
# Los otros tres certifican a una persona; éste resume a todo el curso: una fila
# por alumno, una columna por asignatura, y al pie quién dictó cada una. Por eso
# se pide desde la sección y no desde la ficha del alumno.
#
#     N° │ Cédula      │ 01  02  03 … 15 │ Prog. E.T. │ Resumen
#     01 │ V-30123456  │ 17  14  20 …    │            │
#
# ## ⚠️ Tres casillas quedan EN BLANCO, y es a propósito
#
#     Plan de Estudio · Mención     SIGA no los modela
#     Educación para el Trabajo     tampoco, ni sus programas ni sus horas
#     «Resumen» (la última columna) el formato no dice qué va ahí
#
# Es la misma decisión que la 31059: el formato tiene casillas que SIGA no puede
# llenar, y con solo el PDF el colegio queda bloqueado esperando que nosotros
# cambiemos algo. Por eso sale también en Excel, y ahí las completa a mano.
# Decisión de Daniel, 11 de septiembre de 2026.
class ResumenFinalDeLaSeccion
  # Cuántas asignaturas caben en el formato oficial. Un pensum más largo no
  # entra en la cuadrícula del ministerio, así que se corta acá y se avisa.
  COLUMNAS_DE_ASIGNATURA = 15

  Fila = Data.define(:numero, :alumno, :notas) do
    def cedula = alumno.user.identificador_a_la_vista
    def nombre = alumno.user.apellidos_y_nombres
  end

  def self.para(seccion:, firmante: nil)
    new(seccion: seccion, firmante: firmante).datos
  end

  def initialize(seccion:, firmante: nil)
    @seccion = seccion
    @grado = seccion.grade
    @colegio = @grado.school
    @firmante = firmante
  end

  # ⚠️ Solo Educación Media. Primaria e Inicial tienen sus propios documentos, y
  # este formato dice «Régimen Regular» de bachillerato en su encabezado.
  def emitible? = @grado.media?

  def datos
    {
      "plantel" => plantel,
      "curso" => curso,
      "asignaturas" => asignaturas.map { |m| { "codigo" => codigo_de(m), "nombre" => m.name,
                                               "profesor" => profesor_de(m) } },
      "filas" => filas.map { |f| { "numero" => format("%02d", f.numero), "cedula" => f.cedula,
                                   "nombre" => f.nombre, "notas" => f.notas } },
      "total_de_alumnos" => inscripciones.size,
      "se_cortaron_asignaturas" => materias.size > COLUMNAS_DE_ASIGNATURA,
      "firmante" => firmante
    }
  end

  private

  def plantel
    {
      "dea" => @colegio.dea_code,
      "nombre" => @colegio.name,
      "direccion" => @colegio.direccion,
      "municipio" => @colegio.municipio,
      "entidad_federal" => @colegio.entidad_federal,
      "director" => @firmante&.nombre_completo
    }
  end

  def curso
    {
      "grado" => @grado.name,
      "seccion" => @seccion.name,
      "anio_escolar" => @seccion.academic_period.name
    }
  end

  # Las del pensum del grado, en el orden en que se numeran en el formato.
  def materias = @materias ||= @grado.subjects.order(:name).to_a

  def asignaturas = materias.first(COLUMNAS_DE_ASIGNATURA)

  def codigo_de(materia) = format("%02d", asignaturas.index(materia) + 1)

  # ⚠️ Quién dictó cada asignatura EN ESTA SECCIÓN, no en el grado: «1er Año A»
  # y «1er Año B» pueden tener profesores distintos de Matemática, y el acta
  # lleva la firma del que le dio clase a ESTOS alumnos.
  def profesor_de(materia)
    docente = asignaciones[materia.id]&.teacher
    return nil if docente.nil?

    { "nombre" => docente.user.apellidos_y_nombres,
      "documento" => docente.user.documento_a_la_vista }
  end

  def asignaciones
    @asignaciones ||= TeacherSection.where(section_id: @seccion.id)
                                    .includes(teacher: :user)
                                    .index_by(&:subject_id)
  end

  def inscripciones = @inscripciones ||= Enrollment.en_orden_de_lista(@seccion.enrollments)

  def filas
    inscripciones.each_with_index.map do |inscripcion, i|
      Fila.new(numero: i + 1, alumno: inscripcion.student,
               notas: asignaturas.map { |m| definitivas.dig(inscripcion.id, m.id) })
    end
  end

  # ⚠️ La DEFINITIVA, que es la que manda el Artículo 112: si hubo reparación,
  # es esa. Una consulta para toda la sección.
  def definitivas
    @definitivas ||= FinalGradeBook
                     .where(enrollment_id: inscripciones.map(&:id))
                     .each_with_object({}) do |libro, mapa|
                       (mapa[libro.enrollment_id] ||= {})[libro.subject_id] = libro.final_score&.to_i
                     end
  end

  def firmante
    return nil if @firmante.nil?

    { "nombre" => @firmante.nombre_completo, "documento" => @firmante.identificador_a_la_vista }
  end
end
