# La planilla de materias y profesores, ya entendida (MOR-126, tanda 2).
#
# Una fila es **una materia dictada en una sección**, y de ahí salen cuatro
# cosas: la materia, el pensum del grado, el profesor y su asignación.
#
# La misma materia aparece tantas veces como secciones la tengan, y el mismo
# profesor tantas veces como materias dicte. Eso no es redundancia de la
# planilla: es su forma natural, y el importador la aprovecha en vez de pedirle
# al colegio que la normalice antes de mandarla.
class PensumInterpretado
  include InterpretaLaPlanilla

  QUE_ES_UNA_FILA = %w[materia materias].freeze
  COLUMNA_DE_FILA = "Área y profesor".freeze

  # Cuando el colegio no maneja departamentos. Es un agrupador de listados, no
  # un dato académico, así que inventar uno vacío es mejor que exigirlo.
  DEPARTAMENTO_POR_DEFECTO = "General".freeze

  class Fila < InterpretaLaPlanilla::Fila
    attr_accessor :materia, :codigo, :departamento, :codigo_generado
    attr_reader :profesor

    def initialize(numero:)
      super
      @profesor = {}
    end

    # En Tipo Título, como TODOS los nombres de la app. Ver `MatriculaInterpretada::Fila`.
    def nombre_del_profesor
      Normaliza.titulo([ profesor[:first_name], profesor[:last_name], profesor[:second_last_name] ]
                         .compact_blank.join(" "))
    end

    def etiqueta = [ materia, nombre_del_profesor ].compact_blank.join(" · ")
  end

  attr_reader :filas, :periodo

  def initialize(planilla:, mapeo:, colegio:, periodo: nil)
    preparar(planilla: planilla, mapeo: mapeo, colegio: colegio, periodo: periodo)

    @filas = @planilla.filas.map { |cruda| interpretar(cruda) }
    avisar_de_los_choques
  end

  # ── los resúmenes de esta planilla ────────────────────────────────────────

  # Cuántas materias distintas trae, no cuántas filas: una materia en cinco
  # secciones son cinco filas y una sola materia.
  def materias_distintas
    cargables.map { |f| f.codigo }.uniq.size
  end

  def profesores_distintos
    cargables.filter_map { |f| f.profesor[:document] }.uniq.size
  end

  # Las materias cuyo código lo inventó SIGA porque la planilla no lo traía.
  # Se listan para que el colegio los revise: el código es lo que identifica a
  # la materia dentro del colegio, y uno inventado puede chocar con su
  # nomenclatura.
  def codigos_generados
    cargables.select(&:codigo_generado).map { |f| [ f.materia, f.codigo ] }.uniq
  end

  private

  # ⚠️ Una sección tiene UN profesor por materia, y la propia planilla lo delata.
  #
  # Antes esto solo salía DESPUÉS de escribir, en el reporte de fallidas: el
  # colegio confirmaba, se cargaba todo, y recién ahí se enteraba de que una fila
  # había quedado fuera. La planilla ya tiene la información —dos filas con la
  # misma sección y materia y distinto profesor— así que se dice antes.
  #
  # Es un AVISO y no un error: la fila igual se carga si es la primera, y forzar
  # a corregir la planilla para poder importar sería peor que cargar 359 filas y
  # señalar la que sobra.
  def avisar_de_los_choques
    cargables.group_by { |f| [ f.seccion&.id, f.codigo ] }.each_value do |mismas|
      primera = mismas.first
      next if mismas.size < 2

      mismas.drop(1).each do |repetida|
        next if repetida.profesor[:document] == primera.profesor[:document]

        repetida.aviso("#{primera.materia} en #{etiqueta(primera.seccion)} ya la dicta " \
                       "#{primera.nombre_del_profesor} en la fila #{primera.numero}. " \
                       "Una sección tiene un solo profesor por área, así que esta no se carga.")
      end
    end
  end

  def etiqueta(seccion) = "#{seccion.grade.name} #{seccion.name}"

  def interpretar(cruda)
    fila = Fila.new(numero: cruda.numero)

    leer_seccion(fila, cruda)
    leer_materia(fila, cruda)
    leer_profesor(fila, cruda)

    fila
  end

  # ── la materia ────────────────────────────────────────────────────────────

  def leer_materia(fila, cruda)
    fila.materia = Normaliza.titulo(valor(cruda, :materia))
    return fila.error("Sin materia") if fila.materia.blank?

    fila.departamento = Normaliza.titulo(valor(cruda, :departamento)).presence || DEPARTAMENTO_POR_DEFECTO

    declarado = valor(cruda, :codigo).to_s.strip.upcase.presence
    fila.codigo = declarado || codigo_para(fila.materia)
    fila.codigo_generado = declarado.nil?
  end

  # Palabras que no aportan al código: «Educación **para la** Salud».
  SIN_VALOR = %w[de del la las los y e para por en a al con].freeze

  # ⚠️ Un código generado es un INVENTO de SIGA, no una deducción.
  #
  # Los códigos de un colegio son elecciones humanas y ningún algoritmo las
  # reproduce: en los propios datos de prueba, «Castellano y Literatura» es
  # `LEN` e «Historia de Venezuela» es `HIS`. Por eso lo importante no es
  # acertar —no se puede— sino **avisar**: `codigos_generados` los lista en la
  # previsualización para que el colegio los revise antes de confirmar.
  #
  # La regla es las tres primeras letras de la primera palabra con valor, más la
  # inicial de cada palabra siguiente:
  #
  #     Matemática              → MAT
  #     Educación Física        → EDUF
  #     Ciencias Naturales      → CIEN
  #     Ciencias Sociales       → CIES     ← y por eso no basta con las tres
  #     Educación para la Salud → EDUS
  def codigo_para(nombre)
    @por_nombre ||= {}
    @por_nombre[Normaliza.limpiar(nombre)] ||= begin
      palabras = Normaliza.limpiar(nombre).split(" ").reject { |p| SIN_VALOR.include?(p) }
      base = palabras.empty? ? "MAT" : palabras.first[0, 3] + palabras.drop(1).map { |p| p[0] }.join

      libre(base.upcase[0, 10], nombre)
    end
  end

  # `subjects.code` es único dentro del colegio, así que dos materias DISTINTAS
  # con el mismo código generado harían fallar la segunda al guardar, con un
  # error de base de datos en vez de un aviso. Se resuelve acá, mientras todavía
  # se puede mostrar en pantalla.
  #
  # ⚠️ Chocar y coincidir no son lo mismo. Si el colegio ya tiene `MAT` y se
  # llama «Matemática», la planilla que trae «Matemática» tiene que REUTILIZARLO
  # —es la misma materia, y reimportar es el caso normal—. Solo se busca otro
  # código cuando el que está ocupado pertenece a una materia con otro nombre.
  def libre(base, nombre)
    @ocupados ||= Subject.where(school: @colegio)
                         .pluck(:code, :name)
                         .to_h { |codigo, suyo| [ codigo, Normaliza.limpiar(suyo) ] }

    codigo = base
    sufijo = 1
    codigo = "#{base}#{sufijo += 1}" while @ocupados[codigo] && @ocupados[codigo] != Normaliza.limpiar(nombre)

    @ocupados[codigo] = Normaliza.limpiar(nombre)
    codigo
  end

  # ── el profesor ───────────────────────────────────────────────────────────

  def leer_profesor(fila, cruda)
    encabezado = @mapeo["profesor"]
    nombre = NombreDePersona.new(valor(cruda, :profesor),
                                 apellidos_primero: NombreDePersona.apellidos_primero?(encabezado))

    return fila.error("Sin profesor") if nombre.vacio?

    fila.profesor.merge!(nombre.to_h)
    fila.aviso("Profesor: #{nombre.motivo}") unless nombre.seguro?

    documento, tipo = documento_y_tipo(valor(cruda, :cedula_del_profesor))
    return fila.error("El profesor no trae cédula") if documento.blank?

    fila.profesor[:document] = documento
    fila.profesor[:document_type] = tipo

    leer_correo(fila, cruda)
    avisar_si_la_cedula_es_de_otra_persona(fila, fila.profesor, "El profesor")
  end

  # ⚠️ Acá está la diferencia con la matrícula, y es del modelo, no una
  # preferencia.
  #
  # A un representante se le puede cargar sin correo: queda sin poder consultar
  # las notas y el reporte lo lista. Un profesor NO: el concern `EntraAlSistema`
  # exige el correo, porque un profesor que no entra al sistema no puede cargar
  # notas, que es lo único que viene a hacer.
  #
  # Así que acá es un ERROR y no un aviso — la fila no se puede cargar.
  def leer_correo(fila, cruda)
    correo = Normaliza.correo(valor(cruda, :correo_del_profesor))

    if correo.present?
      fila.profesor[:email] = correo
      return
    end

    crudo = valor(cruda, :correo_del_profesor).to_s.strip

    if crudo.present?
      fila.error("El correo «#{crudo.truncate(30)}» no es válido, y el profesor lo necesita para entrar")
    else
      fila.error("El profesor no tiene correo, y sin él no puede entrar a cargar notas")
    end
  end
end
