# Escribe la matrícula en la base (MOR-126).
#
# Es el único paso que crea algo, y corre después de que alguien vio la
# previsualización y confirmó.
#
# ## Fila por fila, no todo o nada
#
# El issue pedía «todo-o-nada, **o** un reporte exacto de qué entró y qué no».
# Acá es lo segundo, y a propósito: con una transacción única, una fila
# inesperada en la 200 de 360 se lleva las 359 buenas y el colegio tiene que
# empezar de cero sin saber cuál falló. Cada fila va en su propio savepoint, y
# lo que se rompe queda anotado con su número de fila del archivo.
#
# ## Reimportar no duplica
#
# Es el caso NORMAL: el colegio manda la planilla, ve el reporte, corrige cuatro
# filas y la vuelve a mandar. Todo se busca antes de crearse, y por CÉDULA
# —nunca por nombre—: `MOR-138` probó que 90 de 290 alumnos compartían carnet
# entre dos colegios, y los nombres se repiten todavía más.
class CargaDeMatricula
  include EscribePersonas

  Resultado = Struct.new(:alumnos_creados, :alumnos_actualizados,
                         :representantes_creados, :representantes_reutilizados,
                         :inscripciones, :secciones_tocadas,
                         :sin_correo, :fallidas, keyword_init: true) do
    def total_cargado = alumnos_creados + alumnos_actualizados

    def to_h_para_guardar
      {
        "alumnos_creados" => alumnos_creados,
        "alumnos_actualizados" => alumnos_actualizados,
        "representantes_creados" => representantes_creados,
        "representantes_reutilizados" => representantes_reutilizados,
        "inscripciones" => inscripciones,
        "secciones" => secciones_tocadas.to_a.sort,
        "sin_correo" => sin_correo,
        "fallidas" => fallidas
      }
    end
  end

  def initialize(matricula:, colegio:)
    @matricula = matricula
    @colegio = colegio
    @resultado = Resultado.new(
      alumnos_creados: 0, alumnos_actualizados: 0,
      representantes_creados: 0, representantes_reutilizados: 0,
      inscripciones: 0, secciones_tocadas: Set.new,
      sin_correo: [], fallidas: []
    )
  end

  def ejecutar
    @matricula.cargables.each { |fila| cargar(fila) }
    @resultado
  end

  private

  def cargar(fila)
    # `requires_new` abre un SAVEPOINT: si esta fila revienta, se deshace ELLA y
    # las demás siguen. Sin eso, `rescue` dentro de una transacción deja la
    # transacción entera marcada para rollback y todo lo posterior falla.
    ActiveRecord::Base.transaction(requires_new: true) do
      alumno = crear_alumno(fila)
      representante = crear_representante(fila)

      vincular(alumno, representante, fila)
      inscribir(alumno, fila)
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    @resultado.fallidas << { "fila" => fila.numero,
                             "alumno" => fila.nombre_del_alumno,
                             "motivo" => e.message }
  end

  # ── las personas ──────────────────────────────────────────────────────────
  #
  # La búsqueda y la actualización viven en `EscribePersonas`: el importador de
  # pensum hace lo mismo con los profesores.

  def crear_alumno(fila)
    datos = fila.alumno
    persona = persona_existente(datos[:document], datos[:cedula_escolar])
    nueva = persona.nil?

    if nueva
      persona = User.new(datos)
    else
      actualizar(persona, datos, Student.unscoped.exists?(user: persona, school: @colegio))
    end
    persona.save!

    alumno = Student.find_or_initialize_by(user: persona, school: @colegio)
    alumno.school_card = fila.carnet.presence || alumno.school_card.presence || siguiente_carnet
    creado = alumno.new_record?
    alumno.save!

    creado ? @resultado.alumnos_creados += 1 : @resultado.alumnos_actualizados += 1
    alumno
  end

  def crear_representante(fila)
    datos = fila.representante.except(:phone)
    persona = persona_existente(datos[:document])

    if persona.nil?
      persona = User.new(datos)
    else
      actualizar(persona, datos, Representative.unscoped.exists?(user: persona, school: @colegio))
    end
    persona.save!

    representante = Representative.find_or_initialize_by(user: persona, school: @colegio)
    representante.phone = fila.representante[:phone] if fila.representante[:phone].present?
    creado = representante.new_record?
    representante.save!

    creado ? @resultado.representantes_creados += 1 : @resultado.representantes_reutilizados += 1

    if persona.email.blank?
      # Apellido primero, como todos los listados de la app: esta lista se usa
      # para BUSCAR a alguien, no para saludarlo.
      @resultado.sin_correo << { "nombre" => persona.apellidos_y_nombres, "cedula" => persona.document }
    end

    representante
  end

  def vincular(alumno, representante, fila)
    vinculo = StudentRepresentative.find_or_initialize_by(representative: representante, student: alumno)
    vinculo.parentesco = fila.parentesco if vinculo.new_record?
    vinculo.principal = true if vinculo.new_record?
    vinculo.save!
  end

  # La fecha de inscripción es la del año escolar, no la de hoy: se está
  # cargando una matrícula que ya existe, no inscribiendo a nadie ahora.
  def inscribir(alumno, fila)
    inscripcion = Enrollment.find_or_initialize_by(student: alumno, section: fila.seccion)
    return unless inscripcion.new_record?

    inscripcion.enrollment_date = fila.seccion.academic_period.start_date || Date.current
    inscripcion.save!

    @resultado.inscripciones += 1
    @resultado.secciones_tocadas << "#{fila.seccion.grade.name} #{fila.seccion.name}"
  end

  # ── el carnet ─────────────────────────────────────────────────────────────

  # El carnet lo numera el colegio y la planilla casi nunca lo trae, pero el
  # modelo lo exige. Se genera con el año escolar y un consecutivo, igual que
  # los que ya existen: `25-001`.
  #
  # ⚠️ No es único en la plataforma y no debe serlo: `MOR-138` descubrió que 90
  # de 290 alumnos compartían carnet entre dos colegios, porque cada plantel
  # numera desde 1. Lo que identifica a la persona es la cédula.
  # El formato y el consecutivo viven en `Student`: lo mismo hace falta al
  # importar historial y al dar de alta a mano, y estaban escritos tres veces
  # (dos de ellas distintas).
  def siguiente_carnet = Student.siguiente_carnet(@colegio)
end
