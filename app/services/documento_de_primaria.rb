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
  # ⚠️ **La Educación Primaria venezolana son SEIS grados.** No es una
  # configuración por colegio: lo fija la Ley Orgánica de Educación, y un plantel
  # dicta la primaria completa o no la dicta.
  #
  # Antes esto se deducía preguntando «¿existe un grado siguiente en este
  # colegio?», y estaba mal por una razón peor que la inexactitud: hacía depender
  # un DOCUMENTO OFICIAL de qué grados alguien hubiera cargado en SIGA. Un
  # colegio que todavía no creó 5to y 6to —porque los está cargando de a poco, o
  # porque este año no tiene alumnos ahí— le habría emitido «Certificado de
  # Educación Primaria» a un alumno de 3er Grado.
  ULTIMO_GRADO = 6

  # A dónde promueve el último grado de primaria. No es un grado de este colegio:
  # es el nivel siguiente del sistema, y el formato lo trae impreso así.
  DESPUES_DE_PRIMARIA = "al 1er Año del Nivel de Educación Media".freeze

  # Cómo se llama cada papel, para la pantalla y para la auditoría. Estaba
  # escrito como un ternario en el controller; con dos pantallas que lo emiten
  # —la ficha y la pestaña de certificados— serían dos ternarios.
  NOMBRES = {
    "certificado" => "Certificado de Educación Primaria",
    "prosecucion" => "Constancia de Prosecución"
  }.freeze

  # ⚠️ El papel lo decide el GRADO, y se puede preguntar sin un alumno delante.
  #
  # La pestaña de certificados dice qué va a salir ANTES de emitir —y lo dice
  # también de una sección sin alumnos—, así que la pregunta no puede exigir una
  # inscripción. Es la misma regla de siempre, sacada a donde se pueda consultar.
  def self.tipo_para(grado) = numero_de(grado) == ULTIMO_GRADO ? "certificado" : "prosecucion"

  # El número del grado sale de su nombre: «6to Grado» → 6. Un nombre sin número
  # no se puede ubicar en la secuencia, y ante la duda se emite la CONSTANCIA:
  # es el documento de todos los años, y el certificado —que promueve al nivel
  # de media— es el que no se puede emitir de más.
  def self.numero_de(grado) = grado.name.to_s[/\d+/]&.to_i || 0

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

  # Quien termina 6to Grado recibe el CERTIFICADO; cualquier otro grado de
  # primaria, la CONSTANCIA de prosecución.
  def tipo = self.class.tipo_para(@grado)

  def promovido_a
    return DESPUES_DE_PRIMARIA if ultimo_grado?

    "al #{ordinal(numero + 1)} Grado del Nivel de Educación Primaria"
  end

  def ultimo_grado? = numero == ULTIMO_GRADO

  def numero = @numero ||= self.class.numero_de(@grado)

  ORDINALES = { 1 => "1er", 2 => "2do", 3 => "3er", 4 => "4to",
                5 => "5to", 6 => "6to" }.freeze

  def ordinal(n) = ORDINALES.fetch(n, "#{n}º")

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
