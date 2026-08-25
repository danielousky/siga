# La planilla en blanco de MATRÍCULA (MOR-126).
#
# La maquinaria está en `PlantillaDeImportacion`; acá solo vive lo que es propio
# de cargar alumnos.
class PlantillaDeMatricula < PlantillaDeImportacion
  COLUMNAS = ColumnasDeMatricula
  HOJA = "Matrícula".freeze
  PREFIJO = "matricula".freeze

  # Los ejemplos no son de adorno: cada uno enseña algo que el texto solo no
  # transmite bien.
  EJEMPLOS = [
    # Un alumno de primaria: sin cédula de identidad, con escolar. Es el caso
    # más común y el que más dudas genera.
    [ "DE LA CRUZ MARÍN JOSÉ LUIS", "V20140000123", "", "12/03/2014", "M", "", "1er Año A",
      "MARÍN GONZÁLEZ MARÍA", "V-12.345.678", "maria.marin@gmail.com", "0414-1234567", "Madre" ],
    # Su hermana: MISMA representante, misma cédula. Enseña que no hay que
    # inventarle una fila aparte al representante.
    [ "DE LA CRUZ MARÍN ANA SOFÍA", "V20160000456", "", "22/11/2016", "F", "", "1er Año A",
      "MARÍN GONZÁLEZ MARÍA", "V-12.345.678", "maria.marin@gmail.com", "0414-1234567", "Madre" ],
    # Un bachiller: ya tiene cédula, y su representante NO tiene correo.
    # Enseña que la fila entra igual.
    [ "BLANCO NIEVES PEDRO ANTONIO", "", "V-31.222.333", "05/07/2009", "M", "25-104", "5to Año B",
      "NIEVES ROJAS CARMEN", "V-10.987.654", "", "0424-9876543", "Madre" ]
  ].freeze

  INTRO = "Borre las tres filas de ejemplo de la hoja «Matrícula» y escriba sus alumnos, " \
          "uno por fila. Las columnas en rojo son obligatorias. Puede agregar columnas " \
          "suyas: las que SIGA no reconozca simplemente se ignoran.".freeze

  ANTES_DE_ENVIAR = [
    "Las secciones («1er Año A») tienen que existir ya en SIGA. Si alguna no existe, " \
    "el sistema se lo va a mostrar ANTES de cargar nada y le ofrece crearla ahí mismo.",
    "Si un alumno repite en dos filas, se carga una sola vez: se reconoce por su cédula.",
    "Un representante sin correo se carga igual, pero no va a poder consultar las notas " \
    "hasta que se lo carguen. Al terminar sale la lista de quiénes quedaron así.",
    "No hace falta borrar los subtotales ni el membrete: el sistema los ignora y le dice " \
    "cuáles filas dejó fuera."
  ].freeze
end
