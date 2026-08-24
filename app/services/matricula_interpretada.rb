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
  # Una fila, entendida. Guarda el número ORIGINAL del archivo porque es lo
  # único que le sirve a quien tiene que ir a corregirla.
  class Fila
    attr_reader :numero, :alumno, :representante, :errores, :avisos
    attr_accessor :parentesco, :seccion_texto, :seccion

    def initialize(numero:)
      @numero = numero
      @errores = []
      @avisos = []
      @alumno = {}
      @representante = {}
    end

    def cargable? = errores.empty?
    def limpia? = errores.empty? && avisos.empty?

    def nombre_del_alumno
      [ alumno[:first_name], alumno[:last_name], alumno[:second_last_name] ].compact_blank.join(" ")
    end

    def error(texto)  = errores << texto
    def aviso(texto)  = avisos  << texto
  end

  attr_reader :filas

  def initialize(planilla:, mapeo:, colegio:)
    @planilla = planilla
    @mapeo = mapeo.to_h { |encabezado, clave| [ clave.to_s, encabezado ] }
    @colegio = colegio
    @grados = Grade.where(school: colegio).to_a
    @secciones = Section.includes(:grade).where(grade: @grados).to_a

    # El sexo se decide con la COLUMNA entera, no celda por celda: `H` es
    # femenino junto a `V` y masculino junto a `M`. Ver `Normaliza.sexos`.
    @sexos = Normaliza.sexos(valores_de(:sexo))

    @filas = @planilla.filas.map { |cruda| interpretar(cruda) }
  end

  # ── los resúmenes que necesita la pantalla ────────────────────────────────

  def cargables   = filas.select(&:cargable?)
  def rechazadas  = filas.reject(&:cargable?)
  def con_avisos  = cargables.reject { |f| f.avisos.empty? }

  # Las secciones que nombra la planilla, agrupadas y CON SU CONTEO.
  #
  # ⚠️ El conteo no es decorativo: es lo que delata el error de tipeo. «1er Año
  # A · 20 alumnos» es una sección; «1er Año Á · 1 alumno» es un dedazo, y
  # verlos uno al lado del otro lo hace obvio antes de crear basura.
  def secciones_de_la_planilla
    filas.group_by(&:seccion_texto).filter_map do |texto, filas_de_esa|
      next if texto.blank?

      grado, nombre = partir(texto)

      {
        texto: texto,
        alumnos: filas_de_esa.size,
        seccion: buscar_seccion(grado, nombre),
        grado: grado,
        nombre_de_seccion: nombre
      }
    end.sort_by { |s| s[:texto] }
  end

  def secciones_que_faltan = secciones_de_la_planilla.reject { |s| s[:seccion] }

  # Cuántas fechas se leerían distinto en un Excel en inglés. No es un error:
  # es una pregunta que hay que hacerle al colegio antes de cargar.
  def fechas_ambiguas = @fechas_ambiguas.to_i

  def representantes_sin_correo
    cargables.count { |f| f.representante[:email].blank? }
  end

  private

  def valores_de(clave)
    encabezado = @mapeo[clave.to_s]
    return [] if encabezado.blank?

    @planilla.filas.map { |f| f[encabezado] }
  end

  def valor(cruda, clave)
    encabezado = @mapeo[clave.to_s]
    encabezado.present? ? cruda[encabezado] : nil
  end

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
    fila.alumno[:sex] = @sexos[Normaliza.limpiar(valor(cruda, :sexo))]
  end

  # El tipo de documento sale del propio número: `V-31.222.333` es una cédula
  # venezolana y `E-...` la de un extranjero residente. La planilla no trae una
  # columna aparte para eso y pedirla sería pedir un dato que ya está escrito.
  def leer_documentos(fila, cruda)
    crudo = valor(cruda, :documento).to_s.strip
    tipo = crudo.match?(/\A\s*E/i) ? :cedula_e : :cedula_v

    fila.alumno[:document] = User.normalizar_documento(crudo, tipo)
    fila.alumno[:document_type] = tipo if fila.alumno[:document].present?
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

    crudo = valor(cruda, :cedula_del_representante).to_s.strip
    tipo = crudo.match?(/\A\s*E/i) ? :cedula_e : :cedula_v
    documento = User.normalizar_documento(crudo, tipo)

    return fila.error("El representante no trae cédula") if documento.blank?

    fila.representante[:document] = documento
    fila.representante[:document_type] = tipo
    fila.representante[:email] = Normaliza.correo(valor(cruda, :correo_del_representante))
    fila.representante[:phone] = Normaliza.telefono(valor(cruda, :telefono_del_representante))

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

  # ── la sección ────────────────────────────────────────────────────────────

  def leer_seccion(fila, cruda)
    texto = valor(cruda, :seccion).to_s.strip.gsub(/\s+/, " ")
    fila.seccion_texto = texto

    return fila.error("Sin sección") if texto.blank?

    grado, nombre = partir(texto)
    seccion = buscar_seccion(grado, nombre)

    if seccion
      fila.seccion = seccion
    elsif grado
      fila.error("La sección «#{texto}» no existe todavía")
    else
      fila.error("No hay ningún grado que se llame como «#{texto}»")
    end
  end

  # `"1er Año A"` → el grado `1er Año` y la sección `A`.
  #
  # Se busca el grado cuyo nombre sea PREFIJO del texto, comparando sin acentos
  # ni espacios: así `1er Año A`, `1erAño-A` y `1ER AÑO / A` dan lo mismo. Lo
  # que sobra es el nombre de la sección.
  #
  # Se ordena por largo descendente para que `10mo Grado` gane sobre `1er
  # Grado` cuando los dos empiezan parecido.
  def partir(texto)
    comparable = Normaliza.limpiar(texto).delete(" ")

    grado = @grados
              .select { |g| comparable.start_with?(Normaliza.limpiar(g.name).delete(" ")) }
              .max_by { |g| g.name.length }

    return [ nil, nil ] unless grado

    resto = comparable.delete_prefix(Normaliza.limpiar(grado.name).delete(" "))
    [ grado, resto.gsub(/\A[^a-z0-9]+/, "").upcase.presence ]
  end

  def buscar_seccion(grado, nombre)
    return nil if grado.nil? || nombre.blank?

    @secciones.find do |s|
      s.grade_id == grado.id && Normaliza.limpiar(s.name).delete(" ") == Normaliza.limpiar(nombre).delete(" ")
    end
  end
end
