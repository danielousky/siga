# Lee la planilla que trae el colegio y la deja en filas con nombre (MOR-126).
#
# No sabe nada de alumnos ni de representantes: solo convierte un archivo que
# hizo una persona en datos que un programa puede recorrer. Lo que significa
# cada columna lo decide el mapeo, que es otro paso.
#
# ## Por qué no alcanza con `hoja.row(1)`
#
# Una planilla de colegio real no empieza en la fila 1. Empieza así:
#
#     fila 1   U.E. COLEGIO SAN JOSÉ
#     fila 2   MATRÍCULA 2025-2026
#     fila 3   (vacía)
#     fila 4   Nº · APELLIDOS Y NOMBRES · C.I. · AÑO/SECC · …   ← el encabezado
#     fila 5   1 · DE LA CRUZ MARÍN JOSÉ LUIS · …
#     fila 8   · SUBTOTAL 1er AÑO ·                             ← basura en el medio
#
# Asumir que el encabezado es la primera fila deja al colegio con una columna
# llamada "U.E. COLEGIO SAN JOSÉ" y 3 filas de más. Por eso se BUSCA.
class Planilla
  # Extensiones que roo sabe abrir. El `.xls` de Excel 97-2003 no es un caso
  # exótico acá: el sistema que usan hoy la mayoría de los colegios venezolanos
  # es de escritorio y con 25 años encima, así que es lo que exporta.
  EXTENSIONES = %w[.xlsx .xls .csv .ods].freeze

  # Cuántas filas mirar buscando el encabezado antes de rendirse. Veinte cubre
  # cualquier membrete razonable; más allá, lo que hay no es una planilla.
  FILAS_A_INSPECCIONAR = 20

  # ⚠️ Un CSV no dice con qué está separado, y Excel no usa coma.
  #
  # Un Excel configurado en español guarda con **punto y coma**, porque la coma
  # ya es el separador decimal. Numbers exporta con tabulaciones. Asumiendo coma,
  # el archivo entero se lee como UNA columna, ninguna fila «parece encabezado»
  # y el colegio recibe «no encontré la fila de encabezados» sobre un archivo que
  # está perfectamente bien.
  #
  # Y no es un caso de borde: es lo que sale de abrir un CSV en Excel y volver a
  # guardarlo, que es exactamente lo que hace una secretaria antes de mandarlo.
  DELIMITADORES = [ ",", ";", "\t", "|" ].freeze

  # Cuánto se mira para adivinar separador y codificación.
  MUESTRA = 64 * 1024

  # ⚠️ El BOM se le pega al PRIMER encabezado y lo vuelve irreconocible.
  #
  # «NOMBRE» con marca delante no es «NOMBRE» para nadie: el mapeo automático
  # falla en esa columna y en ninguna otra, que es peor que fallar entero porque
  # no se nota.
  #
  # Van las DOS formas y no una: si el archivo trae marca de UTF-8 con contenido
  # que no lo es —Excel produce esa quimera— los tres bytes se leen como `ï»¿`,
  # tres caracteres de texto normal, y `\uFEFF` no los toca.
  BOM = /\A(?:\uFEFF|ï»¿)/

  class NoSePuedeLeer < StandardError; end

  attr_reader :fila_de_encabezado, :encabezados

  def initialize(ruta, extension: nil)
    @ruta = ruta.to_s
    @extension = (extension || File.extname(@ruta)).to_s.downcase
    @extension = ".#{@extension}" unless @extension.start_with?(".")

    unless EXTENSIONES.include?(@extension)
      raise NoSePuedeLeer, "No sé leer un archivo #{@extension}. Acepto: #{EXTENSIONES.join(', ')}"
    end

    abrir
    ubicar_encabezado
  end

  # Las filas de datos, cada una como un hash `{ encabezado => valor }`.
  #
  # Ya vienen sin las de basura: el membrete de arriba, los subtotales del medio
  # y las vacías del final.
  def filas
    @filas ||= ((@fila_de_encabezado + 1)..@hoja.last_row).filter_map do |n|
      valores = celdas_de(n)
      next if basura?(valores)

      Fila.new(numero: n, datos: @encabezados.zip(valores).to_h)
    end
  end

  # Las que se descartaron, para poder decir por qué en la previsualización.
  # Un colegio que ve "312 de 316" merece saber cuáles fueron las otras 4.
  def descartadas
    @descartadas ||= ((@fila_de_encabezado + 1)..@hoja.last_row).filter_map do |n|
      valores = celdas_de(n)
      next unless basura?(valores)

      Fila.new(numero: n, datos: @encabezados.zip(valores).to_h)
    end
  end

  def total_de_filas = @hoja.last_row

  # Una fila con su número original, que es lo único que le sirve a quien tiene
  # que ir a corregir su archivo: "la fila 47" y no "el registro 43".
  Fila = Struct.new(:numero, :datos, keyword_init: true) do
    def [](encabezado) = datos[encabezado]
    def vacia? = datos.values.all? { |v| v.to_s.strip.empty? }
  end

  private

  def abrir
    @hoja = Roo::Spreadsheet.open(@ruta, **opciones_para_abrir)
    raise NoSePuedeLeer, "La planilla no tiene ninguna hoja con datos" if @hoja.last_row.to_i.zero?
  rescue NoSePuedeLeer
    raise
  rescue StandardError => e
    # roo levanta cosas muy distintas según el formato. Quien sube un archivo
    # necesita saber que no se pudo leer, no el nombre de la excepción.
    raise NoSePuedeLeer, "No se pudo leer la planilla (#{e.class}). ¿Está dañada o protegida con contraseña?"
  end

  def opciones_para_abrir
    opciones = { extension: @extension.delete(".").to_sym }
    return opciones unless @extension == ".csv"

    opciones.merge(csv_options: opciones_de_csv)
  end

  # El separador y la codificación, adivinados del propio archivo.
  #
  # La codificación se prueba primero porque la otra depende de ella: un archivo
  # en Windows-1252 leído como UTF-8 revienta antes de poder contar comas.
  def opciones_de_csv
    muestra = File.binread(@ruta, MUESTRA).to_s

    # Cortar en el último salto de línea, INCLUYÉNDOLO: la muestra puede partir
    # un carácter multibyte por la mitad y hacer que un UTF-8 válido parezca que
    # no lo es.
    #
    # ⚠️ El `+ 1` no es cosmético. Un archivo de Windows termina cada línea con
    # `\r\n`; cortando justo ANTES del `\n` queda un `\r` suelto al final, y
    # `CSV` lo rechaza con «Unquoted fields do not allow new line». Todos los
    # separadores fallaban igual y ganaba la coma por ser la primera.
    final = muestra.rindex("\n")
    muestra = muestra[0, final + 1] if final

    codificacion = codificacion_de(muestra)
    texto = muestra.dup.force_encoding(codificacion).scrub

    # El `bom|` solo tiene sentido en UTF-8 —un Windows-1252 no lleva BOM— y CSV
    # avisa por consola si se le pide igual.
    marca = codificacion == "utf-8" ? "bom|" : ""

    { col_sep: delimitador_de(texto), encoding: "#{marca}#{codificacion}" }
  end

  # Windows-1252 y no ISO-8859-1: es lo que escribe Excel en Windows, y el
  # superconjunto —tiene las comillas tipográficas y el guion largo que un
  # colegio pega desde Word—.
  def codificacion_de(bytes)
    bytes.dup.force_encoding(Encoding::UTF_8).valid_encoding? ? "utf-8" : "windows-1252"
  end

  # Gana el separador que produce la tabla más ancha.
  #
  # Contar cuántas veces aparece cada carácter no sirve: «GARCÍA PÉREZ, CARLOS»
  # dentro de una celda entrecomillada tiene comas que no separan nada. Lo que sí
  # distingue es el ANCHO que resulta — con el separador correcto todas las filas
  # dan el mismo número de columnas, y con el equivocado dan una.
  def delimitador_de(texto)
    DELIMITADORES.max_by { |separador| ancho_tipico(texto, separador) }
  end

  def ancho_tipico(texto, separador)
    filas = CSV.parse(texto, col_sep: separador).reject { |f| f.compact.empty? }
    return 0 if filas.empty?

    # El ancho que más se repite, y a igualdad de repeticiones el mayor.
    filas.map(&:size).tally.max_by { |ancho, veces| [ veces, ancho ] }.first
  rescue CSV::MalformedCSVError, ArgumentError
    0
  end

  # El encabezado es la primera fila que PARECE un encabezado y además está
  # PEGADA a sus datos. Las dos mitades hacen falta.
  def ubicar_encabezado
    tope = [ @hoja.last_row, FILAS_A_INSPECCIONAR ].min

    (1..tope).each do |n|
      celdas = celdas_de(n)
      next unless parece_encabezado?(celdas)
      next unless pegado_a_sus_datos?(n)

      @fila_de_encabezado = n
      @encabezados = nombrar(celdas)
      return
    end

    raise NoSePuedeLeer,
          "No encontré la fila de encabezados en las primeras #{tope} filas. " \
          "Leí #{ancho} #{ancho == 1 ? 'columna' : 'columnas'}. " \
          "¿La planilla tiene una fila con el nombre de cada columna?"
  end

  # Al menos dos celdas llenas, que cubran la mitad del ancho, y ninguna que sea
  # un número suelto: un encabezado dice cómo se llama la columna, no cuánto
  # vale.
  #
  # El mínimo es DOS y no tres: una planilla de tres columnas donde la primera
  # es "Nº" y viene sin título tiene solo dos encabezados escritos, y es un caso
  # normal, no un archivo roto.
  def parece_encabezado?(celdas)
    n = llenas(celdas)

    n >= 2 && n >= (ancho / 2.0).ceil && celdas.compact_blank.none? { |c| numero_suelto?(c) }
  end

  # ⚠️ Un encabezado está pegado a sus datos. El membrete no.
  #
  # Es lo único que los distingue de verdad, y me costó dos intentos. Un título
  # como `COLEGIO · SAN JOSÉ · MATRÍCULA 2025` cumple todo lo de arriba: tres
  # celdas de texto, ningún número. Lo que NO tiene es una fila de datos
  # inmediatamente debajo — entre el membrete y la tabla siempre hay una línea
  # en blanco, porque quien hizo la planilla la puso ahí para que se viera bien.
  #
  # Buscar datos "en algún lugar más abajo" no sirve: más abajo siempre hay,
  # y por eso la primera versión elegía el membrete.
  #
  # ⚠️ Y no se le pide NADA de densidad a esa fila de datos. Dos intentos me
  # costó llegar acá.
  #
  # La primera versión pedía «una celda menos que el encabezado». La segunda, la
  # mitad. Las dos rechazaban planillas de verdad, porque una matrícula real
  # está llena de huecos: el alumno que todavía no tiene cédula, el
  # representante sin correo, la columna de observaciones vacía en casi todas.
  #
  # Y ninguna de las dos compraba nada, que es lo importante: lo que separa al
  # encabezado del membrete NO es cuántas celdas trae la fila siguiente, es que
  # el membrete tiene una línea en blanco debajo y el encabezado no. Eso ya lo
  # dice `basura?`. La densidad sobra, y de la del propio encabezado —media
  # anchura, en `parece_encabezado?`— ya se ocupa el otro lado.
  def pegado_a_sus_datos?(numero)
    return false if numero >= @hoja.last_row

    !basura?(celdas_de(numero + 1))
  end

  def numero_suelto?(valor)
    valor.is_a?(Numeric) || valor.to_s.strip.match?(/\A[\d.,]+\z/)
  end

  # Una fila es basura si está vacía, o si tiene una sola celda con texto —el
  # caso del "SUBTOTAL 1er AÑO" perdido en el medio de la matrícula—.
  def basura?(celdas)
    llenas(celdas) <= 1
  end

  def llenas(celdas) = celdas.count { |c| c.to_s.strip.present? }

  def celdas_de(n)
    @hoja.row(n).values_at(0...ancho) || []
  end

  def ancho = @ancho ||= @hoja.last_column.to_i

  # Los encabezados tienen que ser únicos y no vacíos: son las claves del hash
  # de cada fila. Una planilla con dos columnas "OBSERVACIONES" es normal, y
  # sin esto la segunda se comería a la primera en silencio.
  def nombrar(celdas)
    vistos = Hash.new(0)

    celdas.each_with_index.map do |celda, i|
      base = celda.to_s.sub(BOM, "").strip.gsub(/\s+/, " ")
      base = "Columna #{i + 1}" if base.empty?

      vistos[base] += 1
      vistos[base] > 1 ? "#{base} (#{vistos[base]})" : base
    end
  end
end
