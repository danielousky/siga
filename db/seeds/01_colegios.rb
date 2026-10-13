# Los colegios, sus años escolares y sus lapsos (MOR-224).
#
# ## Dos colegios, y cada uno prueba algo distinto
#
#     SIMÓN BOLÍVAR   los TRES niveles + Media Técnica · ~360 alumnos
#                     el colegio promedio venezolano, y el que ejercita todo
#
#     ANDRÉS BELLO    preescolar y primaria · ~90 alumnos · escala literal
#                     el segundo inquilino, que es lo que prueba el aislamiento
#
# ⚠️ El grande dicta los tres niveles a propósito, y eso es nuevo. Antes Bolívar
# era solo bachillerato y Bello solo primaria, así que para ver el selector de
# nivel funcionando había que entrar a uno y para ver bachillerato al otro —
# cuando el colegio real de ~360 alumnos dicta los tres a la vez. Es literalmente
# el caso que motivó `Current.nivel`.
paso "📚 Colegios"

def colegio!(dea:, nombre:, **datos)
  colegio = School.find_or_create_by!(dea_code: dea) { |c| c.name = nombre }
  # La dirección completa NO es decorado: `entidad_federal`, `municipio` y
  # `parroquia` salen IMPRESAS en los documentos del MPPE. Sin ellas, la demo
  # genera constancias con renglones en blanco.
  colegio.update!(name: nombre, **datos)
  colegio
end

bolivar = colegio!(
  dea: "BOL001", nombre: "U.E. Simón Bolívar",
  location: "Caracas, Distrito Capital", entidad_federal: "Distrito Capital",
  municipio: "Libertador", parroquia: "El Recreo", telefono: "0212-555-1234",
  direccion: "Av. Casanova con calle El Colegio, Sabana Grande"
)

bello = colegio!(
  dea: "AND002", nombre: "U.E. Andrés Bello",
  location: "Valencia, Carabobo", entidad_federal: "Carabobo",
  municipio: "Valencia", parroquia: "San José", telefono: "0241-555-6677",
  direccion: "Calle Páez, entre avenidas Bolívar y Constitución"
)

SEMILLA[:bolivar] = bolivar
SEMILLA[:bello]   = bello

# El escudo del colegio: su identidad, y aparece en los documentos que la
# familia se lleva en la mano. Sin él, el boletín parece de la empresa de
# software y no del colegio.
{ bolivar => "escudo_bolivar.png", bello => "escudo_bello.png" }.each do |colegio, archivo|
  ruta = Rails.root.join("db/seeds_assets", archivo)
  next unless ruta.exist?
  next if colegio.logo.attached?

  colegio.logo.attach(io: File.open(ruta), filename: archivo, content_type: "image/png")
end
puts "   ✓ #{bolivar.name} · #{bello.name}"

# ── Años escolares ───────────────────────────────────────────────────────────
#
# Se cuentan desde HOY (`ANIO_EN_CURSO`, en `utiles`): el que corre, el que
# pasó y el de antes. Bolívar tiene los tres porque es un colegio con historia;
# Bello, solo el que corre.
#
#     HISTÓRICO   solo definitivas, importadas   → «Todos los años» significa algo
#     ANTERIOR    completo y cerrado en SIGA     → boletines, certificados, promoción
#     EN CURSO    hasta hoy                      → donde se trabaja
#     SIGUIENTE   SOLO en vacaciones             → la estructura copiada, sin alumnos
#
# ⚠️ `en_operacion` decide el año por defecto, y es el que TIENE ALUMNOS. En
# agosto, la fila más nueva es el año que empieza en septiembre y no tiene ni
# una sección: arrancar ahí es abrir el panel de un colegio lleno y leer
# «0 alumnos». Por eso el SIGUIENTE existe solo cuando el que corre ya terminó:
# es el estado real de un colegio en vacaciones, y es lo que deja «Promover
# alumnos» con trabajo por hacer (MOR-169).
#
# Las fechas son las que propone la app (`AcademicPeriod.para_el_anio`): del 15
# de septiembre al 31 de julio.
def anio!(colegio, inicio)
  propuesto = AcademicPeriod.para_el_anio(inicio, school: colegio)

  AcademicPeriod.find_or_create_by!(name: propuesto.name, school: colegio) do |p|
    p.start_date = propuesto.start_date
    p.end_date   = propuesto.end_date
  end
