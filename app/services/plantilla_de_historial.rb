# La planilla en blanco de NOTAS DE AÑOS ANTERIORES (MOR-126, tanda 3).
#
# Los ejemplos enseñan las tres cosas que más se preguntan: que una fila es una
# materia de un alumno en un año, que el mismo alumno se repite tantas veces como
# materias cursó, y que las notas pueden venir en número o en letra.
class PlantillaDeHistorial < PlantillaDeImportacion
  COLUMNAS = ColumnasDeHistorial
  HOJA = "Historial".freeze
  PREFIJO = "historial".freeze

  # El orden de las columnas lo fija `ColumnasDeHistorial::TODAS`:
  # nombre · cédula escolar · cédula · año escolar · sección · materia ·
  # lapso 1..4 · definitiva · reparación
  EJEMPLOS = [
    # El mismo alumno, dos materias del mismo año: dos filas. Es lo que más se
    # pregunta, y por eso va primero.
    [ "DE LA CRUZ MARÍN JOSÉ LUIS", "V20140000123", "", "2023-2024", "3er Año A",
      "Matemática", "15", "14", "16", "", "15", "" ],
    [ "DE LA CRUZ MARÍN JOSÉ LUIS", "V20140000123", "", "2023-2024", "3er Año A",
      "Castellano y Literatura", "9", "11", "10", "", "10", "12" ],
    # Otro alumno, con la nota en LETRA: el historial de primaria viene así,
    # porque es lo único que se imprimió.
    [ "BLANCO NIEVES ANA SOFÍA", "V20160000456", "", "2023-2024", "6to Grado B",
      "Matemática", "B", "A", "B", "", "B", "" ]
  ].freeze

  INTRO = "Cada fila es UNA MATERIA DE UN ALUMNO EN UN AÑO ESCOLAR. Si José cursó nueve " \
          "materias en 2023-2024, van nueve filas con su misma cédula escolar: no se " \
          "duplica el alumno, se reconoce por ella. Borre las tres filas de ejemplo y " \
          "escriba las suyas; las columnas en rojo son obligatorias.".freeze

  ANTES_DE_ENVIAR = [
    "El AÑO ESCOLAR y la SECCIÓN de ese año tienen que existir en SIGA. Si no existen, el " \
    "sistema se lo muestra ANTES de cargar nada y le ofrece crearlos ahí mismo — el año " \
    "con sus lapsos, y la sección con su grado.",
    "Importe primero las MATERIAS Y PROFESORES: una nota necesita su materia, y acá no se " \
    "crean.",
    "⚠️ Hace falta la CÉDULA o la CÉDULA ESCOLAR del alumno. El nombre no alcanza: en una " \
    "matrícula de 360 hay apellidos repetidos, y una nota cargada al alumno equivocado es " \
    "peor que no cargarla.",
    "Las notas pueden ir del 1 al 20 o en literal A–E. ⚠️ Si van en letra se pierde el " \
    "número exacto —«B» abarca 17 y 18, y se guarda 17—: si tiene el número, ese vale más.",
    "La DEFINITIVA que usted traiga manda sobre el promedio de los lapsos: es la que está " \
    "impresa en el boletín que ya entregó. Si la deja vacía, se calcula de los lapsos.",
    "Estas notas quedan marcadas como importadas y NO se recalculan nunca: no tienen " \
    "evaluaciones debajo, y no hace falta que las tengan."
  ].freeze
end
