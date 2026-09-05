# El pensum: departamentos, áreas y qué se dicta en cada grado (MOR-224).
#
# ## Por qué está escrito como una tabla y no como código
#
# Esto NO es dato inventado: es el currículo del MPPE. Un director que mira la
# demo reconoce «Formación para la Soberanía Nacional» y «Grupo de Creación,
# Recreación y Producción» — y no reconoce las once materias sueltas que había
# antes, repetidas idénticas en los cinco años.
#
# Daniel: *«las asignaturas por defecto, creo que podemos acercarnos más a la
# realidad con la data sembrada»*.
#
# ## ⚠️ El pensum es por GRADO, no por colegio
#
# `grade_subjects` existe justamente para esto. Sembrar las mismas ocho materias
# en los quince grados es lo que había, y es lo primero que un director nota
# como falso: en 1er Año no hay Química, y en primaria no hay Filosofía.
paso "🏛️  Departamentos y áreas de aprendizaje"

# Las coordinaciones de un colegio venezolano de tamaño medio.
DEPARTAMENTOS = {
  inicial:    "Educación Inicial",
  lengua:     "Lengua y Literatura",
  matematica: "Matemática",
  ciencias:   "Ciencias Naturales",
  sociales:   "Ciencias Sociales",
  idiomas:    "Idiomas Modernos",
  arte:       "Arte y Cultura",
  edfisica:   "Educación Física y Deporte",
  tecnica:    "Educación Técnica",
  orientacion: "Orientación y Convivencia"
}.freeze

# ── Las áreas ────────────────────────────────────────────────────────────────
#
# ⚠️ El nombre es el OFICIAL, no el de pizarra. «Geografía, Historia y
# Ciudadanía» es una sola área desde el currículo de 2016, aunque el colegio le
# siga diciendo «Historia».
#
# ⚠️ El CÓDIGO es un invento del colegio y por eso se siembra explícito: ningún
# algoritmo acierta que «Castellano y Literatura» es `LEN` — pasó en el
# importador y quedó anotado (`§ 3` del estado conocido).
AREAS = {
  # Educación Inicial — currículo de 2005. Son ÁREAS DE APRENDIZAJE y se
  # trabajan por componentes; en la boleta no se califican, se describen.
  "FPS" => { nombre: "Formación Personal y Social",     dpto: :inicial },
  "RCA" => { nombre: "Relación con el Ambiente",         dpto: :inicial },
  "CYR" => { nombre: "Comunicación y Representación",    dpto: :inicial },

  # Educación Primaria
  "LEN" => { nombre: "Castellano y Literatura",          dpto: :lengua },
  "MAT" => { nombre: "Matemática",                       dpto: :matematica },
  "CNA" => { nombre: "Ciencias Naturales",               dpto: :ciencias },
  "CSO" => { nombre: "Ciencias Sociales",                dpto: :sociales },
  "EST" => { nombre: "Educación Estética",               dpto: :arte },
  "EDF" => { nombre: "Educación Física y Deporte",       dpto: :edfisica },
  "ING" => { nombre: "Inglés",                           dpto: :idiomas },
  "EPT" => { nombre: "Educación para el Trabajo",        dpto: :tecnica },
  "COM" => { nombre: "Computación",                      dpto: :tecnica },

  # Educación Media General — áreas de formación del currículo de 2016
  "ART" => { nombre: "Arte y Patrimonio",                dpto: :arte },
  "GHC" => { nombre: "Geografía, Historia y Ciudadanía", dpto: :sociales },
  "FSN" => { nombre: "Formación para la Soberanía Nacional", dpto: :sociales },
  "OYC" => { nombre: "Orientación y Convivencia",        dpto: :orientacion },
  "GCR" => { nombre: "Grupo de Creación, Recreación y Producción", dpto: :arte },
  "BIO" => { nombre: "Biología",                         dpto: :ciencias },
  "FIS" => { nombre: "Física",                           dpto: :ciencias },
  "QUI" => { nombre: "Química",                          dpto: :ciencias },
  "CTI" => { nombre: "Ciencias de la Tierra",            dpto: :ciencias },

  # Media Técnica — mención Informática
  "PRG" => { nombre: "Programación",                     dpto: :tecnica },
  "BDA" => { nombre: "Bases de Datos",                   dpto: :tecnica },
  "MEQ" => { nombre: "Mantenimiento de Equipos",         dpto: :tecnica },
  "PPR" => { nombre: "Prácticas Profesionales",          dpto: :tecnica },
  "PSP" => { nombre: "Proyecto Socio-Productivo",        dpto: :tecnica }
}.freeze

# ── El pensum, grado por grado ───────────────────────────────────────────────
#
# ⚠️ Las dos ETAPAS de primaria llevan pensum distinto, y por eso están
# escritas aparte: de 4to a 6to entran Educación para el Trabajo y Computación.
# Es la distinción que un maestro nombra en la primera frase —«primera etapa» y
# «segunda etapa»— y la demo tiene que mostrarla.
#
# ⚠️ En bachillerato el pensum CAMBIA cada año: Ciencias Naturales en 1º y 2º
# se abre en Biología, Física y Química en 3º, y Ciencias de la Tierra aparece
# solo en 5º.
PRIMERA_ETAPA = %w[LEN MAT CNA CSO EST EDF ING].freeze
SEGUNDA_ETAPA = (PRIMERA_ETAPA + %w[EPT COM]).freeze