end

SEMILLA[:historico] = anio!(bolivar, ANIO_EN_CURSO - 2)
SEMILLA[:anterior]  = anio!(bolivar, ANIO_EN_CURSO - 1)
SEMILLA[:en_curso]  = anio!(bolivar, ANIO_EN_CURSO)
SEMILLA[:siguiente] = anio!(bolivar, ANIO_EN_CURSO + 1) if SEMILLA[:en_curso].end_date < HOY
SEMILLA[:bello_en_curso] = anio!(bello, ANIO_EN_CURSO)

puts "   ✓ Bolívar: #{SEMILLA[:historico].name} (importado) · #{SEMILLA[:anterior].name} (cerrado) · " \
     "#{SEMILLA[:en_curso].name} (#{SEMILLA[:en_curso].end_date < HOY ? 'terminado' : 'en curso'})" \
     "#{" · #{SEMILLA[:siguiente].name} (por empezar)" if SEMILLA[:siguiente]}"
puts "     Bello:   #{SEMILLA[:bello_en_curso].name}"

# ── Lapsos ───────────────────────────────────────────────────────────────────
#
# ⚠️ SIEMPRE tres, y con el nombre que produce la app: `AcademicPeriod::LAPSOS`.
#
# Hubo acá un «Primer Semestre / Segundo Semestre» para 2026-2027, puesto a
# propósito para mostrar que reorganizar un año nuevo no toca el anterior. Pero
# eso es un invariante del CÁLCULO y ya lo prueba `grade_calculator_test` con su
# propio escenario; en la demo solo confundía a quien hacía QA.
#
# Las FECHAS sí son propias, y esa es la gracia: el reparto en tercios de
# `sembrar_lapsos` no conoce el receso de diciembre.
# ⚠️ Las fechas se derivan del PERÍODO, no se escriben a mano.
#
# Estaban escritas —15 de septiembre, 20 de diciembre…— y el año 2024-2025
# arranca el 16: el lapso caía un día antes del período y la validación lo
# rechazaba. Derivándolas, cualquier año escolar que se agregue después encaja
# solo.
#
# El corte en diciembre y el arranque en enero SÍ son fijos, y esa es la gracia:
# el reparto en tercios de `sembrar_lapsos` no conoce el receso de navidad.
def fechas_de_los_lapsos(periodo)
  cierre_de_diciembre = Date.new(periodo.start_date.year, 12, 20)
  vuelta_de_enero     = Date.new(periodo.end_date.year, 1, 8)
  cierre_de_marzo     = Date.new(periodo.end_date.year, 3, 31)
  vuelta_de_abril     = Date.new(periodo.end_date.year, 4, 6)

  [ [ periodo.start_date, cierre_de_diciembre ],
    [ vuelta_de_enero,    cierre_de_marzo ],
    [ vuelta_de_abril,    periodo.end_date ] ]
end

SEMILLA.values_at(:historico, :anterior, :en_curso, :siguiente, :bello_en_curso).compact.each do |periodo|
  fechas = fechas_de_los_lapsos(periodo)

  AcademicPeriod::LAPSOS.each_with_index do |nombre, i|
    lapso = EvaluationMoment.find_or_create_by!(name: nombre, academic_period: periodo)

    # `find_or_create_by!` no toca los que ya existen, y estas fechas pueden ser
    # nuevas: se asignan aparte para que una siembra sobre una base ya cargada
    # las complete en vez de dejarlas vacías.
    next if lapso.fechas_propias?

    desde, hasta = fechas[i]
    lapso.update!(starts_on: desde, ends_on: hasta)
  end
end
puts "   ✓ #{AcademicPeriod::LAPSOS.join(' · ')} en cada año escolar"
