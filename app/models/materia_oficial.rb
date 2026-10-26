# Las materias que se cursan en Venezuela, por grado (MOR-208).
#
# ## Por qué esto es una constante, como `GradoOficial`
#
# Un colegio no elige que en 3er Año se dé Física: lo fija el plan de estudio
# del MPPE. Es la misma información en los 3.900 colegios del país, así que
# pedirle a cada director que la cargue es pedirle que transcriba una ley.
#
# Daniel: *«las materias básicas también las podemos deducir. No hay que pedirle
# que cargue matemáticas, castellano, biología, historia… Luego lo puede
# ajustar, pero inicialmente debe ser así»*.
#
# ⚠️ **Es un PUNTO DE PARTIDA, no un corsé.** Lo que se siembra son `Subject` y
# `GradeSubject` normales: el colegio los renombra, los borra y agrega los suyos
# —Computación, Religión, la segunda lengua que dicte— sin que nada acá se
# entere.
#
# ## ⚠️ Lo que se siembra es lo que se CALIFICA, no lo que se legisla
#
# Y es la decisión que más se puede malinterpretar, así que conviene que esté
# escrita.
#
# El Currículo Bolivariano de primaria (2007) define CUATRO «áreas de
# aprendizaje» muy anchas: «Lenguaje, Comunicación y Cultura», «Matemática,
# Ciencias Naturales y Sociedad», «Ciencias Sociales, Ciudadanía e Identidad» y
# «Educación Física, Deportes y Recreación». Sembrar eso daría un boletín de
# cuatro renglones que **ningún representante reconoce**: la libreta de un
# colegio venezolano dice Matemática, Lengua, Ciencias Naturales.
#
# Daniel, confirmándolo: *«en el caso de primaria, sí: las materias que se
# califican, no las cuatro áreas»*.
#
# ⚠️ Y observó algo que vale para después: *«las áreas podrían ser los
# departamentos»*. Son exactamente eso —agrupaciones por afinidad— así que el
# día que un colegio quiera departamentos, la agrupación oficial ya existe.
#
# ## Media General sí es oficial y completa
#
# Las 14 áreas de formación del MPPE (2017), **con el año en que se cursa cada
# una**. Esa parte no se interpreta: se copia.
#
# ⚠️ Y el año importa. Física, Química y Biología empiezan en 3er Año, y
# Ciencias Naturales termina en 2do. Sembrarlas en los cinco años llenaría el
# boletín de un primer año con materias que ese alumno no cursa — que es
# exactamente el tipo de error que hace que un colegio desconfíe del sistema el
# primer día.
#
# ## ⚠️ Preescolar NO lleva materias
#
# La Educación Inicial no se califica por asignaturas: tiene dos áreas de
# aprendizaje —«Formación Personal, Social y Comunicación» y «Relación entre los
# Componentes del Ambiente»— y se evalúa por componentes, en escala literal.
# Sembrarle «Matemática» a un 2do Nivel sería un error de dominio, no un exceso
# de celo. Por eso `PARA` no tiene entradas de preescolar.
#
# ## Las horas a la semana, que también son del plan
#
# La Resolución DM/0033 de 2017 (Gaceta 41.221) fija cuántas horas semanales
# lleva cada área en cada año, y van al lado de los años en el mismo orden:
# Inglés es `[ 6, 6, 6, 6, 4 ]` de 1er a 5to Año.
#
# ⚠️ Solo Media General las tiene. Primaria no trae horas por materia —la
# maestra integral reparte su día—, y el plan de la Media Técnica depende de la
# especialidad.
#
# ⚠️ Y suman 44 a 46, que es más de lo que cabe en una semana de turno de
# mañana (40). No es un error de esta tabla: es la norma, y cada colegio la
# ajusta. Por eso son una PROPUESTA (`CargaHorariaOficial`) y no un dato fijo.
#
# Fuentes: plan de estudio de Media General (MPPE, junio 2017) · Currículo
# Nacional Bolivariano (2007) · Currículo de Educación Inicial (2007).
class MateriaOficial
  # `grados` son los NOMBRES del catálogo de `GradoOficial`, no un rango: es lo
  # que permite escribir «3er Año a 5to Año» sin que nadie tenga que saber en
  # qué posición del catálogo cae cada uno.
  #
  # `horas` va emparejada con `grados`, posición por posición; vacía donde el
  # plan no fija ninguna.
  Entrada = Data.define(:nombre, :codigo, :grados, :horas) do
    def to_s = nombre

    def horas_en(nombre_del_grado)
      buscado = GradoOficial.normalizar(nombre_del_grado)
      posicion = grados.index { |grado| GradoOficial.normalizar(grado) == buscado }

      posicion && horas[posicion]
    end
  end

  PRIMARIA = %w[1er\ Grado 2do\ Grado 3er\ Grado 4to\ Grado 5to\ Grado 6to\ Grado].freeze
  BACHILLERATO = %w[1er\ Año 2do\ Año 3er\ Año 4to\ Año 5to\ Año].freeze

  # ⚠️ El 6to Año de la Media Técnica NO está en estas listas.
  #
  # Es el año de la especialidad —electrónica, informática, agropecuaria— y sus
  # materias las decide el colegio según qué técnico gradúa. No hay un pensum
  # nacional que proponer, y proponer el del 5to Año sería inventar.
  CATALOGO = [
    # ── Primaria: lo que se califica en una libreta ──────────────────────────
    [ "Lengua y Literatura",   "LEN", PRIMARIA ],
    [ "Matemática",            "MAT", PRIMARIA ],
    [ "Ciencias Naturales",    "CN",  PRIMARIA ],
    [ "Ciencias Sociales",     "CS",  PRIMARIA ],
    [ "Educación Física",      "EF",  PRIMARIA ],
    [ "Educación Estética",    "EE",  PRIMARIA ],

    # ── Media General: las 14 áreas de formación, con su año ─────────────────
    [ "Castellano",            "CAS", BACHILLERATO, [ 4, 4, 4, 4, 4 ] ],
    [ "Matemáticas",           "MAT", BACHILLERATO, [ 4, 4, 4, 4, 4 ] ],
    [ "Educación Física",      "EF",  BACHILLERATO, [ 6, 6, 6, 6, 6 ] ],
    [ "Inglés y Otras Lenguas Extranjeras", "ING", BACHILLERATO, [ 6, 6, 6, 6, 4 ] ],
    [ "Orientación y Convivencia",          "OYC", BACHILLERATO, [ 2, 2, 2, 2, 2 ] ],
    [ "Geografía, Historia y Ciudadanía",   "GHC", BACHILLERATO, [ 6, 6, 6, 4, 4 ] ],
    [ "Participación en Grupos de Creación, Recreación y Producción",
                               "PGC", BACHILLERATO, [ 6, 6, 6, 6, 6 ] ],
    [ "Ciencias Naturales",    "CN",  %w[1er\ Año 2do\ Año], [ 6, 6 ] ],
    [ "Arte y Patrimonio",     "ART", %w[1er\ Año 2do\ Año], [ 4, 4 ] ],
    [ "Física",                "FIS", %w[3er\ Año 4to\ Año 5to\ Año], [ 4, 4, 4 ] ],
    [ "Química",               "QUI", %w[3er\ Año 4to\ Año 5to\ Año], [ 4, 4, 4 ] ],
    [ "Biología",              "BIO", %w[3er\ Año 4to\ Año 5to\ Año], [ 4, 4, 4 ] ],
    [ "Formación para la Soberanía Nacional", "FSN", %w[4to\ Año 5to\ Año], [ 2, 2 ] ],
    [ "Ciencias de la Tierra", "CT",  %w[5to\ Año], [ 2 ] ]
  ].map { |nombre, codigo, grados, horas| Entrada.new(nombre: nombre, codigo: codigo, grados: grados, horas: horas || []) }
   .freeze

  # Las áreas del plan que traen horas: las de Media General.
  def self.con_horas = CATALOGO.select { |entrada| entrada.horas.any? }

  # Las materias que le tocan a un colegio según los grados que dicta.
  #
  # ⚠️ Se pregunta por los GRADOS y no por los niveles, a propósito: un colegio
  # puede dictar solo hasta 3er Año, y entonces Física —que empieza en 3ero—
  # entra, pero Ciencias de la Tierra no. Preguntar por el nivel le daría las
  # cinco materias del bachillerato completo.
  def self.para(nombres_de_grados)
    tiene = Array(nombres_de_grados).map { |n| GradoOficial.normalizar(n) }.to_set

    CATALOGO.filter_map do |entrada|
      suyos = entrada.grados.select { |g| tiene.include?(GradoOficial.normalizar(g)) }
      next if suyos.empty?

      [ entrada, suyos ]
    end
  end

  # ⚠️ Dos materias distintas pueden proponer el MISMO código.
  #
  # «Matemática» de primaria y «Matemáticas» de bachillerato proponen las dos
  # `MAT`, y `subjects.code` es único por colegio: un colegio que dicta los dos
  # niveles reventaría al sembrar la segunda.
  #
  # Y son la misma materia, no dos: lo que cambia es cómo la nombra cada nivel.
  # Así que la regla es reutilizar el código —y por lo tanto la materia— cuando
  # ya existe, igual que hace el importador de pensum.
  def self.mismo_codigo?(a, b) = a.codigo == b.codigo
end
