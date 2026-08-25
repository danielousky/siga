# La planilla, ya entendida: quién es cada alumno y qué le falta (MOR-126).
#
# Toma las filas crudas más el mapeo y devuelve, por cada una, los datos listos
# para crear al alumno, a su representante y su inscripción — con lo que está
# mal marcado en el sitio donde está mal.
#
# ## La distinción que ordena todo: ERROR vs AVISO
#
#   ERROR   la fila NO se puede cargar. Falta algo sin lo cual el registro no
#           existiría: el nombre, cualquier identificador, la sección.
#   AVISO   la fila SÍ se carga, pero alguien tiene que enterarse. El
#           representante sin correo no va a poder consultar nada; un nombre de
#           cinco palabras puede estar mal partido.
#
# Confundirlas es lo que hace inservible a un importador. Si todo es error, un
# colegio con 45 representantes sin correo no puede importar nada. Si todo es
# aviso, se cargan alumnos sin nombre.
class MatriculaInterpretada
  include InterpretaLaPlanilla

  # Cómo se nombra una fila de esta planilla, para los textos compartidos.
  QUE_ES_UNA_FILA = %w[alumno alumnos].freeze
  COLUMNA_DE_FILA = "Alumno".freeze

  # La fila de una matrícula: además de lo común, un alumno y su representante.
  class Fila < InterpretaLaPlanilla::Fila
    attr_reader :alumno, :representante
    attr_accessor :parentesco, :carnet

    def initialize(numero:)
      super
      @alumno = {}
      @representante = {}
    end

    def nombre_del_alumno
      [ alumno[:first_name], alumno[:last_name], alumno[:second_last_name] ].compact_blank.join(" ")
    end

    def etiqueta = nombre_del_alumno
  end

  attr_reader :filas

  attr_reader :periodo

  def initialize(planilla:, mapeo:, colegio:, periodo: nil)
    preparar(planilla: planilla, mapeo: mapeo, colegio: colegio, periodo: periodo)

    # El sexo se decide con la COLUMNA entera, no celda por celda: `H` es
    # femenino junto a `V` y masculino junto a `M`. Ver `Normaliza.sexos`.
    @sexos = Normaliza.sexos(valores_de(:sexo))

    @filas = @planilla.filas.map { |cruda| interpretar(cruda) }
  end

  # Cuántas fechas se leerían distinto en un Excel en inglés. No es un error:
  # es una pregunta que hay que hacerle al colegio antes de cargar.
  def fechas_ambiguas = @fechas_ambiguas.to_i

  def representantes_sin_correo
    cargables.count { |f| f.representante[:email].blank? }
  end

  private

  def interpretar(cruda)
    fila = Fila.new(numero: cruda.numero)

    leer_alumno(fila, cruda)
    leer_representante(fila, cruda)
    leer_seccion(fila, cruda)

    fila
  end

  # ── el alumno ─────────────────────────────────────────────────────────────

  def leer_alumno(fila, cruda)
    encabezado = @mapeo["nombre_completo"]
    nombre = NombreDePersona.new(valor(cruda, :nombre_completo),
                                 apellidos_primero: NombreDePersona.apellidos_primero?(encabezado))

    return fila.error("Sin nombre") if nombre.vacio?

    fila.alumno.merge!(nombre.to_h)
    fila.aviso("Nombre: #{nombre.motivo}") unless nombre.seguro?

    leer_documentos(fila, cruda)
    leer_nacimiento(fila, cruda)
    avisar_si_la_cedula_es_de_otra_persona(fila, fila.alumno, "El alumno")
    fila.alumno[:sex] = @sexos[Normaliza.limpiar(valor(cruda, :sexo))]

    # El carnet lo numera el colegio y la planilla casi nunca lo trae. Si viene,
    # se respeta; si no, lo genera la carga.
    fila.carnet = valor(cruda, :carnet).to_s.strip.presence
  end

  # El tipo de documento sale del propio número: `V-31.222.333` es una cédula
  # venezolana y `E-...` la de un extranjero residente. La planilla no trae una
  # columna aparte para eso y pedirla sería pedir un dato que ya está escrito.
  def leer_documentos(fila, cruda)
    documento, tipo = documento_y_tipo(valor(cruda, :documento))

    fila.alumno[:document] = documento
    fila.alumno[:document_type] = tipo if documento.present?
    fila.alumno[:cedula_escolar] = User.normalizar_cedula_escolar(valor(cruda, :cedula_escolar))

    return if fila.alumno[:document].present? || fila.alumno[:cedula_escolar].present?

    # Sin ninguno de los dos el modelo no deja crear a la persona, y con razón:
    # nadie sin identificador puede aparecer en una planilla del MPPE.
    fila.error("Sin cédula de identidad ni cédula escolar")
  end

  def leer_nacimiento(fila, cruda)
    fecha = FechaDePlanilla.new(valor(cruda, :fecha_de_nacimiento))

    @fechas_ambiguas = @fechas_ambiguas.to_i + 1 if fecha.ambigua?

    return if fecha.vacia?
    return fila.aviso("Fecha de nacimiento: #{fecha.motivo}") unless fecha.valida?

    fila.alumno[:birth_date] = fecha.fecha
  end

  # ── el representante ──────────────────────────────────────────────────────

  def leer_representante(fila, cruda)
    encabezado = @mapeo["representante"]
    nombre = NombreDePersona.new(valor(cruda, :representante),
                                 apellidos_primero: NombreDePersona.apellidos_primero?(encabezado))

    return fila.error("Sin representante") if nombre.vacio?

    fila.representante.merge!(nombre.to_h)
    fila.aviso("Representante: #{nombre.motivo}") unless nombre.seguro?

    documento, tipo = documento_y_tipo(valor(cruda, :cedula_del_representante))

    return fila.error("El representante no trae cédula") if documento.blank?

    fila.representante[:document] = documento
    fila.representante[:document_type] = tipo
    fila.representante[:email] = Normaliza.correo(valor(cruda, :correo_del_representante))
    fila.representante[:phone] = Normaliza.telefono(valor(cruda, :telefono_del_representante))

    avisar_si_la_cedula_es_de_otra_persona(fila, fila.representante, "El representante")

    avisar_por_el_correo(fila, cruda)
    fila.parentesco = leer_parentesco(cruda)
  end

  # Sin correo la fila entra igual —es la decisión de `MOR-142`— pero el colegio
  # tiene que salir de acá sabiendo a quién le falta.
  def avisar_por_el_correo(fila, cruda)
    return if fila.representante[:email].present?

    crudo = valor(cruda, :correo_del_representante).to_s.strip

    if crudo.present?
      fila.aviso("El correo «#{crudo.truncate(30)}» no es válido: se deja vacío")
    else
      fila.aviso("El representante no tiene correo: no va a poder consultar las notas")
    end
  end

  PARENTESCOS = {
    "madre" => :madre, "mama" => :madre, "padre" => :padre, "papa" => :padre,
    "representante" => :representante, "representante legal" => :representante,
    "tio" => :otro, "tia" => :otro, "abuelo" => :otro, "abuela" => :otro, "otro" => :otro
  }.freeze

  def leer_parentesco(cruda)
    PARENTESCOS.fetch(Normaliza.limpiar(valor(cruda, :parentesco)), :representante)
  end
end
