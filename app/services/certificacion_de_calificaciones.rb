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
# ## Las ocho secciones del formato
#
# Están tomadas de un ejemplar REAL, lleno y sellado, no de una descripción:
#
#     I     plan de estudio (31059) · lugar y fecha de expedición
#     II    la institución que emite: código, epónimo, dirección, teléfono,
#           municipio, entidad federal y CDCEE
#     III   identificación del estudiante, con el lugar de nacimiento partido
#           en país, estado y municipio
#     IV    instituciones donde cursó estudios (hasta cinco)
#     V     el plan de estudio: un BLOQUE POR AÑO, de primero a quinto
#     VI    observaciones, con el promedio académico
#     VII   firma del director del plantel, con su sello
#     VIII  firma del director del CDCEE, con el sello del estado
#
# ## ⚠️ La calificación va en NÚMERO y EN LETRAS
#
# No es el literal A–E: es el mismo número escrito de las dos maneras —«11 ·
# ONCE»— que es como se protege un documento oficial contra la adulteración.
# Cambiarle un trazo al 11 para volverlo 17 exige cambiar también la palabra.
#
# El literal A–E existe aparte, y solo para dos áreas: **Orientación y
# Convivencia** y **Participación en Grupos**, que van en sus propias tablitas
# al final de la sección V, por año.
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
      "anos" => bloques_por_ano,
      "orientacion_y_convivencia" => literal_por_ano(Subject::ORIENTACION),
      "participacion_en_grupos" => literal_por_ano(Subject::PARTICIPACION),
      "observaciones" => { "promedio_academico" => promedio_academico }
    }
  end

  private

  # ── sección II ────────────────────────────────────────────────────────────

  def plantel
    {
      "nombre" => @colegio.name,
      "codigo" => @colegio.dea_code,
      "direccion" => @colegio.direccion.presence || @colegio.location,
      "telefono" => @colegio.telefono,
      "entidad_federal" => @colegio.entidad_federal,
      "municipio" => @colegio.municipio,
      "cdcee" => @colegio.cdcee
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
      # ⚠️ El formato tiene una casilla para cada uno. `birth_place` es texto
      # libre y se conserva para la pantalla, pero acá no sirve: partirlo
      # adivinando pondría un municipio donde hay un estado.
      "pais_de_nacimiento" => persona.birth_country,
      "estado_de_nacimiento" => persona.birth_state,
      "municipio_de_nacimiento" => persona.birth_municipality,
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
        "localidad" => colegio.municipio.presence || colegio.location,
        "entidad_federal" => colegio.entidad_federal,
        "anos" => de_ese.map { |e| e.section.academic_period.name }.uniq.sort }
    end
  end

  # ── sección V ─────────────────────────────────────────────────────────────

  # ⚠️ Un BLOQUE POR AÑO, no una matriz de áreas × años.
  #
  # La forma real tiene cinco recuadros —PRIMER AÑO, SEGUNDO AÑO…— cada uno con
  # su propia tabla. No es cosmético: las áreas cambian de un año a otro (en
  # cuarto aparece Formación para la Soberanía Nacional, en quinto Ciencias de la
  # Tierra) y una matriz común dejaría una fila con cuatro guiones para cada área
  # que no se cursa todos los años.
  ORDINALES = { 1 => "PRIMER", 2 => "SEGUNDO", 3 => "TERCER", 4 => "CUARTO", 5 => "QUINTO" }.freeze

  def bloques_por_ano
    anos_del_plan.map do |grado, periodo|
      { "ordinal" => ordinal_de(grado),
        "grado" => grado.name,
        "periodo" => periodo.name,
        "areas" => areas_de(grado, periodo) }
    end
  end

  # ⚠️ El ordinal sale del GRADO, no de la posición en la lista.
  #
  # Contando posiciones, un alumno que repitió tercer año recibía «SEXTO AÑO» —
  # un año que no existe en media general— porque tenía seis inscripciones. Lo
  # que el formato quiere es qué año cursó, y eso lo dice el grado: quien repite
  # tiene dos recuadros y los dos dicen TERCER AÑO, que es lo correcto.
  def ordinal_de(grado)
    numero = grado.name.to_s[/\d+/]&.to_i

    ORDINALES[numero] ? "#{ORDINALES[numero]} AÑO" : grado.name.to_s.upcase
  end

  # «1º», «3º» — para las tablitas de literal, que van por año y no por recuadro.
  def numero_de_ano(grado)
    numero = grado.name.to_s[/\d+/]&.to_i

    numero ? "#{numero}º" : grado.name.to_s
  end

  # Las áreas de formación de ese año, SIN las dos que van en sus tablitas
  # aparte. El certificado dice lo que el alumno cursó, no lo que dice el pensum.
  def areas_de(grado, periodo)
    libros_de(grado, periodo)
      .reject { |l| Subject.de_literal_por_norma?(l.subject.name) }
      .map { |l| calificacion(l) }
      .compact
      .sort_by { |a| a["area"] }
  end

  # Una calificación como la pide el formato: número, letras, tipo y fecha.
  def calificacion(libro)
    nota = libro.final_score
    return nil if nota.nil?

    periodo = libro.enrollment.section.academic_period
    obtenida = periodo.end_date || Date.new(1900)

    {
      "area" => libro.subject.name,
      "numero" => nota.to_i,
      # ⚠️ El mismo número escrito con palabras, no el literal A–E.
      "letras" => NumeroEnLetras.para(nota.to_i),
      # ⚠️ **F** es la calificación final del año; **R**, la de reparación.
      #
      # El ejemplar real trae un tercer valor, `P`, en filas fechadas en octubre
      # —cuando se evalúan las materias pendientes—. SIGA no modela «pendiente»,
      # así que no se inventa: lo que no es reparación es final.
      "te" => libro.remedial_exam_score.present? ? "R" : "F",
      "mes" => format("%02d", obtenida.month),
      "ano" => obtenida.year
    }
  end

  # ── las dos áreas con literal, al final de la sección V ───────────────────

  # ⚠️ Van por AÑO y con la letra, no con el número.
  #
  # En el ejemplar real, «Participación en Grupos» además dice **cuál grupo**
  # —MANUALIDADES, REPOSTERÍA, GASTRONOMÍA— y eso SIGA no lo modela: la casilla
  # queda para que el colegio la escriba. Inventarle un grupo a un alumno sería
  # poner en un documento oficial algo que nadie declaró.
  def literal_por_ano(area)
    anos_del_plan.filter_map do |grado, periodo|
      libro = libros_de(grado, periodo).find { |l| Subject.area_del_31059(l.subject.name) == area }
      next if libro.nil? || libro.final_score.nil?

      { "ano" => numero_de_ano(grado),
        "literal" => EscalaLiteral.para(libro.final_score.to_i),
        "grupo" => nil }
    end
  end

  # ── sección VI ────────────────────────────────────────────────────────────

  # El promedio de TODAS las calificaciones definitivas del bachillerato, con dos
  # decimales. Es lo que dice el ejemplar real: «Promedio Académico : 12.73».
  #
  # No se redondea al entero del Artículo 108: ese artículo manda sobre la
  # calificación de una materia, y esto es un promedio de promedios que el
  # formato pide con decimales.
  def promedio_academico
    notas = anos_del_plan.flat_map { |g, p| libros_de(g, p) }.filter_map(&:final_score)
    return nil if notas.empty?

    (notas.sum.to_d / notas.size).round(2).to_f
  end

  def libros_de(grado, periodo)
    @por_ano ||= libros.group_by do |l|
      [ l.enrollment.section.grade_id, l.enrollment.section.academic_period_id ]
    end

    @por_ano.fetch([ grado.id, periodo.id ], [])
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
