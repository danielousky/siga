# Lo que comparten los dos intérpretes de planilla (MOR-126).
#
# `MatriculaInterpretada` lee alumnos y `PensumInterpretado` lee materias, pero
# las dos planillas nombran secciones, traen personas con cédula y necesitan
# distinguir un ERROR —la fila no se carga— de un AVISO —se carga, pero alguien
# tiene que enterarse—.
#
# Vive acá y no copiado en los dos porque la resolución de secciones ya costó
# tres intentos, y tenerla en dos lugares garantiza que el cuarto arregle uno
# solo.
module InterpretaLaPlanilla
  extend ActiveSupport::Concern

  # Una fila entendida. Guarda el número ORIGINAL del archivo porque es lo único
  # que le sirve a quien tiene que ir a corregirla: «la fila 47», no «el
  # registro 43».
  class Fila
    attr_reader :numero, :errores, :avisos
    attr_accessor :seccion_texto, :seccion

    def initialize(numero:)
      @numero = numero
      @errores = []
      @avisos = []
    end

    # Cómo se llama esta fila en pantalla: el alumno en una matrícula, la
    # materia y su profesor en un pensum. La usan las tablas de rechazos y
    # avisos, que son las mismas para las dos planillas.
    def etiqueta = ""

    def cargable? = errores.empty?
    def limpia? = errores.empty? && avisos.empty?

    def error(texto) = errores << texto
    def aviso(texto) = avisos << texto
  end

  # Lo que las dos planillas necesitan antes de leer una sola fila: contra qué
  # colegio, qué año escolar y qué secciones se está comparando.
  def preparar(planilla:, mapeo:, colegio:, periodo: nil)
    @planilla = planilla
    @mapeo = mapeo.to_h { |encabezado, clave| [ clave.to_s, encabezado ] }
    @colegio = colegio
    @periodo = periodo || AcademicPeriod.vigente
    @grados = Grade.where(school: colegio).to_a

    # ⚠️ Las secciones se buscan DENTRO del año escolar, no en todos.
    #
    # Un colegio tiene «1er Año A» en cada año que lleva abierto. Buscando sin
    # filtrar, la primera que aparece gana — y podía ser la del año pasado
    # mientras una sección nueva se creaba en el que viene. La importación
    # quedaba partida entre dos años, sin que nadie lo viera.
    @secciones = @periodo ? Section.includes(:grade).where(grade: @grados, academic_period: @periodo).to_a : []
  end

  def cargables  = filas.select(&:cargable?)
  def rechazadas = filas.reject(&:cargable?)
  def con_avisos = cargables.reject { |f| f.avisos.empty? }

  # Las secciones que nombra la planilla, agrupadas y CON SU CONTEO.
  #
  # ⚠️ Se agrupa por la sección a la que APUNTAN, no por cómo están escritas.
  #
  # `1er Año A`, `1ER AÑO / A` y `1er Año Á` son la misma sección: `partir` las
  # resuelve todas al mismo grado y nombre. Agrupando por el texto crudo salían
  # como tres secciones distintas, con tres botones «Crear 1er Año A» que hacen
  # lo mismo — y el tercero, después de apretar el primero, ya no hacía nada.
  #
  # Las variantes de escritura no se pierden: van en `tambien`, porque que la
  # planilla escriba «1er Año Á» es algo que el colegio querrá corregir aunque
  # SIGA lo entienda igual. La que se muestra de principal es la que MÁS SE
  # REPITE —no la primera del abecedario, que dejaba «1ER AÑO / A» de titular y
  # la escritura limpia de variante— y a igual conteo, la que aparece antes en
  # el archivo.
  #
  # ⚠️ El conteo no es decorativo: es lo que delata el error de tipeo. «1er Año
  # C · 18 alumnos» es una sección; «1er Año K · 1» es un dedazo, y verlos uno al
  # lado del otro lo hace obvio antes de crear basura.
  #
  # Se llama `cuantas` y no `alumnos` porque en la planilla de pensum son
  # materias — y usarlo de capacidad de la sección, como se usa en matrícula,
  # daría un aula para ocho personas.
  def secciones_de_la_planilla
    filas.reject { |f| f.seccion_texto.blank? }
         .group_by { |f| identidad_de_seccion(f.seccion_texto) }
         .map do |(grado, nombre), de_esa|
           escrituras = de_esa.group_by(&:seccion_texto)
                              .sort_by { |_, filas| [ -filas.size, filas.first.numero ] }
                              .map(&:first)

           { texto: escrituras.first, tambien: escrituras.drop(1), cuantas: de_esa.size,
             seccion: buscar_seccion(grado, nombre), grado: grado, nombre_de_seccion: nombre }
         end.sort_by { |s| s[:texto] }
  end

  def secciones_que_faltan = secciones_de_la_planilla.reject { |s| s[:seccion] }

  private

  def valor(cruda, clave)
    encabezado = @mapeo[clave.to_s]
    encabezado.present? ? cruda[encabezado] : nil
  end

  def valores_de(clave)
    encabezado = @mapeo[clave.to_s]
    return [] if encabezado.blank?

    @planilla.filas.map { |f| f[encabezado] }
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
  # ni espacios: así `1er Año A`, `1erAño-A` y `1ER AÑO / A` dan lo mismo. Lo que
  # sobra es el nombre de la sección.
  #
  # Gana el nombre más largo para que `10mo Grado` no se lo coma `1er Grado`
  # cuando los dos empiezan parecido.
  def partir(texto)
    comparable = Normaliza.limpiar(texto).delete(" ")

    grado = @grados
              .select { |g| comparable.start_with?(Normaliza.limpiar(g.name).delete(" ")) }
              .max_by { |g| g.name.length }

    return [ nil, nil ] unless grado

    resto = comparable.delete_prefix(Normaliza.limpiar(grado.name).delete(" "))
    [ grado, resto.gsub(/\A[^a-z0-9]+/, "").upcase.presence ]
  end

  # Cómo se agrupan dos escrituras: por el grado y la sección a los que apuntan.
  #
  # Cuando no hay ningún grado que se parezca no hay identidad que compartir, así
  # que cada texto queda solo — si no, «Preescolar B» y «basura» se sumarían en
  # una misma fila inexistente.
  def identidad_de_seccion(texto)
    grado, nombre = partir(texto)

    grado ? [ grado, nombre ] : [ nil, texto ]
  end

  def buscar_seccion(grado, nombre)
    return nil if grado.nil? || nombre.blank?

    @secciones.find do |s|
      s.grade_id == grado.id &&
        Normaliza.limpiar(s.name).delete(" ") == Normaliza.limpiar(nombre).delete(" ")
    end
  end

  # ── las personas ──────────────────────────────────────────────────────────

  # El tipo de documento sale del propio número: `V-31.222.333` es una cédula
  # venezolana y `E-…` la de un extranjero residente. La planilla no trae una
  # columna aparte para eso, y pedirla sería pedir un dato que ya está escrito.
  def documento_y_tipo(crudo)
    texto = crudo.to_s.strip
    tipo = texto.match?(/\A\s*E/i) ? :cedula_e : :cedula_v

    [ User.normalizar_documento(texto, tipo), tipo ]
  end

  # ⚠️ La cédula ya está registrada, pero a nombre de alguien que se llama muy
  # distinto.
  #
  # Pasó de verdad: la planilla traía a «MARÍN GONZÁLEZ MARÍA» con la cédula
  # 12.345.678, que en SIGA era la del profesor Carlos García. El importador la
  # encontró —hace bien, se busca por cédula— y le sobrescribió el nombre. El
  # profesor dejó de llamarse como se llama.
  #
  # Buscar por cédula es correcto y no se toca: es lo que hace que una persona
  # con rol en dos colegios sea una sola. Lo que faltaba era NOTARLO.
  def avisar_si_la_cedula_es_de_otra_persona(fila, datos, quien)
    return if datos[:document].blank?

    existente = Current.sin_aislamiento { User.find_by(document: datos[:document]) }
    return if existente.nil?
    return if se_parecen?(existente, datos)

    fila.aviso("#{quien} tiene la cédula #{datos[:document]}, que en SIGA es de " \
               "#{existente.nombre_completo}. Confirme que es la misma persona.")
  end

  # Alcanza con que compartan el primer apellido o el primer nombre: la planilla
  # de un colegio abrevia, invierte y escribe mal, pero no cambia a la persona.
  # Y 360 avisos son cero avisos.
  def se_parecen?(existente, datos)
    de_la_planilla = [ datos[:first_name], datos[:last_name] ].compact_blank.map { |n| Normaliza.limpiar(n) }
    en_siga = [ existente.first_name, existente.last_name, existente.second_last_name ]
                .compact_blank.map { |n| Normaliza.limpiar(n) }

    de_la_planilla.any? { |n| en_siga.any? { |e| e.include?(n) || n.include?(e) } }
  end
end
