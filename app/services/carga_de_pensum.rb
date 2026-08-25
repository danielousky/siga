# Escribe las materias, el pensum y los profesores (MOR-126, tanda 2).
#
# De cada fila salen cuatro cosas, y las cuatro son `find_or_create`:
#
#     Department      el área, si el colegio las maneja
#     Subject         la materia, identificada por su CÓDIGO dentro del colegio
#     GradeSubject    el pensum: este grado tiene esta materia
#     TeacherSection  quién la dicta en esta sección
#
# Una materia en cinco secciones son cinco filas y **una sola** `Subject`. Un
# profesor con cinco materias son cinco filas y **una sola** persona. La planilla
# viene así naturalmente y el importador la aprovecha en vez de pedirle al
# colegio que la normalice antes de mandarla.
class CargaDePensum
  include EscribePersonas

  Resultado = Struct.new(:materias_creadas, :materias_reutilizadas,
                         :profesores_creados, :profesores_reutilizados,
                         :asignaciones, :pensum, :secciones_tocadas, :fallidas,
                         keyword_init: true) do
    def total_cargado = asignaciones

    def to_h_para_guardar
      {
        "materias_creadas" => materias_creadas,
        "materias_reutilizadas" => materias_reutilizadas,
        "profesores_creados" => profesores_creados,
        "profesores_reutilizados" => profesores_reutilizados,
        "asignaciones" => asignaciones,
        "pensum" => pensum,
        "secciones" => secciones_tocadas.to_a.sort,
        "fallidas" => fallidas
      }
    end
  end

  def initialize(pensum:, colegio:)
    @pensum = pensum
    @colegio = colegio
    @resultado = Resultado.new(
      materias_creadas: 0, materias_reutilizadas: 0,
      profesores_creados: 0, profesores_reutilizados: 0,
      asignaciones: 0, pensum: 0, secciones_tocadas: Set.new, fallidas: []
    )
    @materias = Set.new
    @personas = Set.new
    @departamentos = {}
  end

  def ejecutar
    @pensum.cargables.each { |fila| cargar(fila) }
    @resultado
  end

  private

  def cargar(fila)
    # Cada fila en su propio SAVEPOINT: si una revienta se deshace ELLA y las
    # demás siguen. Sin eso, un `rescue` dentro de una transacción deja la
    # transacción entera marcada para rollback y todo lo posterior falla.
    ActiveRecord::Base.transaction(requires_new: true) do
      materia = crear_materia(fila)
      profesor = crear_profesor(fila)

      poner_en_el_pensum(materia, fila)
      asignar(profesor, materia, fila)
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    @resultado.fallidas << { "fila" => fila.numero,
                             "materia" => fila.materia,
                             "motivo" => e.message }
  end

  # ── la materia ────────────────────────────────────────────────────────────

  # ⚠️ Se busca por CÓDIGO, no por nombre.
  #
  # `subjects.code` es único dentro del colegio, así que es lo que identifica a
  # la materia. Buscando por nombre, «Matemática» y «Matematica» serían dos
  # materias distintas con el mismo código — y la segunda no se podría guardar.
  def crear_materia(fila)
    @departamentos[fila.departamento] ||= Department.find_or_create_by!(
      school: @colegio, name: fila.departamento
    )

    materia = Subject.find_by(code: fila.codigo)
    ya_contada = visto?(@materias, fila.codigo)

    if materia
      @resultado.materias_reutilizadas += 1 unless ya_contada
    else
      materia = Subject.create!(code: fila.codigo, name: fila.materia,
                                department: @departamentos[fila.departamento])
      @resultado.materias_creadas += 1
    end

    materia
  end

  # El pensum: este grado tiene esta materia. Sale de la sección de la fila.
  def poner_en_el_pensum(materia, fila)
    vinculo = GradeSubject.find_or_initialize_by(grade: fila.seccion.grade, subject: materia)
    return unless vinculo.new_record?

    vinculo.save!
    @resultado.pensum += 1
  end

  # ── el profesor ───────────────────────────────────────────────────────────

  # La búsqueda y la actualización viven en `EscribePersonas`, igual que en la
  # matrícula: un profesor que ya da clase en otro colegio de SIGA es el mismo
  # ser humano, y buscarlo dentro de este colegio nada más lo duplicaría.
  def crear_profesor(fila)
    datos = fila.profesor
    persona = persona_existente(datos[:document])

    if persona.nil?
      persona = User.new(datos)
    else
      actualizar(persona, datos, Teacher.unscoped.exists?(user: persona, school: @colegio))
    end
    persona.save!

    profesor = Teacher.find_or_initialize_by(user: persona, school: @colegio)
    creado = profesor.new_record?
    profesor.save!

    unless visto?(@personas, datos[:document])
      creado ? @resultado.profesores_creados += 1 : @resultado.profesores_reutilizados += 1
    end

    profesor
  end

  # ── la asignación ─────────────────────────────────────────────────────────

  # ⚠️ Una sección tiene UN profesor por materia: `teacher_sections` valida
  # `subject_id` único por `section_id`.
  #
  # Si la planilla trae dos profesores para la misma materia en la misma
  # sección, la segunda fila no puede guardarse. Se reporta en vez de romper: el
  # colegio decide cuál es la buena y vuelve a subir.
  def asignar(profesor, materia, fila)
    asignacion = TeacherSection.find_or_initialize_by(section: fila.seccion, subject: materia)

    if asignacion.persisted? && asignacion.teacher_id != profesor.id
      return @resultado.fallidas << {
        "fila" => fila.numero, "materia" => fila.materia,
        "motivo" => "#{materia.name} en #{etiqueta(fila.seccion)} ya está asignada a " \
                    "#{asignacion.teacher.user.nombre_completo}"
      }
    end
    return unless asignacion.new_record?

    asignacion.teacher = profesor
    asignacion.save!

    @resultado.asignaciones += 1
    @resultado.secciones_tocadas << etiqueta(fila.seccion)
  end

  def etiqueta(seccion) = "#{seccion.grade.name} #{seccion.name}"

  # Los conteos son de cosas DISTINTAS, no de filas: una materia dictada en
  # cinco secciones son cinco filas y UNA materia, y su profesor es UNA persona.
  def visto?(conjunto, clave)
    ya = conjunto.include?(clave)
    conjunto << clave
    ya
  end
end
