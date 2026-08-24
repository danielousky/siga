# Qué columnas espera el importador de matrícula, y qué significa cada una.
#
# Es **una sola definición para tres cosas**, y por eso vive acá y no repartida:
#
#   1. La plantilla que el colegio descarga para llenar.
#   2. La leyenda que explica cada columna.
#   3. El mapeo automático, que usa `sinonimos` para adivinar qué columna de la
#      planilla del colegio corresponde a cuál campo nuestro.
#
# Si estuviera repartida, el día que se agregue una columna habría que
# acordarse de tres lugares. Se agregaría en uno.
#
# Ver MOR-126.
class ColumnasDeMatricula
  Columna = Struct.new(:clave, :titulo, :ambito, :obligatorio, :formato, :ejemplo, :nota, :sinonimos,
                       keyword_init: true) do
    def obligatorio? = obligatorio
  end

  TODAS = [
    Columna.new(
      clave: :nombre_completo,
      ambito: :alumno,
      titulo: "APELLIDOS Y NOMBRES DEL ALUMNO",
      obligatorio: true,
      formato: "Apellidos primero",
      ejemplo: "DE LA CRUZ MARÍN JOSÉ LUIS",
      nota: "Si su planilla los trae al revés, titule la columna «NOMBRES Y APELLIDOS» " \
            "y el sistema lo entiende. Los apellidos compuestos («DE LA CRUZ») se " \
            "reconocen solos.",
      sinonimos: [ "apellidos y nombres", "nombres y apellidos", "alumno", "estudiante",
                   "nombre del alumno", "nombre completo", "apellidos", "nombre" ]
    ),
    Columna.new(
      clave: :cedula_escolar,
      ambito: :alumno,
      titulo: "CÉDULA ESCOLAR",
      obligatorio: false,
      formato: "12 caracteres, como la asigna el MPPE",
      ejemplo: "V20140000123",
      nota: "Obligatoria SI el alumno no tiene cédula de identidad. Se conserva aunque " \
            "después saque la cédula: es lo que hace verificable un boletín viejo.",
      sinonimos: [ "cedula escolar", "ced. escolar", "c. escolar", "cedula del alumno" ]
    ),
    Columna.new(
      clave: :documento,
      ambito: :alumno,
      titulo: "CÉDULA DE IDENTIDAD",
      obligatorio: false,
      formato: "Con o sin puntos y guion, da igual",
      ejemplo: "V-31.222.333",
      nota: "Obligatoria SI el alumno no tiene cédula escolar. Un alumno de primaria " \
            "normalmente no tiene ninguna de las dos todavía: en ese caso, la escolar.",
      sinonimos: [ "cedula", "c.i.", "ci", "cedula de identidad", "documento", "ced." ]
    ),
    Columna.new(
      clave: :fecha_de_nacimiento,
      ambito: :alumno,
      titulo: "FECHA DE NACIMIENTO",
      obligatorio: false,
      formato: "día/mes/año",
      ejemplo: "12/03/2014",
      nota: "⚠️ Día primero. Si su archivo salió de un Excel en inglés puede venir al " \
            "revés — el sistema avisa cuando detecta fechas que se leerían de dos formas.",
      sinonimos: [ "fecha de nacimiento", "f. nacim.", "f. nac.", "nacimiento",
                   "fecha nac", "fecha nacimiento" ]
    ),
    Columna.new(
      clave: :sexo,
      ambito: :alumno,
      titulo: "SEXO",
      obligatorio: false,
      formato: "M o F",
      ejemplo: "M",
      nota: "También se entiende Masculino/Femenino y V/H (varón/hembra) de las " \
            "planillas del MPPE.",
      sinonimos: [ "sexo", "genero", "s." ]
    ),
    Columna.new(
      clave: :seccion,
      ambito: :inscripcion,
      titulo: "SECCIÓN",
      obligatorio: true,
      formato: "Grado y sección, como se llaman en SIGA",
      ejemplo: "1er Año A",
      nota: "Tienen que existir antes de importar. Si aparece alguna que no existe, el " \
            "sistema se lo muestra antes de cargar nada y le ofrece crearla ahí mismo.",
      sinonimos: [ "seccion", "año/secc", "ano/secc", "grado y seccion", "grado",
                   "curso", "año", "salon" ]
    ),
    Columna.new(
      clave: :representante,
      ambito: :representante,
      titulo: "APELLIDOS Y NOMBRES DEL REPRESENTANTE",
      obligatorio: true,
      formato: "Apellidos primero",
      ejemplo: "MARÍN GONZÁLEZ MARÍA",
      nota: "Si dos alumnos comparten representante, escríbalo igual en las dos filas: " \
            "se reconoce por la cédula y queda una sola persona.",
      sinonimos: [ "representante", "responsable", "madre o padre", "apoderado",
                   "nombre del representante", "apellidos y nombres",
                   "nombres y apellidos", "nombre", "apellidos" ]
    ),
    Columna.new(
      clave: :cedula_del_representante,
      ambito: :representante,
      titulo: "CÉDULA DEL REPRESENTANTE",
      obligatorio: true,
      formato: "Con o sin puntos y guion, da igual",
      ejemplo: "V-12.345.678",
      nota: "Es lo que identifica a la persona. Si esa señora ya representa a un alumno " \
            "en otro colegio de SIGA, se reutiliza su registro en vez de duplicarla.",
      sinonimos: [ "cedula del representante", "ci representante", "c.i. rep.",
                   "cedula rep", "documento del representante", "cedula", "documento" ]
    ),
    Columna.new(
      clave: :correo_del_representante,
      ambito: :representante,
      titulo: "CORREO DEL REPRESENTANTE",
      obligatorio: false,
      formato: "Uno por representante",
      ejemplo: "maria.marin@gmail.com",
      nota: "Sin correo la fila se carga igual, pero esa persona NO va a poder consultar " \
            "las notas hasta que se lo carguen. Al terminar sale la lista de quiénes son.",
      sinonimos: [ "correo del representante", "email", "correo", "e-mail",
                   "correo electronico" ]
    ),
    Columna.new(
      clave: :telefono_del_representante,
      ambito: :representante,
      titulo: "TELÉFONO DEL REPRESENTANTE",
      obligatorio: false,
      formato: "Como usted lo escriba",
      ejemplo: "0414-1234567",
      nota: "No se le cambia el formato.",
      sinonimos: [ "telefono", "telf", "tlf", "celular", "telefono del representante" ]
    ),
    Columna.new(
      clave: :parentesco,
      ambito: :inscripcion,
      titulo: "PARENTESCO",
      obligatorio: false,
      formato: "Madre, Padre, Representante legal u Otro",
      ejemplo: "Madre",
      nota: "Si se deja vacío queda como «Representante».",
      sinonimos: [ "parentesco", "relacion", "vinculo" ]
    )
  ].freeze

  def self.obligatorias = TODAS.select(&:obligatorio?)
  def self.titulos = TODAS.map(&:titulo)
  def self.[](clave) = TODAS.find { |c| c.clave == clave }

  # De quién habla el encabezado. Sin esto, `APELLIDOS Y NOMBRES DEL
  # REPRESENTANTE` se mapea al nombre del ALUMNO, porque contiene «apellidos y
  # nombres» y esa columna se declara primero.
  #
  # Lo encontró probar la plantilla generada contra el propio lector: la
  # herramienta no entendía el archivo que ella misma escribe.
  DE_REPRESENTANTE = %w[representante responsable apoderado madre padre].freeze

  # La columna que mejor corresponde a un encabezado de la planilla del colegio,
  # o `nil` si no se parece a ninguna.
  #
  # Compara sin acentos, sin mayúsculas y sin puntuación, porque `C.I.` y `ci`
  # son la misma columna escrita por dos secretarias distintas.
  #
  # El orden de las dos pasadas importa:
  #
  #   1. Coincidencia EXACTA con un sinónimo, sin mirar el ámbito. `PARENTESCO`
  #      y `SECCIÓN` no nombran a nadie y aun así son inequívocas.
  #   2. Coincidencia parcial, pero solo entre las columnas del ámbito que el
  #      encabezado nombra, y SIN la palabra que marca ese ámbito.
  #
  # ⚠️ Quitar esa palabra es lo que hace falta para que `CORREO REPRESENTANTE`
  # no se lea como el nombre del representante. Ahí hay dos señales — «correo»
  # dice QUÉ campo es y «representante» dice DE QUIÉN— y si compiten, gana la
  # segunda porque es más larga. Separadas, cada una hace su trabajo.
  # ⚠️ Un sinónimo corto NO se busca por dentro de la palabra.
  #
  # `ci` es sinónimo de cédula, y `OBSERVACIONES` contiene esas dos letras
  # —obserVACIones—, así que el importador leía la columna de observaciones como
  # la cédula del alumno. Con tres letras o menos, la única coincidencia que
  # vale es la exacta, que ya la resuelve la primera pasada.
  LARGO_MINIMO_PARA_BUSCAR_ADENTRO = 4

  def self.para(encabezado)
    texto = comparable(encabezado)
    return nil if texto.blank?

    exacta = TODAS.find { |c| c.sinonimos.any? { |s| comparable(s) == texto } }
    return exacta if exacta

    resto = sin_la_marca_de_ambito(texto)
    return nil if resto.blank?

    candidatas(texto).find { |c| c.sinonimos.any? { |s| contiene?(resto, comparable(s)) } }
  end

  # La comparación va en UNA dirección: el encabezado contiene al sinónimo.
  #
  # Al revés —el sinónimo contiene al encabezado— parece razonable para las
  # abreviaturas y no lo es: `Nº` se normaliza a `n`, y «nombre» contiene una
  # `n`, así que la columna del número de orden se leía como el nombre del
  # alumno. Las abreviaturas de verdad ya las agarra la coincidencia exacta.
  def self.contiene?(texto, sinonimo)
    return false if sinonimo.length < LARGO_MINIMO_PARA_BUSCAR_ADENTRO
    return false if texto.length < LARGO_MINIMO_PARA_BUSCAR_ADENTRO

    texto.include?(sinonimo)
  end

  def self.candidatas(texto)
    TODAS.select { |c| c.ambito == ambito_de(texto) || c.ambito == :inscripcion }
  end

  def self.ambito_de(texto)
    DE_REPRESENTANTE.any? { |p| texto.include?(p) } ? :representante : :alumno
  end

  def self.sin_la_marca_de_ambito(texto)
    DE_REPRESENTANTE.reduce(texto) { |t, palabra| t.gsub(palabra, "") }
  end

  def self.comparable(texto)
    texto.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.gsub(/[^a-z0-9]/, "")
  end
end
