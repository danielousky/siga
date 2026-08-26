# Los datos de los documentos de fin de año de primaria (MOR-99).
#
# Decide **cuál de los dos** corresponde y arma lo que el papel necesita:
#
#     último grado de primaria  →  CERTIFICADO DE EDUCACIÓN PRIMARIA
#                                  promueve al 1er Año del Nivel de Educación Media
#     cualquier otro            →  CONSTANCIA DE PROSECUCIÓN
#                                  promueve al grado siguiente
#
# ⚠️ **Certifican el LITERAL, no el número.** Es la escala A–E de primaria
# (`MOR-129`), y sale del promedio de las materias del año.
class DocumentoDePrimaria
  # A dónde promueve el último grado de primaria. No es un grado de este colegio:
  # es el nivel siguiente del sistema, y el formato lo trae impreso así.
  DESPUES_DE_PRIMARIA = "al 1er Año del Nivel de Educación Media".freeze

  def self.para(enrollment:, firmante: nil)
    new(enrollment: enrollment, firmante: firmante).datos
  end

  def initialize(enrollment:, firmante: nil)
    @inscripcion = enrollment
    @seccion = enrollment.section
    @grado = @seccion.grade
    @colegio = @grado.school
    @firmante = firmante
  end

  # ⚠️ Solo para primaria. Un alumno de bachillerato se certifica con la 31059, y
  # emitirle este papel le pondría un nivel educativo que no cursó.
  def emitible? = @grado.primaria?

  def datos
    {
      "tipo" => tipo,
      "plantel" => plantel,
      "estudiante" => estudiante,
      "grado" => @grado.name,
      "periodo" => @seccion.academic_period.name,
      "literal" => literal,
      "promovido_a" => promovido_a,
      "expedida_en" => expedida_en,
      "firmante" => firmante
    }
  end

  private

  # El certificado se emite al terminar la primaria; la constancia, en cualquier
  # otro grado. Se decide por si hay un grado siguiente, no por el número: un
  # colegio que solo llega a 4to Grado termina ahí, y su alumno no prosigue a un
  # 5to que no existe.
  def tipo = siguiente.nil? ? "certificado" : "prosecucion"

  def promovido_a
    return DESPUES_DE_PRIMARIA if siguiente.nil?

    "al #{siguiente.name} del Nivel de Educación Primaria"
  end

  # El grado que sigue dentro del MISMO colegio, por el número que lleva en el
  # nombre. «5to Grado» sigue a «4to Grado» aunque alguien los haya creado en
  # otro orden.
  def siguiente
    return @siguiente if defined?(@siguiente)

    mio = numero_de(@grado)
    @siguiente = mio && Grade.where(school: @colegio, level: :primaria)
                             .to_a
                             .select { |g| numero_de(g) == mio + 1 }
                             .first
  end

  def numero_de(grado) = grado.name.to_s[/\d+/]&.to_i

  # ── el literal ────────────────────────────────────────────────────────────

  # ⚠️ El promedio del AÑO en todas sus materias, convertido a letra.
  #
  # Se redondea antes de convertir, porque el Artículo 108 manda entero y la
  # tabla de literales está definida sobre enteros: 16,5 es «17 → B», no un punto
  # a mitad de camino entre C y B.
  def literal
    notas = FinalGradeBook.where(enrollment: @inscripcion).filter_map(&:final_score)
    return nil if notas.empty?

    EscalaLiteral.para(GradeCalculator.redondear(notas.sum.to_d / notas.size))
  end

  # ── lo demás ──────────────────────────────────────────────────────────────

  def plantel
    {
      "nombre" => @colegio.name,
      "municipio" => @colegio.municipio,
      "parroquia" => @colegio.parroquia,
      "entidad_federal" => @colegio.entidad_federal
    }
  end

  def estudiante
    persona = @inscripcion.student.user

    {
      "nombre" => persona.nombre_completo,
      # El formato acepta las tres: cédula escolar, cédula de identidad o
      # pasaporte. Se imprime la que la persona tenga.
      "identificador" => persona.identificador.presence || persona.cedula_escolar,
      "lugar_de_nacimiento" => lugar_de_nacimiento(persona),
      "fecha_de_nacimiento" => persona.birth_date && I18n.l(persona.birth_date, format: :long)
    }
  end

  def lugar_de_nacimiento(persona)
    [ persona.birth_municipality, persona.birth_state ].compact_blank.join(", ").presence ||
      persona.birth_place
  end

  def firmante
    director = @firmante || Admin.find_by(school: @colegio, role: :director)
    return {} if director.nil?

    { "nombre" => director.user.nombre_completo, "documento" => director.user.identificador }
  end

  def expedida_en
    [ @colegio.municipio, @colegio.entidad_federal ].compact_blank.join(", ").presence ||
      @colegio.location
  end
end
