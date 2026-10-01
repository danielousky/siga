# Los datos de los documentos de fin de año de Educación Inicial (MOR-99).
#
# Decide **cuál de los dos** corresponde, igual que su hermano de primaria:
#
#     III Grupo (el último)  →  CERTIFICACIÓN DE ESTUDIOS DEL NIVEL DE
#                               EDUCACIÓN INICIAL
#                               «continuará estudios en el 1ER. GRADO del
#                                Nivel de Educación Primaria»
#     I y II Grupo           →  CONSTANCIA DE PROSECUCIÓN EN EL NIVEL DE
#                               EDUCACIÓN INICIAL
#
# El texto sale de los formatos del MPPE que entregó Daniel el 11 de septiembre
# de 2026 (`DOCs/209_CertificadoEduI`).
#
# ## ⚠️ Acá NO hay literal, y esa es la diferencia grande con primaria
#
# En Educación Inicial la calificación es un TEXTO —no hay nota, ni escala, ni
# promedio (ver `docs/specs/educacion-inicial.md`)— y el formato del ministerio
# lo refleja: no tiene dónde poner una calificación. Solo dice qué grupo cursó y
# en qué período.
#
# ## ⚠️ «Nivel» en SIGA, «Grupo» en el papel
#
# SIGA llama a los grados de Inicial «1er Nivel», «2do Nivel» y «3er Nivel»,
# porque así los nombra el catálogo oficial de grados (`GradoOficial`). El
# formato del MPPE los llama «I, II y III Grupo de la Etapa Preescolar». Es el
# mismo niño en el mismo año: lo que cambia es cómo lo nombra cada papel, y el
# documento tiene que decirlo como lo dice el ministerio.
class DocumentoDeInicial
  # ⚠️ La Etapa Preescolar son TRES grupos, y no es configurable: lo fija el
  # currículo de Educación Inicial. Es la misma razón por la que
  # `DocumentoDePrimaria::ULTIMO_GRADO` está escrito y no se deduce de qué
  # grados haya cargado el colegio — un plantel que todavía no creó el 3er
  # Nivel le habría emitido la certificación final a un niño de I Grupo.
  ULTIMO_GRUPO = 3

  # La etapa que cubren esos tres grupos. La otra —Maternal— SIGA no la modela:
  # `GradoOficial` tiene los tres niveles de preescolar y nada más.
  ETAPA = "Preescolar".freeze

  # A dónde continúa quien termina. No es un grado de este colegio: es el nivel
  # siguiente del sistema, y el formato lo trae impreso así, en mayúscula.
  DESPUES_DE_INICIAL = "el 1ER. GRADO del Nivel de Educación Primaria".freeze

  # Los grupos se numeran en ROMANO en el formato del ministerio.
  ROMANOS = { 1 => "I", 2 => "II", 3 => "III" }.freeze

  # Cómo se llama cada papel, para la pantalla y para la auditoría.
  NOMBRES = {
    "certificacion" => "Certificación de Estudios de Educación Inicial",
    "prosecucion" => "Constancia de Prosecución de Educación Inicial"
  }.freeze

  # ⚠️ El papel lo decide el GRUPO, y se puede preguntar sin un niño delante:
  # ver `DocumentoDePrimaria.tipo_para`, que es su gemelo.
  def self.tipo_para(grado) = numero_de(grado) == ULTIMO_GRUPO ? "certificacion" : "prosecucion"

  # ⚠️ El número sale del NOMBRE del grado: «3er Nivel» → 3.
  #
  # Y ante la duda —un nombre sin número— se emite la CONSTANCIA, que es el
  # documento de todos los años. La certificación, que dice que el niño pasa a
  # primaria, es la que no se puede emitir de más.
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

  # ⚠️ Solo para Educación Inicial. A un alumno de primaria le toca su propio
  # par de documentos, y a uno de bachillerato la certificación 31059.
  def emitible? = @grado.preescolar?

  def datos
    {
      "tipo" => tipo,
      "plantel" => plantel,
      "estudiante" => estudiante,
      "grupo" => grupo,
      "etapa" => ETAPA,
      "periodo" => @seccion.academic_period.name,
      "continua_en" => (DESPUES_DE_INICIAL if ultimo_grupo?),
      "expedida_en" => expedida_en,
      "firmante" => firmante
    }
  end

  private

  # Quien termina el III Grupo recibe la CERTIFICACIÓN de estudios; los otros
  # dos, la CONSTANCIA de prosecución entre grupos.
  def tipo = self.class.tipo_para(@grado)

  def ultimo_grupo? = numero == ULTIMO_GRUPO

  # «III», que es como lo escribe el formato del ministerio.
  def grupo = ROMANOS.fetch(numero, numero.to_s)

  def numero = @numero ||= self.class.numero_de(@grado)

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
      # ⚠️ El formato pide la CÉDULA ESCOLAR, que es justamente la que tiene un
      # niño de preescolar: la de identidad no la tiene todavía. Si por lo que
      # sea hay documento, se muestra ese — el papel no puede salir en blanco.
      "identificador" => persona.cedula_escolar.presence || persona.documento_a_la_vista,
      "lugar_de_nacimiento" => persona.birth_place,
      "fecha_de_nacimiento" => (I18n.l(persona.birth_date, format: :long) if persona.birth_date)
    }
  end

  # Dónde se expide: la ciudad del plantel. Es lo que el formato pide en
  # «Constancia que se expide en ___».
  def expedida_en = @colegio.municipio.presence || @colegio.location

  # ⚠️ Quien firma llega como el REGISTRO del director (`Admin`), y el nombre es
  # de su PERSONA (`User`).
  #
  # Hasta el 1 de octubre de 2026 este método le pedía `nombre_completo` a lo
  # que recibiera, y `DocumentosOficialesController` le pasaba el `Admin` —que
  # no lo tiene—: emitir el documento de Inicial desde la ficha levantaba un
  # `NoMethodError` en cualquier colegio CON director cargado, o sea en todos
  # los de verdad. Solo funcionaba sin director, que es como lo probaba el único
  # test que había — el del armador, que no pasa por el controlador.
  #
  # Lo destapó la pestaña de certificados, que emite por el mismo camino.
  def firmante
    return @firmante if @firmante.is_a?(Hash)

    persona = @firmante.respond_to?(:user) ? @firmante.user : @firmante
    return nil if persona.nil?

    { "nombre" => persona.nombre_completo, "documento" => persona.identificador_a_la_vista }
  end
end
