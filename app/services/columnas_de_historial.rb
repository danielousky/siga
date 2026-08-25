# Qué columnas espera el importador de historial de notas (MOR-126, tanda 3).
#
# Una fila es **un alumno en una materia de un año escolar**, con sus lapsos al
# lado. Es la forma en que sale de cualquier sistema y la única que se puede
# mapear:
#
#     PÉREZ ANA · 2023-2024 · 3er Año A · Matemática · 15 · 14 · 16 · 15
#         │           │           │           │         └────┬────┘   │
#         │           │           │           │              │        └ la definitiva
#         │           │           │           │              └ un MomentGrade por lapso
#         │           │           │           └ la materia, del pensum del grado
#         │           │           └ la sección de ESE año, no la de hoy
#         │           └ el año escolar, que puede no existir todavía
#         └ la persona, buscada por cédula escolar o documento
#
# ⚠️ **La alternativa —una columna por materia— no se puede mapear.** Sería un
# encabezado distinto en cada colegio y en cada grado, y el mapeo dejaría de
# tener sentido: no hay «esta columna es Matemática» que valga para todos.
class ColumnasDeHistorial
  Columna = ColumnasDeMatricula::Columna

  # Cuántos lapsos se aceptan. Tres es lo normal en Venezuela; dos existe en
  # colegios con semestres. Más de cuatro no lo tiene nadie y aceptarlo solo
  # abriría la puerta a mapear mal una columna que no es una nota.
  LAPSOS = 4

  DE_LAPSOS = (1..LAPSOS).map do |n|
    Columna.new(
      clave: :"lapso_#{n}",
      ambito: :notas,
      titulo: "LAPSO #{n}",
      obligatorio: false,
      formato: "Del 1 al 20, o el literal",
      ejemplo: n.odd? ? "15" : "14",
      nota: "Deje la columna fuera si su colegio no tiene ese lapso. Con dos lapsos, " \
            "use LAPSO 1 y LAPSO 2 y nada más.",
      sinonimos: [ "lapso #{n}", "l#{n}", "momento #{n}", "corte #{n}", "#{n}er lapso",
                   "#{n}do lapso", "#{n}to lapso", "trimestre #{n}", "semestre #{n}" ]
    )
  end.freeze

  TODAS = [
    Columna.new(
      clave: :nombre_completo,
      ambito: :alumno,
      titulo: "APELLIDOS Y NOMBRES DEL ALUMNO",
      obligatorio: true,
      formato: "Apellidos primero",
      ejemplo: "DE LA CRUZ MARÍN JOSÉ LUIS",
      nota: "Se usa para reconocerlo y para avisarle si la cédula que trae ya es de otra " \
            "persona. Un alumno que ya está en SIGA no se duplica.",
      sinonimos: [ "apellidos y nombres del alumno", "apellidos y nombres", "alumno",
                   "estudiante", "nombres y apellidos", "nombre del alumno", "nombre" ]
    ),
    Columna.new(
      clave: :cedula_escolar,
      ambito: :alumno,
      titulo: "CÉDULA ESCOLAR",
      obligatorio: false,
      formato: "Como la asigna el MPPE",
      ejemplo: "V20140000123",
      nota: "Es lo que identifica al alumno cuando todavía no tiene cédula de identidad, " \
            "y es NACIONAL: acompaña al alumno si se cambia de plantel.",
      sinonimos: [ "cedula escolar", "ce", "cod. estudiante", "codigo del estudiante" ]
    ),
    Columna.new(
      clave: :documento,
      ambito: :alumno,
      titulo: "CÉDULA DEL ALUMNO",
      obligatorio: false,
      formato: "Con o sin puntos y guion",
      ejemplo: "V-31.222.333",
      nota: "⚠️ Hace falta ESTA o la cédula escolar: sin ninguna de las dos no se puede " \
            "saber de quién es la nota, y una nota que se le carga al alumno equivocado " \
            "es peor que no cargarla.",
      sinonimos: [ "cedula del alumno", "cedula", "c.i.", "ci", "documento", "cedula de identidad" ]
    ),
    Columna.new(
      clave: :ano_escolar,
      ambito: :cuando,
      titulo: "AÑO ESCOLAR",
      obligatorio: true,
      formato: "Los dos años, con guion",
      ejemplo: "2023-2024",
      nota: "El año al que pertenecen estas notas. Si el colegio todavía no lo tiene " \
            "cargado, el sistema se lo muestra antes de importar y le ofrece crearlo con " \
            "sus lapsos, de un clic.",
      sinonimos: [ "año escolar", "ano escolar", "periodo", "período", "año", "curso escolar" ]
    ),
    Columna.new(
      clave: :seccion,
      ambito: :cuando,
      titulo: "SECCIÓN",
      obligatorio: true,
      formato: "Grado y sección de ESE año",
      ejemplo: "3er Año A",
      nota: "La sección que cursaba entonces, no la de hoy. Si no existe, el sistema le " \
            "ofrece crearla —con su grado, si tampoco existe— antes de cargar nada.",
      sinonimos: [ "seccion", "año/secc", "ano/secc", "grado y seccion", "grado", "curso", "salon" ]
    ),
    Columna.new(
      clave: :materia,
      ambito: :materia,
      titulo: "MATERIA",
      obligatorio: true,
      formato: "El nombre o su código",
      ejemplo: "Matemática",
      nota: "Tiene que estar en el pensum del grado. Importe primero las materias y " \
            "profesores si todavía no lo hizo.",
      sinonimos: [ "materia", "asignatura", "area", "area de formacion", "catedra", "codigo" ]
    ),
    *DE_LAPSOS,
    Columna.new(
      clave: :definitiva,
      ambito: :notas,
      titulo: "DEFINITIVA",
      obligatorio: false,
      formato: "Del 1 al 20, o el literal",
      ejemplo: "15",
      nota: "⚠️ La definitiva que traiga el colegio MANDA sobre el promedio de los lapsos: " \
            "es la que está impresa en el boletín que ya entregó. Si no la trae, se calcula " \
            "de los lapsos.",
      sinonimos: [ "definitiva", "nota definitiva", "final", "nota final", "promedio anual",
                   "calificacion definitiva", "anual" ]
    ),
    Columna.new(
      clave: :reparacion,
      ambito: :notas,
      titulo: "REPARACIÓN",
      obligatorio: false,
      formato: "Del 1 al 20, o el literal",
      ejemplo: "12",
      nota: "La nota de la segunda oportunidad, si la presentó. Por el Artículo 112 del " \
            "Reglamento, es la definitiva.",
      sinonimos: [ "reparacion", "revision", "segunda oportunidad", "recuperacion", "rep" ]
    )
  ].freeze

  # Palabras que dicen DE QUIÉN es la columna. En esta planilla hay una sola
  # persona —el alumno— así que sirven para descartar, no para desempatar.
  DEL_ALUMNO = %w[alumno estudiante].freeze

  LARGO_MINIMO_PARA_BUSCAR_ADENTRO = ColumnasDeMatricula::LARGO_MINIMO_PARA_BUSCAR_ADENTRO

  def self.obligatorias = TODAS.select(&:obligatorio?)
  def self.titulos = TODAS.map(&:titulo)
  def self.[](clave) = TODAS.find { |c| c.clave == clave }
  def self.de_lapsos = DE_LAPSOS

  def self.para(encabezado)
    texto = comparable(encabezado)
    return nil if texto.blank?

    exacta = TODAS.find { |c| c.sinonimos.any? { |s| comparable(s) == texto } }
    return exacta if exacta

    resto = DEL_ALUMNO.reduce(texto) { |t, palabra| t.gsub(palabra, "") }
    return nil if resto.blank?

    TODAS.find { |c| c.sinonimos.any? { |s| contiene?(resto, comparable(s)) } }
  end

  def self.contiene?(texto, sinonimo)
    return false if sinonimo.length < LARGO_MINIMO_PARA_BUSCAR_ADENTRO
    return false if texto.length < LARGO_MINIMO_PARA_BUSCAR_ADENTRO

    texto.include?(sinonimo)
  end

  def self.comparable(texto) = ColumnasDeMatricula.comparable(texto)
end
