# Qué columnas espera el importador de pensum y profesores (MOR-126, tanda 2).
#
# Una fila es **una materia dictada en una sección**, y de ahí salen cuatro
# cosas de un golpe:
#
#     1er Año A · Matemática · GARCÍA PÉREZ CARLOS
#            │        │              │
#            │        │              └─ el PROFESOR y su rol en el colegio
#            │        └───────────────  la MATERIA
#            │                          y el PENSUM: 1er Año tiene Matemática
#            └────────────────────────  la ASIGNACIÓN: quién la dicta acá
#
# ⚠️ **El correo del profesor es obligatorio, y esto es distinto de la tanda 1.**
#
# A un representante se le puede cargar sin correo —queda sin poder consultar
# las notas y el reporte lo lista— pero un profesor SIN CORREO NO SE PUEDE
# CREAR: el concern `EntraAlSistema` lo exige, porque un profesor que no entra
# no puede cargar notas, que es lo único que viene a hacer. Ver `MOR-142`.
class ColumnasDePensum
  Columna = ColumnasDeMatricula::Columna

  TODAS = [
    Columna.new(
      clave: :seccion,
      ambito: :asignacion,
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
      clave: :materia,
      ambito: :materia,
      titulo: "MATERIA",
      obligatorio: true,
      formato: "El nombre completo",
      ejemplo: "Matemática",
      nota: "Si ya existe una materia con el mismo código, se reutiliza en vez de " \
            "duplicarla. Cargar la misma materia para varias secciones es lo normal: " \
            "una fila por sección.",
      sinonimos: [ "materia", "asignatura", "area", "area de formacion", "catedra" ]
    ),
    Columna.new(
      clave: :codigo,
      ambito: :materia,
      titulo: "CÓDIGO DE LA MATERIA",
      obligatorio: false,
      formato: "Corto, como lo usa el colegio",
      ejemplo: "MAT",
      nota: "Es lo que identifica a la materia dentro del colegio. Si no lo trae, SIGA " \
            "lo arma con las primeras letras del nombre.",
      sinonimos: [ "codigo", "cod", "codigo de la materia", "clave" ]
    ),
    Columna.new(
      clave: :departamento,
      ambito: :materia,
      titulo: "DEPARTAMENTO",
      obligatorio: false,
      formato: "El área a la que pertenece",
      ejemplo: "Ciencias",
      nota: "Solo sirve para agrupar materias en los listados. Si su colegio no maneja " \
            "departamentos, deje la columna fuera: todas van a «General».",
      sinonimos: [ "departamento", "area academica", "coordinacion" ]
    ),
    Columna.new(
      clave: :profesor,
      ambito: :profesor,
      titulo: "APELLIDOS Y NOMBRES DEL PROFESOR",
      obligatorio: true,
      formato: "Apellidos primero",
      ejemplo: "GARCÍA PÉREZ CARLOS",
      nota: "Un profesor que dicta cinco materias va en cinco filas, con la misma " \
            "cédula: se reconoce por ella y queda una sola persona.",
      sinonimos: [ "profesor", "docente", "profesora", "nombre del profesor",
                   "apellidos y nombres", "nombres y apellidos", "nombre", "apellidos" ]
    ),
    Columna.new(
      clave: :cedula_del_profesor,
      ambito: :profesor,
      titulo: "CÉDULA DEL PROFESOR",
      obligatorio: true,
      formato: "Con o sin puntos y guion, da igual",
      ejemplo: "V-12.345.678",
      nota: "Es lo que identifica a la persona. Si ese profesor ya da clase en otro " \
            "colegio de SIGA, se reutiliza su registro en vez de duplicarlo.",
      sinonimos: [ "cedula del profesor", "ci profesor", "c.i.", "ci", "cedula",
                   "documento", "cedula de identidad" ]
    ),
    Columna.new(
      clave: :correo_del_profesor,
      ambito: :profesor,
      titulo: "CORREO DEL PROFESOR",
      obligatorio: true,
      formato: "Uno por profesor",
      ejemplo: "carlos.garcia@colegio.edu",
      nota: "⚠️ Obligatorio, a diferencia del correo del representante. Un profesor sin " \
            "correo no puede entrar al sistema, y entrar es lo único que viene a hacer: " \
            "cargar las notas de sus alumnos.",
      sinonimos: [ "correo del profesor", "email", "correo", "e-mail", "correo electronico" ]
    )
  ].freeze

  # El resto se comporta igual que en matrícula: la búsqueda por sinónimos, la
  # coincidencia exacta primero y el ámbito para desempatar. Lo único que cambia
  # es qué palabras marcan el ámbito.
  DE_PROFESOR = %w[profesor profesora docente].freeze

  LARGO_MINIMO_PARA_BUSCAR_ADENTRO = ColumnasDeMatricula::LARGO_MINIMO_PARA_BUSCAR_ADENTRO

  def self.obligatorias = TODAS.select(&:obligatorio?)
  def self.titulos = TODAS.map(&:titulo)
  def self.[](clave) = TODAS.find { |c| c.clave == clave }

  def self.para(encabezado)
    texto = comparable(encabezado)
    return nil if texto.blank?

    exacta = TODAS.find { |c| c.sinonimos.any? { |s| comparable(s) == texto } }
    return exacta if exacta

    resto = DE_PROFESOR.reduce(texto) { |t, palabra| t.gsub(palabra, "") }
    return nil if resto.blank?

    candidatas(texto).find { |c| c.sinonimos.any? { |s| contiene?(resto, comparable(s)) } }
  end

  # Sin marca de profesor, una columna suelta como «CÉDULA» es del profesor
  # igual: en esta planilla no hay ninguna otra persona.
  def self.candidatas(_texto) = TODAS

  def self.contiene?(texto, sinonimo)
    return false if sinonimo.length < LARGO_MINIMO_PARA_BUSCAR_ADENTRO
    return false if texto.length < LARGO_MINIMO_PARA_BUSCAR_ADENTRO

    texto.include?(sinonimo)
  end

  def self.comparable(texto) = ColumnasDeMatricula.comparable(texto)
end
