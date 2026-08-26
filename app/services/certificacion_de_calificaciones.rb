# Los datos de la Certificación de Calificaciones del MPPE (MOR-99).
#
# ## Qué es este documento
#
# La forma **31059** es la certificación oficial de Educación Media General, en
# vigencia desde el **17 de noviembre de 2017**, respaldada por la Resolución
# DM/0033 publicada en **Gaceta Oficial 41.221** del 24 de agosto de 2017, y
# elaborada por la Dirección General de Registro y Control Académico del MPPE.
#
# A diferencia del boletín, **cubre todos los años en un solo papel**: de 1º a 5º
# año, con la calificación definitiva de cada área en cada año cursado. Es lo que
# pide una universidad, una embajada o el colegio que recibe a un alumno.
#
# ## Las cinco secciones del formato
#
#     I    plan de estudio (31059) · lugar y fecha de expedición
#     II   datos del plantel: nombre, código, dirección, entidad, municipio
#     III  identificación del estudiante
#     IV   planteles donde cursó
#     V    áreas de formación con su calificación, por año
#
# ## ⚠️ Dos áreas van en LETRA, y el resto en número
#
# Desde el plan 31059, **Orientación y Convivencia** y **Participación en Grupos
# de Creación, Recreación y Producción** llevan calificación literal aunque estén
# en bachillerato. Eso vive en `subjects.escala` y no en el grado — ver
# `Subject#escala_en`.
class CertificacionDeCalificaciones
  # El código del plan de estudio. Va en la sección I del formato y es lo que le
  # dice a quien la recibe qué documento está leyendo.
  PLAN = "31059".freeze
  PLAN_NOMBRE = "Educación Media General".freeze

  # ⚠️ La certificación vale TRES AÑOS desde su expedición. No es una decisión
  # nuestra: es la vigencia que fija el MPPE, y va impresa para que quien la
  # recibe sepa hasta cuándo le sirve.
  VIGENCIA = 3

  def self.para(student:, expedida_en: nil)
    new(student: student, expedida_en: expedida_en).datos
  end

  def initialize(student:, expedida_en: nil)
    @alumno = student
    @colegio = student.school
    @expedida_en = expedida_en.presence || [ @colegio.municipio, @colegio.entidad_federal ]
                                             .compact_blank.join(", ").presence ||
                   @colegio.location
  end

  # ⚠️ El plan 31059 es de EDUCACIÓN MEDIA GENERAL, y no vale para primaria.
  #
  # Primaria se certifica con otra forma, que este documento no dibuja. Emitir
  # una 31059 con las notas de un alumno de 5to Grado le pone al papel un plan de
  # estudio que ese alumno no cursó — y eso es exactamente lo que hace que la
  # zona educativa lo rechace.
  #
  # Se pregunta antes de armar nada, para que quien la pide se entere en la
  # pantalla y no en la ventanilla.
  def emitible?
    anos.any? { |grado, _| grado.secundaria? }
  end

  # Los años que NO son de media general y por eso quedan fuera del documento.
  def anos_fuera_del_plan
    anos.reject { |grado, _| grado.secundaria? }.map { |g, p| etiqueta_de_ano(g, p) }
  end

  def datos
    {
      "plan" => { "codigo" => PLAN, "nombre" => PLAN_NOMBRE, "vigencia" => VIGENCIA },
      "expedida" => { "en" => @expedida_en, "el" => Date.current.iso8601 },
      "plantel" => plantel,
      "estudiante" => estudiante,
      "planteles_cursados" => planteles_cursados,
      "anos" => anos_del_plan.map { |g, p| etiqueta_de_ano(g, p) },
      "areas" => areas
    }
  end

  private

  # ── sección II ────────────────────────────────────────────────────────────

  def plantel
    {
      "nombre" => @colegio.name,
      "dea" => @colegio.dea_code,
      "direccion" => @colegio.direccion.presence || @colegio.location,
      "entidad_federal" => @colegio.entidad_federal,
      "municipio" => @colegio.municipio
    }
  end

  # ── sección III ───────────────────────────────────────────────────────────

  # ⚠️ Apellidos y nombres van SEPARADOS, no juntos.
  #
  # El formato tiene una casilla para cada uno, y quien recibe el documento
  # compara el PRIMER apellido contra la cédula del SAIME. Un «Nombre completo»
  # de una sola línea obliga a adivinar dónde corta.
  def estudiante
    persona = @alumno.user

    {
      "apellidos" => persona.apellidos,
      "nombres" => Normaliza.titulo(persona.first_name),
      "documento" => persona.identificador,
      "cedula_escolar" => persona.cedula_escolar,
      "fecha_de_nacimiento" => persona.birth_date&.iso8601,
      "lugar_de_nacimiento" => persona.birth_place,
      "sexo" => persona.sex
    }
  end

  # ── sección IV ────────────────────────────────────────────────────────────

  # Los planteles donde cursó, deducidos de sus inscripciones.
  #
  # ⚠️ **Alcanza hasta donde llega SIGA.** Un alumno que hizo 1º y 2º en otro
  # colegio trae esa historia en papel, y hoy no hay dónde escribirla: lo que se
  # lista son los planteles de SIGA en los que tiene inscripción — que puede ser
  # más de uno, porque desde `MOR-138` una persona puede ser alumno en varios.
  #
  # Para un alumno que hizo todo su bachillerato en el mismo colegio —el caso
  # normal— la sección queda completa.
  def planteles_cursados
    inscripciones.group_by { |e| e.section.grade.school }.map do |colegio, de_ese|
      { "plantel" => colegio.name,
        "dea" => colegio.dea_code,
        "localidad" => colegio.location,
        "anos" => de_ese.map { |e| e.section.academic_period.name }.uniq.sort }
    end
  end

  # ── sección V ─────────────────────────────────────────────────────────────

  # Una fila por área de formación, una columna por año cursado.
  #
  # Las áreas salen de las MATERIAS que el alumno cursó de verdad, no del pensum:
  # un alumno que se cambió de mención no cursó las mismas que sus compañeros, y
  # el certificado dice lo que él hizo.
  def areas
    del_plan = anos_del_plan.map { |g, p| etiqueta_de_ano(g, p) }.to_set

    libros.select { |l| del_plan.include?(etiqueta_de_ano(l.enrollment.section.grade, l.enrollment.section.academic_period)) }
          .group_by(&:subject).map do |materia, de_esa|
      notas = de_esa.to_h do |libro|
        grado = libro.enrollment.section.grade
        periodo = libro.enrollment.section.academic_period

        [ etiqueta_de_ano(grado, periodo), calificacion(libro, materia, grado) ]
      end

      { "area" => materia.name, "codigo" => materia.code, "notas" => notas }
    end.sort_by { |a| a["area"] }
  end

  # ⚠️ La definitiva es `final_score`, no `annual_average`.
  #
  # Artículo 112 del Reglamento: la nota de la segunda oportunidad es la
  # definitiva. `final_score` ya la tiene resuelta; `annual_average` es la del
  # año sin la reparación, y certificar esa deja aplazado a quien reparó.
  def calificacion(libro, materia, grado)
    nota = libro.final_score
    return nil if nota.nil?

    literal = materia.escala_en(grado).to_s == "literal"

    # ⚠️ En el certificado va la LETRA SOLA, no «17 (B)» como en el boletín.
    #
    # El boletín le muestra las dos cosas a una familia porque el número explica
    # la letra. El formato oficial tiene una casilla y la norma dice que esas dos
    # áreas se certifican con literal: poner el número al lado sería agregarle
    # algo al documento que el MPPE no puso.
    { "numero" => nota.to_i, "escala" => literal ? "literal" : "numerica",
      "texto" => literal ? EscalaLiteral.para(nota.to_i) : nota.to_i.to_s }
  end

  # ── lo común ──────────────────────────────────────────────────────────────

  # ⚠️ La columna es (grado, año escolar) y no solo el grado: un alumno que
  # repitió cursó «3er Año» dos veces, y las dos tienen que aparecer.
  def etiqueta_de_ano(grado, periodo) = "#{grado.name} · #{periodo.name}"

  def anos
    @anos ||= inscripciones.map { |e| [ e.section.grade, e.section.academic_period ] }
                           .uniq
                           .sort_by { |_, p| p.start_date || Date.new(1900) }
  end

  # Solo los de media general: son los que el plan 31059 certifica.
  def anos_del_plan = anos.select { |grado, _| grado.secundaria? }

  # Sin aislamiento: una persona puede ser alumno en varios colegios de SIGA
  # (`MOR-138`), y su certificación cubre todo lo que cursó.
  def inscripciones
    @inscripciones ||= Current.sin_aislamiento do
      Enrollment.unscoped
                .where(student_id: Student.unscoped.where(user_id: @alumno.user_id).select(:id))
                .includes(section: [ { grade: :school }, :academic_period ])
                .to_a
    end
  end

  def libros
    @libros ||= Current.sin_aislamiento do
      FinalGradeBook.unscoped
                    .where(enrollment_id: inscripciones.map(&:id))
                    .includes(:subject, enrollment: { section: [ :grade, :academic_period ] })
                    .to_a
    end
  end
end