PENSUM = {
  "1er Nivel"  => %w[FPS RCA CYR],
  "2do Nivel"  => %w[FPS RCA CYR],
  "3er Nivel"  => %w[FPS RCA CYR],

  "1er Grado"  => PRIMERA_ETAPA,
  "2do Grado"  => PRIMERA_ETAPA,
  "3er Grado"  => PRIMERA_ETAPA,
  "4to Grado"  => SEGUNDA_ETAPA,
  "5to Grado"  => SEGUNDA_ETAPA,
  "6to Grado"  => SEGUNDA_ETAPA,

  "1er Año"    => %w[LEN MAT ING EDF ART CNA GHC FSN OYC GCR],
  "2do Año"    => %w[LEN MAT ING EDF ART CNA GHC FSN OYC GCR],
  "3er Año"    => %w[LEN MAT ING EDF ART BIO FIS QUI GHC FSN OYC GCR],
  "4to Año"    => %w[LEN MAT ING EDF BIO FIS QUI GHC FSN OYC GCR],
  "5to Año"    => %w[LEN MAT ING EDF BIO FIS QUI CTI GHC FSN OYC GCR],

  # El 6to Año gradúa Técnico Medio: mantiene el tronco común y agrega la
  # mención. Las Prácticas Profesionales y el Proyecto Socio-Productivo son
  # obligatorias para el título.
  "6to Año"    => %w[LEN MAT ING OYC PRG BDA MEQ PPR PSP]
}.freeze

# ── Sembrar ──────────────────────────────────────────────────────────────────

def sembrar_pensum!(colegio, niveles:)
  Current.school = colegio

  departamentos = DEPARTAMENTOS.transform_values do |nombre|
    Department.find_or_create_by!(name: nombre, school: colegio)
  end

  # ⚠️ Los grados salen del CATÁLOGO, con `SembrarGrados`: es lo mismo que hace
  # un director en su primera hora, y expande las implicaciones —marcar Media
  # Técnica siembra también los cinco años del bachillerato, porque no hay sexto
  # año sin los cinco anteriores.
  SembrarGrados.para(colegio, niveles: niveles)

  # Solo las áreas que este colegio necesita: uno de pura primaria no tiene
  # Química cargada y esperando.
  codigos = colegio.grades.en_orden.flat_map { |g| PENSUM.fetch(g.name, []) }.uniq
  areas = codigos.index_with do |codigo|
    datos = AREAS.fetch(codigo)
    Subject.find_or_create_by!(code: codigo, school: colegio) do |s|
      s.name = datos[:nombre]
      s.department = departamentos.fetch(datos[:dpto])
    end
  end

  colegio.grades.en_orden.each do |grado|
    PENSUM.fetch(grado.name, []).each do |codigo|
      GradeSubject.find_or_create_by!(grade: grado, subject: areas.fetch(codigo))
    end
  end

  areas
end

# ⚠️ Media Técnica y no `secundaria` a secas: es lo que trae el 6to Año, el
# grado con más código especial de todo el proyecto —la certificación 31059 es
# de la educación MEDIA, general o técnica— y sin sembrarlo no se ve nunca.
SEMILLA[:areas_bolivar] = sembrar_pensum!(
  SEMILLA[:bolivar], niveles: %i[preescolar primaria media_tecnica]
)
SEMILLA[:areas_bello] = sembrar_pensum!(
  SEMILLA[:bello], niveles: %i[preescolar primaria]
)

# ── La rúbrica de cada colegio (MOR-136) ─────────────────────────────────────
#
# ⚠️ Los DOS con rúbrica, y distintas a propósito. Bolívar usa los cinco
# niveles que propone SIGA; Bello usa TRES, que es el caso que contó Cyndi —
# *«había colegios que solo tenían tres, lo que lo hacía muy complicado porque
# metías en el mismo saco a estudiantes con 13 que a estudiantes con 17»*.
#
# Sin un colegio de tres niveles sembrado, esa queja no se puede ver resuelta:
# la máscara es más gruesa y por dentro el 13 y el 17 siguen siendo distintos.
Current.school = SEMILLA[:bolivar]
SEMILLA[:bolivar].restablecer_la_rubrica! if SEMILLA[:bolivar].rubrics.none?

Current.school = SEMILLA[:bello]
if SEMILLA[:bello].rubrics.none?
  [ { code: "L",  name: "Logrado",     description: "Alcanzó lo esperado para el lapso", valor: 15 },
    { code: "EP", name: "En proceso",  description: "Avanza, con apoyo del docente",     valor: 10 },
    { code: "I",  name: "Iniciado",    description: "Todavía no alcanza lo esperado",     valor: 1 } ].each do |datos|
    SEMILLA[:bello].rubrics.create!(datos)
  end
end

[ SEMILLA[:bolivar], SEMILLA[:bello] ].each do |colegio|
  Current.school = colegio
  resumen = colegio.grades.en_orden.group_by { |g| GradoOficial.se_elige_como(g.level) }
                   .map { |nivel, gs| "#{GradoOficial::ETIQUETAS[nivel]} #{gs.size}" }.join(" · ")
  puts "   ✓ #{colegio.name}: #{colegio.grades.count} grados (#{resumen}) · " \
       "#{colegio.subjects.count} áreas · rúbrica de #{colegio.rubrics.count} niveles"
end

Current.school = SEMILLA[:bolivar]
puts "     1er Año lleva #{PENSUM['1er Año'].size} áreas; 5to Año, #{PENSUM['5to Año'].size}; 6to Año técnico, #{PENSUM['6to Año'].size}"
