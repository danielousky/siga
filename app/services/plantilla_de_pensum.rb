# La planilla en blanco de MATERIAS Y PROFESORES (MOR-126, tanda 2).
#
# La forma de esta planilla sorprende al principio y por eso los tres ejemplos
# la enseñan antes que el texto: **una fila es una materia dictada en una
# sección**, no una materia. La misma materia se repite tantas veces como
# secciones la tengan, y el mismo profesor tantas veces como materias dicte.
class PlantillaDePensum < PlantillaDeImportacion
  COLUMNAS = ColumnasDePensum
  HOJA = "Pensum".freeze
  PREFIJO = "pensum".freeze

  EJEMPLOS = [
    # La misma materia en dos secciones: dos filas, UNA materia. Es lo que más
    # se pregunta y por eso va primero.
    [ "1er Año A", "Matemática", "MAT", "Ciencias",
      "GARCÍA PÉREZ CARLOS", "V-12.345.678", "carlos.garcia@colegio.edu" ],
    [ "1er Año B", "Matemática", "MAT", "Ciencias",
      "GARCÍA PÉREZ CARLOS", "V-12.345.678", "carlos.garcia@colegio.edu" ],
    # Otra materia, otra profesora, y SIN código: enseña que la columna se puede
    # dejar vacía.
    [ "1er Año A", "Castellano y Literatura", "", "Lengua",
      "NIEVES ROJAS CARMEN", "V-10.987.654", "carmen.nieves@colegio.edu" ]
  ].freeze

  INTRO = "Cada fila es UNA MATERIA EN UNA SECCIÓN. Si «Matemática» se dicta en tres " \
          "secciones, van tres filas: no se duplica la materia, se reconoce por su " \
          "código. Lo mismo con el profesor, que se reconoce por su cédula. Borre las " \
          "tres filas de ejemplo y escriba las suyas; las columnas en rojo son " \
          "obligatorias.".freeze

  ANTES_DE_ENVIAR = [
    "Las secciones («1er Año A») tienen que existir ya en SIGA. Si alguna no existe, " \
    "el sistema se lo va a mostrar ANTES de cargar nada y le ofrece crearla ahí mismo.",
    "TODO profesor necesita correo, y este es el único dato que no se puede dejar en " \
    "blanco: sin él no puede entrar al sistema, y entrar es lo que viene a hacer — " \
    "cargar las notas de sus alumnos.",
    "Una sección tiene un solo profesor por materia. Si la misma materia aparece dos " \
    "veces en la misma sección con profesores distintos, se carga la primera y el " \
    "sistema le avisa cuál dejó fuera.",
    "Si no maneja departamentos, deje la columna vacía: todas las materias van a «General»."
  ].freeze
end
