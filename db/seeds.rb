require "digest"
# =============================================================================
# SIGA - Seeds de Desarrollo
# Pensum venezolano completo con cobertura total de secciones
# =============================================================================

# =============================================================================
# GUARD DE ENTORNO — leer antes de tocar nada de acá abajo
# =============================================================================
#
# Este archivo crea cuentas con una contraseña conocida, y una de ellas tiene el
# rol `desarrollador`: máximo privilegio. Un `db:seed` contra la base de un
# colegio real —un deploy mal configurado, un comando en la terminal equivocada—
# no necesita ningún ataque para hacer daño. Y como los seeds son idempotentes,
# ni siquiera fallaría: sembraría en silencio.
#
# El guard es por LISTA BLANCA y no por lista negra. Un `staging` con datos
# reales tiene el mismo problema y no es `production`.
#
# ## La puerta para la demo pública
#
# Una demo SÍ necesita estos datos, así que hay una salida — pero cuesta escribirla
# y no tiene default:
#
#     SIGA_ENTORNO_DEMO=1 SIGA_SEED_PASSWORD=<algo-que-no-sea-123123> bin/rails db:seed
#
# En cualquier entorno que no sea desarrollo o test, la contraseña es OBLIGATORIA.
# Que la demo esté en internet con `123123` es exactamente lo que este guard
# existe para impedir.
#
# Ver MOR-104.
# La lógica vive en `lib/seed_guard.rb` para poder TESTEARLA. Un guard sin test
# es una intención, no un control: metido acá adentro no se puede probar sin
# sembrar la base, y probarlo a mano contra producción falla antes de llegar al
# guard —Rails aborta primero por la conexión— así que uno cree que funciona sin
# haberlo visto funcionar nunca.
guard = SeedGuard.new

begin
  CLAVE_DE_PRUEBA = guard.clave
rescue SeedGuard::EntornoNoPermitido, SeedGuard::FaltaLaClave => e
  abort "\n#{e.message}"
end

CORREO_DESARROLLADOR = guard.correo_desarrollador

# Todo adulto tiene cédula de identidad: la escolar existe justamente para quien
# todavía no la tiene. Determinista a partir del correo, para que los seeds den
# lo mismo en cada corrida.
def documento_de_prueba(email)
  "V-#{(Digest::MD5.hexdigest(email).to_i(16) % 20_000_000 + 5_000_000)}"
end

def sexo_para(nombre)
  # Determinista y suficiente para datos de prueba: los nombres de la lista que
  # terminan en `a` son femeninos, salvo los que no.
  %w[Andrés Rafael].include?(nombre) ? :male : (nombre.end_with?("a") ? :female : :male)
end


# Los seeds cargan DOS colegios, así que necesitan ver la plataforma entera.
# Sin esto el RLS los dejaría en cero filas y el segundo colegio no se crearía.
#
# Se declara de forma explícita y no en bloque para no indentar el archivo
# completo; el `at_exit` garantiza que la conexión no quede con el bypass puesto
# aunque los seeds fallen a la mitad.
Current.tenant_scope_disabled = true
ActiveRecord::Base.connection.execute("SET siga.bypass_rls = 'on'")
at_exit do
  Current.tenant_scope_disabled = false
  ActiveRecord::Base.connection.execute("SET siga.bypass_rls = 'off'") rescue nil
end

puts "🌱 Iniciando carga de datos de prueba..."
puts ""

# =============================================================================
# ESCUELAS
# =============================================================================
puts "📚 Creando escuelas..."

# ⚠️ La dirección completa NO es decorado: `entidad_federal`, `municipio` y
# `parroquia` salen IMPRESAS en los documentos del MPPE. Sin ellas, la demo
# genera constancias con renglones en blanco — y es lo primero que mira un
# director al que le estás mostrando el producto.
school_bolivar = School.find_or_create_by!(dea_code: "BOL-001") do |s|
  s.name = "U.E. Simón Bolívar"; s.location = "Caracas, Distrito Capital"; s.school_type = :secondary
end
school_bolivar.update!(entidad_federal: "Distrito Capital", municipio: "Libertador",
                       parroquia: "El Recreo", telefono: "0212-555-1234",
                       direccion: "Av. Casanova con calle El Colegio, Sabana Grande")
# Bello es de PRIMARIA a propósito (MOR-129): sin un colegio de primaria
# sembrado, la escala literal A–E no se puede ver funcionando en ninguna
# pantalla — y primaria es la mayoría de los ~3.900 colegios privados del país.
#
# El contraste entre los dos colegios es además el mejor material de la demo:
# mismo sistema, mismas pantallas, y cada uno calificando como le corresponde.
school_bello = School.find_or_create_by!(dea_code: "AND-002") do |s|
  s.name = "U.E. Andrés Bello"; s.location = "Valencia, Carabobo"; s.school_type = :primary
end
school_bello.update!(entidad_federal: "Carabobo", municipio: "Valencia",
                     parroquia: "San José", telefono: "0241-555-6677",
                     direccion: "Calle Páez, entre avenidas Bolívar y Constitución")
# El escudo del colegio: su identidad, y aparece en los documentos que la
# familia se lleva en la mano. Sin él, el boletín parece de la empresa de
# software y no del colegio.
{
  school_bolivar => "escudo_bolivar.png",
  school_bello   => "escudo_bello.png"
}.each do |colegio, archivo|
  ruta = Rails.root.join("db/seeds_assets", archivo)
  next unless ruta.exist?
  next if colegio.logo.attached?

  colegio.logo.attach(io: File.open(ruta), filename: archivo, content_type: "image/png")
end

puts "   ✓ #{school_bolivar.name} | ✓ #{school_bello.name}"
puts "     con escudo: #{School.all.count(&:logo_attached?) rescue School.all.count { |c| c.logo.attached? }}/2"

# =============================================================================
# PERÍODOS ACADÉMICOS
# =============================================================================
puts "📅 Creando períodos académicos..."

periodo_bolivar = AcademicPeriod.find_or_create_by!(name: "2025-2026", school: school_bolivar) do |p|
  p.start_date = Date.new(2025, 9, 15); p.end_date = Date.new(2026, 7, 15)
end
periodo_bello = AcademicPeriod.find_or_create_by!(name: "2025-2026", school: school_bello) do |p|
  p.start_date = Date.new(2025, 9, 15); p.end_date = Date.new(2026, 7, 15)
end

# Un segundo período en Bolívar, sin secciones todavía: es el año que viene.
# Existe para que se pueda VER que cada año escolar tiene su propia estructura de
# evaluación — con lapsos distintos a los del año en curso. Eso es justamente lo
# que se gana colgando los momentos del período y no de la escuela: cambiar los
# lapsos de 2026-2027 no toca ni una nota de 2025-2026.
periodo_bolivar_siguiente = AcademicPeriod.find_or_create_by!(name: "2026-2027", school: school_bolivar) do |p|
  p.start_date = Date.new(2026, 9, 15); p.end_date = Date.new(2027, 7, 15)
end
puts "   ✓ 2025-2026 en ambos colegios + 2026-2027 en Bolívar (para QA de estructura por año)"

# =============================================================================
# MOMENTOS DE EVALUACIÓN
# =============================================================================
puts "📊 Creando momentos de evaluación..."

# Cada período tiene su propio juego de lapsos: colgarlos del período congela la
# estructura de evaluación de cada año escolar junto con sus notas.
#
# Los dos colegios usan tres lapsos en 2025-2026, y cada uno ocupa el 100 % SIN
# estorbarle al otro — eso era imposible antes, cuando los pesos sumaban sobre
# toda la tabla y el primer colegio en llegar dejaba a los demás sin espacio.
#
# El `weight` describe qué parte del año representa cada lapso. NO entra en el
# cálculo de la nota anual: el Artículo 111 del Reglamento manda promedio simple
# de los lapsos (MOR-93). Se deja el 30/30/40 porque es lo que un colegio
# venezolano espera ver escrito.
# Las fechas son las de un año escolar venezolano real: arranca a mediados de
# septiembre y cierra a mediados de julio. Sin ellas el boletín cuenta las
# inasistencias del AÑO entero en vez de las del lapso, y lo aclara en el papel.
LAPSOS_TRES = [
  { name: "Primer Lapso",  weight: 30.0, desde: [ 9, 15 ], hasta: [ 12, 20 ] },
  { name: "Segundo Lapso", weight: 30.0, desde: [ 1,  8 ], hasta: [  3, 31 ] },
  { name: "Tercer Lapso",  weight: 40.0, desde: [ 4,  6 ], hasta: [  7, 15 ] }
].freeze

# 2026-2027 estrena una estructura DISTINTA a propósito: dos lapsos al 50 %.
# Sirve para ver que reorganizar la evaluación de un año nuevo no toca en nada
# la del año anterior ni las notas ya calculadas.
LAPSOS_DOS = [
  { name: "Primer Semestre",  weight: 50.0, desde: [ 9, 15 ], hasta: [ 1, 31 ] },
  { name: "Segundo Semestre", weight: 50.0, desde: [ 2,  2 ], hasta: [ 7, 15 ] }
].freeze

{
  periodo_bolivar           => LAPSOS_TRES,
  periodo_bello             => LAPSOS_TRES,
  periodo_bolivar_siguiente => LAPSOS_DOS
}.each do |periodo, lapsos|
  lapsos.each do |lapso|
    EvaluationMoment.find_or_create_by!(name: lapso[:name], academic_period: periodo) do |m|
      m.weight = lapso[:weight]
    end.tap do |m|
      # `find_or_create_by!` no toca los que ya existen, y estas fechas son
      # nuevas: se asignan aparte para que un seed sobre una base ya sembrada
      # las complete en vez de dejarlas vacías.
      next if lapso[:desde].nil? || m.fechas_propias?

      # Un lapso que arranca en enero pertenece al SEGUNDO año del período:
      # "2025-2026" va de septiembre de 2025 a julio de 2026.
      ano = ->(mes) { mes >= 8 ? periodo.start_date.year : periodo.end_date.year }
      m.update!(starts_on: Date.new(ano.(lapso[:desde][0]), *lapso[:desde]),
                ends_on:   Date.new(ano.(lapso[:hasta][0]), *lapso[:hasta]))
    end
  end
end
puts "   ✓ 2025-2026: 3 lapsos (30/30/40) en ambos colegios"
puts "   ✓ 2026-2027 Bolívar: 2 semestres (50/50) — estructura distinta, mismo colegio"

# =============================================================================
# DEPARTAMENTOS - SIMÓN BOLÍVAR
# =============================================================================
puts ""
puts "🏛️  Creando departamentos..."

dept = {}
{
  bolivar: {
    matematica:  { school: school_bolivar, name: "Matemática" },
    ciencias:    { school: school_bolivar, name: "Ciencias Naturales" },
    sociales:    { school: school_bolivar, name: "Ciencias Sociales" },
    lengua:      { school: school_bolivar, name: "Lengua y Literatura" },
    idiomas:     { school: school_bolivar, name: "Idiomas Modernos" },
    arte:        { school: school_bolivar, name: "Arte y Cultura" },
    edufisica:   { school: school_bolivar, name: "Educación Física" }
  },
  bello: {
    matematica:  { school: school_bello, name: "Matemática" },
    ciencias:    { school: school_bello, name: "Ciencias Naturales" },
    sociales:    { school: school_bello, name: "Ciencias Sociales" },
    lengua:      { school: school_bello, name: "Lengua y Literatura" },
    idiomas:     { school: school_bello, name: "Idiomas Modernos" },
    arte:        { school: school_bello, name: "Arte y Cultura" },
    edufisica:   { school: school_bello, name: "Educación Física" }
  }
}.each do |escuela, departamentos|
  dept[escuela] = {}
  departamentos.each do |key, attrs|
    dept[escuela][key] = Department.find_or_create_by!(name: attrs[:name], school: attrs[:school])
  end
end
puts "   ✓ #{Department.count} departamentos en total"

# =============================================================================
# MATERIAS - Pensum venezolano de Bachillerato
# Ciclo básico (1ro-3ro): 10 materias
# Ciclo diversificado (4to-5to): 10 materias (con Física y Química)
# =============================================================================
puts ""
puts "📖 Creando materias (pensum venezolano)..."

s = {} # subjects bolivar
s[:mat]  = Subject.find_or_create_by!(code: "MAT", school: school_bolivar)  { |x| x.name = "Matemática";                x.department = dept[:bolivar][:matematica] }
s[:bio]  = Subject.find_or_create_by!(code: "BIO", school: school_bolivar)  { |x| x.name = "Biología";                  x.department = dept[:bolivar][:ciencias] }
s[:fis]  = Subject.find_or_create_by!(code: "FIS", school: school_bolivar)  { |x| x.name = "Física";                    x.department = dept[:bolivar][:ciencias] }
s[:qui]  = Subject.find_or_create_by!(code: "QUI", school: school_bolivar)  { |x| x.name = "Química";                   x.department = dept[:bolivar][:ciencias] }
s[:his]  = Subject.find_or_create_by!(code: "HIS", school: school_bolivar)  { |x| x.name = "Historia de Venezuela";     x.department = dept[:bolivar][:sociales] }
s[:geo]  = Subject.find_or_create_by!(code: "GEO", school: school_bolivar)  { |x| x.name = "Geografía de Venezuela";    x.department = dept[:bolivar][:sociales] }
s[:len]  = Subject.find_or_create_by!(code: "LEN", school: school_bolivar)  { |x| x.name = "Castellano y Literatura";   x.department = dept[:bolivar][:lengua] }
s[:ing]  = Subject.find_or_create_by!(code: "ING", school: school_bolivar)  { |x| x.name = "Inglés";                    x.department = dept[:bolivar][:idiomas] }
s[:art]  = Subject.find_or_create_by!(code: "ART", school: school_bolivar)  { |x| x.name = "Arte y Patrimonio";          x.department = dept[:bolivar][:arte] }
s[:edf]  = Subject.find_or_create_by!(code: "EDF", school: school_bolivar)  { |x| x.name = "Educación Física";           x.department = dept[:bolivar][:edufisica] }
s[:fil]  = Subject.find_or_create_by!(code: "FIL", school: school_bolivar)  { |x| x.name = "Filosofía";                 x.department = dept[:bolivar][:sociales] }

b = {} # subjects bello
b[:mat]  = Subject.find_or_create_by!(code: "MAT", school: school_bello)  { |x| x.name = "Matemática";                x.department = dept[:bello][:matematica] }
b[:bio]  = Subject.find_or_create_by!(code: "BIO", school: school_bello)  { |x| x.name = "Ciencias Naturales";        x.department = dept[:bello][:ciencias] }
b[:fis]  = Subject.find_or_create_by!(code: "FIS", school: school_bello)  { |x| x.name = "Educación para la Salud";   x.department = dept[:bello][:ciencias] }
b[:sos]  = Subject.find_or_create_by!(code: "SOS", school: school_bello)  { |x| x.name = "Ciencias Sociales";         x.department = dept[:bello][:sociales] }
b[:len]  = Subject.find_or_create_by!(code: "LEN", school: school_bello)  { |x| x.name = "Castellano y Literatura";   x.department = dept[:bello][:lengua] }
b[:ing]  = Subject.find_or_create_by!(code: "ING", school: school_bello)  { |x| x.name = "Inglés";                    x.department = dept[:bello][:idiomas] }
b[:art]  = Subject.find_or_create_by!(code: "ART", school: school_bello)  { |x| x.name = "Arte y Patrimonio";          x.department = dept[:bello][:arte] }
b[:edf]  = Subject.find_or_create_by!(code: "EDF", school: school_bello)  { |x| x.name = "Educación Física";           x.department = dept[:bello][:edufisica] }

puts "   ✓ #{Subject.count} materias creadas"

# =============================================================================
# GRADOS con pensum venezolano completo
# =============================================================================
puts ""
puts "📚 Creando grados con pensum venezolano..."

# --- SIMÓN BOLÍVAR ---
# Ciclo básico: 1ro, 2ro, 3ro (Biología, sin Física/Química)
# Ciclo diversificado: 4to, 5to (Física + Química, sin Biología separada)
gbol = {}
[
  { key: :g1, name: "1er Año", level: :secundaria,
    subjects: [s[:mat], s[:len], s[:his], s[:geo], s[:bio], s[:ing], s[:art], s[:edf]] },
  { key: :g2, name: "2do Año", level: :secundaria,
    subjects: [s[:mat], s[:len], s[:his], s[:geo], s[:bio], s[:ing], s[:art], s[:edf]] },
  { key: :g3, name: "3er Año", level: :secundaria,
    subjects: [s[:mat], s[:len], s[:his], s[:geo], s[:bio], s[:fis], s[:ing], s[:art], s[:edf]] },
  { key: :g4, name: "4to Año", level: :secundaria,
    subjects: [s[:mat], s[:len], s[:his], s[:fis], s[:qui], s[:ing], s[:fil], s[:edf]] },
  { key: :g5, name: "5to Año", level: :secundaria,
    subjects: [s[:mat], s[:len], s[:his], s[:fis], s[:qui], s[:ing], s[:fil], s[:edf]] }
].each do |g|
  grade = Grade.find_or_create_by!(name: g[:name], school: school_bolivar) { |gr| gr.level = g[:level] }
  g[:subjects].each { |subj| GradeSubject.find_or_create_by!(grade: grade, subject: subj) }
  gbol[g[:key]] = grade
end
puts "   ✓ 5 grados Bolívar (#{gbol[:g1].grade_subjects.count} materias en 1ro; #{gbol[:g4].grade_subjects.count} en 4to)"

# --- ANDRÉS BELLO — PREESCOLAR Y PRIMARIA COMPLETAS ---
#
# ⚠️ Antes tenía TRES grados: 4to, 5to y 6to. Daniel lo señaló como raro y tiene
# razón — «o dictas primaria completa o secundaria completa, pero no parcial».
# Un colegio que empieza en 4to Grado no existe, y una demo con datos imposibles
# le enseña al que la mira que el sistema no sabe de colegios.
#
# Ahora se siembran con `SembrarGrados` desde el catálogo oficial (MOR-153), que
# es además lo que hace un director de verdad en su primera hora: marca los
# niveles y los grados nacen con su nombre, su nivel y su orden.
#
# Bello dicta preescolar Y primaria, que es el caso que `school_type` no podía
# representar por ser excluyente.
Current.school = school_bello
SembrarGrados.para(school_bello, niveles: [ :preescolar, :primaria ])

MATERIAS_DE_PRIMARIA = [ b[:mat], b[:len], b[:sos], b[:bio], b[:ing], b[:art], b[:edf] ].freeze
# Preescolar no lleva el pensum de primaria: a esa edad son ámbitos de
# aprendizaje, no materias. Se le cargan las tres que sí tienen sentido.
MATERIAS_DE_PREESCOLAR = [ b[:len], b[:art], b[:edf] ].freeze

school_bello.grades.en_orden.each do |grade|
  materias = grade.preescolar? ? MATERIAS_DE_PREESCOLAR : MATERIAS_DE_PRIMARIA
  materias.each { |subj| GradeSubject.find_or_create_by!(grade: grade, subject: subj) }
end

# ⚠️ `gbel` mapea SOLO los tres grados que después reciben secciones y alumnos.
# Meter los nueve acá dejaba claves duplicadas —g1 y g7 apuntando al mismo 4to
# Grado— y el bucle de secciones creaba dos veces la misma con dos nombres.
gbel = {
  g1: school_bello.grades.find_by!(name: "4to Grado"),
  g2: school_bello.grades.find_by!(name: "5to Grado"),
  g3: school_bello.grades.find_by!(name: "6to Grado")
}

puts "   ✓ #{school_bello.grades.count} grados Bello · #{school_bello.niveles.map { |n| GradoOficial::ETIQUETAS[n] }.join(' y ')}, escala literal A–E"

# =============================================================================
# ADMIN - Mi usuario
# =============================================================================
puts ""
puts "👤 Configurando administradores..."

# ⚠️ Acá vivía un `Admin` con rol `desarrollador` colgado de Bolívar: la forma
# vieja de decir "esta persona es de SIGA". Ya no existe.
#
# El equipo de SIGA no pertenece a ningún colegio (MOR-133): se siembra más
# abajo como `SigaStaff`, sin `school_id`. Dejarlo como Admin de un colegio fue
# exactamente lo que produjo cuatro fugas en dos días.

[
  { email: "director.bolivar@siga.edu",  name: "Ramón",  last_name: "Díaz",      school: school_bolivar, role: :director },
  { email: "coord.bolivar@siga.edu",     name: "Carmen", last_name: "Rodríguez", school: school_bolivar, role: :coordinador },
  { email: "director.bello@siga.edu",    name: "Luisa",  last_name: "Martínez",  school: school_bello,   role: :director }
].each do |d|
  u = User.find_or_create_by!(email: d[:email]) do |uu|
    uu.password = uu.password_confirmation = CLAVE_DE_PRUEBA
    uu.first_name = d[:name]; uu.last_name = d[:last_name]
    uu.document = documento_de_prueba(d[:email]); uu.document_type = :cedula_v
    uu.sex = sexo_para(d[:name])
  end
  Admin.find_or_create_by!(user: u) { |a| a.school = d[:school]; a.role = d[:role] }
end
puts "   ✓ 4 administradores"

# =============================================================================
# PROFESORES - Un especialista por área
# =============================================================================
puts ""
puts "👨‍🏫 Creando profesores..."

def make_teacher(email, name, last_name, document, school)
  u = User.find_or_create_by!(email: email) do |uu|
    uu.password = uu.password_confirmation = CLAVE_DE_PRUEBA
    uu.first_name = name
    uu.last_name  = last_name
    uu.document   = document
    # Un profesor SIEMPRE tiene cédula de identidad y NUNCA cédula escolar: la
    # escolar existe para quien todavía no tiene la nacional.
    uu.document_type = :cedula_v
    uu.birth_date    = Date.new(1985, (document.to_s.gsub(/\D/, "").to_i % 12) + 1, 15)
    uu.sex           = sexo_para(name)
  end
  Teacher.find_or_create_by!(user: u) { |t| t.school = school }
end

# Simón Bolívar — un profesor por área temática
tbol = {
  mat:  make_teacher("prof.garcia@bolivar.edu",    "Carlos",    "García",    "V-12345678", school_bolivar),
  len:  make_teacher("prof.torres@bolivar.edu",    "María",     "Torres",    "V-23456789", school_bolivar),
  sos:  make_teacher("prof.herrera@bolivar.edu",   "José",      "Herrera",   "V-34567890", school_bolivar),
  bio:  make_teacher("prof.mendoza@bolivar.edu",   "Ana",       "Mendoza",   "V-45678901", school_bolivar),
  fis:  make_teacher("prof.rivas@bolivar.edu",     "Luís",      "Rivas",     "V-56789012", school_bolivar),
  ing:  make_teacher("prof.castillo@bolivar.edu",  "Patricia",  "Castillo",  "V-67890123", school_bolivar),
  arte: make_teacher("prof.moreno@bolivar.edu",    "Sofía",     "Moreno",    "V-78901234", school_bolivar),
  edf:  make_teacher("prof.rojas@bolivar.edu",     "Andrés",    "Rojas",     "V-89012345", school_bolivar)
}
puts "   ✓ 8 profesores (U.E. Simón Bolívar)"

# Andrés Bello — profesores polivalentes
tbel = {
  mat:  make_teacher("prof.vega@bello.edu",    "Pedro",     "Vega",    "V-90123456", school_bello),
  len:  make_teacher("prof.suarez@bello.edu",  "Gabriela",  "Suárez",  "V-01234567", school_bello),
  sos:  make_teacher("prof.parra@bello.edu",   "Ricardo",   "Parra",   "V-11223344", school_bello),
  cien: make_teacher("prof.leon@bello.edu",    "Elena",     "León",    "V-22334455", school_bello),
  ing:  make_teacher("prof.blanco@bello.edu",  "Antonio",   "Blanco",  "V-33445566", school_bello),
  arte: make_teacher("prof.gil@bello.edu",     "Carmen",    "Gil",     "V-44556677", school_bello),
  edf:  make_teacher("prof.reyes@bello.edu",   "Omar",      "Reyes",   "V-55667788", school_bello)
}
puts "   ✓ 7 profesores (U.E. Andrés Bello)"

# Coordinadores de grado — el cargo OPCIONAL que coordina a los guías (MOR-150).
#
# ⚠️ Esto NO es el profesor guía. El guía es de la SECCIÓN y se asigna más
# abajo, cuando las secciones existen. Se dejan solo tres cargados a propósito:
# el cargo es opcional y la mayoría de los colegios no lo tiene, así que la
# demo tiene que mostrar los dos casos.
#
# Sin `unless`, por lo mismo que los guías: son datos de demostración y tienen
# que dar el mismo resultado cada corrida. Con el guard, lo que dejó la
# migración —que copió el guía viejo a los cinco grados— ganaba para siempre y
# la demo mostraba un coordinador en todos, que es exactamente lo contrario de
# lo que hay que mostrar.
gbol.each_value { |grado| grado.update!(coordinator_teacher: nil) }
gbol[:g1].update!(coordinator_teacher: tbol[:sos])
gbol[:g2].update!(coordinator_teacher: tbol[:mat])

# =============================================================================
# SECCIONES — todos los grados con A y B
# =============================================================================
puts ""
puts "🏫 Creando secciones..."

sec_bol = {}
gbol.each_with_index do |(key, grade), i|
  num = i + 1
  ["A", "B"].each do |letra|
    sec_bol["#{key}_#{letra}"] = Section.find_or_create_by!(
      name: letra, grade: grade, academic_period: periodo_bolivar
    ) { |s| s.capacity = 30; s.classroom = "Aula #{num}-#{letra}" }
  end
end

sec_bel = {}
gbel.each_with_index do |(key, grade), i|
  num = i + 1
  ["A", "B"].each do |letra|
    sec_bel["#{key}_#{letra}"] = Section.find_or_create_by!(
      name: letra, grade: grade, academic_period: periodo_bello
    ) { |s| s.capacity = 25; s.classroom = "Sala #{num}-#{letra}" }
  end
end

# Profesores guía, uno POR SECCIÓN (MOR-150).
#
# ⚠️ Que «A» y «B» tengan guías DISTINTOS es el punto de la demo: es exactamente
# lo que el modelo anterior no podía representar. Con el guía colgando del
# grado, el de «1er Año» pasaba lista de A y de B —de alumnos que no son
# suyos— y el guía de B no veía su propia sección.
#
# Se rotan los profesores del colegio para que ninguno quede con cinco
# secciones: un guía real tiene una, a lo sumo dos.
#
# ⚠️ Se asigna SIN `unless`, a diferencia de casi todo lo demás en este archivo.
# Los seeds son datos de demostración y tienen que dar el mismo resultado cada
# vez: con el guard, una corrida anterior —o lo que dejó una migración— gana
# para siempre y la demo termina mostrando el mismo profesor en las diez
# secciones, que es justo lo que este cambio vino a arreglar.
[ [ sec_bol, tbol ], [ sec_bel, tbel ] ].each do |secciones, profesores|
  docentes = profesores.values
  secciones.values.each_with_index do |seccion, i|
    seccion.update!(leader_teacher: docentes[i % docentes.size])
  end
end

puts "   ✓ #{sec_bol.size} secciones (Bolívar) | #{sec_bel.size} secciones (Bello), cada una con su guía"

# =============================================================================
# TEACHER SECTIONS — cobertura completa de todas las secciones
# Cada materia del grado debe tener UN profesor asignado por sección
# =============================================================================
puts ""
puts "📋 Asignando profesores a todas las secciones (cobertura completa)..."

# Helper
def asignar(teacher, section, subject)
  TeacherSection.find_or_create_by!(teacher: teacher, section: section, subject: subject)
end

# BOLÍVAR — mapeamos qué profesor da qué materia
# Quien dicta cada materia en Bolívar:
prof_materia_bol = {
  s_mat: :mat, s_len: :len, s_his: :sos, s_geo: :sos,
  s_bio: :bio, s_fis: :fis, s_qui: :fis,
  s_ing: :ing, s_art: :arte, s_edf: :edf, s_fil: :sos
}

# Mapa materia → profesor para Bolívar
asignacion_bol = {
  s[:mat] => tbol[:mat],
  s[:len] => tbol[:len],
  s[:his] => tbol[:sos],
  s[:geo] => tbol[:sos],
  s[:bio] => tbol[:bio],
  s[:fis] => tbol[:fis],
  s[:qui] => tbol[:fis],
  s[:ing] => tbol[:ing],
  s[:art] => tbol[:arte],
  s[:edf] => tbol[:edf],
  s[:fil] => tbol[:len] # Filosofía la imparte el de Lengua (común en liceos)
}

# Asignar a cada sección de Bolívar según las materias de su grado
sec_bol.each do |key, section|
  section.grade.subjects.each do |subject|
    prof = asignacion_bol[subject]
    asignar(prof, section, subject) if prof
  end
end

# ANDRÉS BELLO
asignacion_bel = {
  b[:mat] => tbel[:mat],
  b[:len] => tbel[:len],
  b[:sos] => tbel[:sos],
  b[:bio] => tbel[:cien],
  b[:fis] => tbel[:cien],
  b[:ing] => tbel[:ing],
  b[:art] => tbel[:arte],
  b[:edf] => tbel[:edf]
}

sec_bel.each do |key, section|
  section.grade.subjects.each do |subject|
    prof = asignacion_bel[subject]
    asignar(prof, section, subject) if prof
  end
end

puts "   ✓ #{TeacherSection.count} asignaciones creadas"

# =============================================================================
# ESTUDIANTES — 20 por sección en Bolívar, 15 en Bello
# =============================================================================
puts ""
puts "🎓 Creando alumnos..."

NOMBRES = %w[Álvaro Sofía Miguel Laura Andrés Valentina Carlos Isabella José María
             Luis Ana Diego Camila Rafael Daniela Fernando Paula Gabriel Natalia
             Sebastián Valeria Eduardo Lucía Omar Paola Héctor Gabriela Erick Verónica].freeze

APELLIDOS = %w[López Ramos Pérez Guzmán Mora Reyes Salinas Vargas Blanco Cruz
               Fuentes Jiménez Herrera Suárez Castillo Mendoza Rojas Torres García Silva
               Díaz Romero Fernández Ortega Soto Cabrera Medina Ríos Vega Parra].freeze

# El apellido NO puede salir del mismo índice que el nombre.
#
# Así estaba, y el resultado era que de las 900 combinaciones posibles
# (30 × 30) solo aparecían las 30 de la diagonal: en 200 alumnos, cada nombre
# repetido siete veces. La lista de alumnos mostraba "Blanco, José" tres
# veces seguidas y parecía un error del sistema en plena demostración.
#
#     mismo índice   → 30 pares distintos, el más repetido 7 veces
#     k*7 + k/30     → 200 pares distintos, ninguno repetido
#
# El `k*7` mezcla (7 es coprimo con 30, así que recorre los 30 apellidos) y el
# `k/30` desplaza el arranque en cada vuelta. Sigue siendo determinista: los
# seeds tienen que dar lo mismo en cada corrida.
def apellido_para(k)
  (k * 7 + k / APELLIDOS.size) % APELLIDOS.size
end

# El SEGUNDO apellido, con otro barajado para que no coincida con el primero.
# 11 también es coprimo con 30, así que recorre la lista entera sin repetir ciclo.
def segundo_apellido_para(k)
  (k * 11 + 3) % APELLIDOS.size
end

# La CÉDULA ESCOLAR que aquí se genera es SINTÉTICA y se nota a propósito.
#
# La real la asigna el MPPE y codifica nacionalidad, año de nacimiento y los
# últimos 8 dígitos de la cédula de la MADRE. No hay algoritmo público, así que
# inventarlo daría números que parecen válidos y no lo son —peor que uno que se
# ve claramente de prueba—.
#
# Lo que sí respeta es lo estructural, que es lo que el sistema tiene que
# soportar: 12 caracteres, ÚNICA EN TODO EL PAÍS (no por colegio), y derivada
# del año de nacimiento. El `k` es un contador global entre colegios: es
# justamente lo que `students.school_card` NO era, y por eso 90 alumnos
# compartían carnet entre Bolívar y Bello.
def cedula_escolar_para(k, anio_nacimiento)
  "V#{anio_nacimiento}#{(k * 37 + 1_000_000).to_s.rjust(7, '0')[0, 7]}"
end

# Un alumno de 4to grado tiene ~9 años; uno de 5to año, ~16. La fecha importa
# porque el MPPE la verifica contra la partida de nacimiento y calcula edad para
# prosecución — no es decorativa.
#
# La edad sale del NOMBRE del grado ("4to Grado" → 4) más la base de su nivel,
# no de `grades.level`: ese enum solo distingue primaria de secundaria, y dentro
# de secundaria un 1er año y un 5to año se llevan cuatro años de diferencia.
def nacimiento_para(grade, k)
  ordinal = grade.name[/\d+/].to_i
  base    = grade.primaria? ? 5 : 11      # 1er grado ≈ 6 años · 1er año ≈ 12
  edad    = base + (ordinal.zero? ? 1 : ordinal)
  Date.new(Date.current.year - edad, (k % 12) + 1, (k % 28) + 1)
end


def normalize(str)
  str.downcase.tr('áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUUN').downcase
end

# La identidad estable de un alumno es su CARNET, no su correo.
#
# Estaba buscado por correo, y el correo se deriva del nombre. En cuanto se
# cambió la lista de apellidos, cada alumno pasó a tener un correo distinto:
# `find_or_create_by!(email:)` creaba un usuario NUEVO y su alta chocaba contra
# el carnet del viejo —"Carnet ya está en uso"— dejando el seed a medio correr.
#
# Los seeds tienen que ser idempotentes ante cambios de CONTENIDO, no solo ante
# volver a correrlos con los mismos datos. Buscando por carnet, cambiar un
# nombre renombra al alumno que ya existe en vez de intentar duplicarlo.
# ⚠️ La búsqueda de respaldo va por CÉDULA ESCOLAR, no por correo.
#
# Desde `MOR-142` la mayoría de los alumnos no tiene correo, y
# `find_or_create_by!(email: nil)` **encuentra al primer alumno sin correo que
# haya** y lo devuelve como si fuera éste: 240 alumnos colapsados en uno. Es el
# mismo error que ya quemó estos seeds una vez —ver el comentario de arriba—,
# con otro campo.
#
# La cédula escolar sirve porque es única en todo el país y no se deriva del
# nombre: cambiar la lista de apellidos no la mueve.
def make_student(email:, nombre:, apellido:, segundo_apellido:, card:, school:,
                 cedula_escolar:, nacimiento:, sexo:)
  atributos = {
    first_name: nombre, last_name: apellido, second_last_name: segundo_apellido,
    cedula_escolar: cedula_escolar, birth_date: nacimiento, sex: sexo, email: email
  }

  existente = Student.find_by(school_card: card, school: school)
  if existente
    existente.user.update!(**atributos)
    return existente
  end

  u = Current.sin_aislamiento { User.find_by(cedula_escolar: cedula_escolar) }
  u ||= User.new(atributos).tap do |uu|
    # Contraseña SOLO si va a entrar. Un alumno de primaria no entra: quien
    # consulta sus notas es su representante. Y sin correo no hay forma de
    # recuperar nada, así que una contraseña ahí sobra por partida doble.
    uu.password = uu.password_confirmation = CLAVE_DE_PRUEBA if email.present?
    uu.save!
  end
  Student.create!(user: u, school_card: card, school: school)
end

# La cédula escolar es única EN TODO EL PAÍS, así que el contador que la
# alimenta tiene que ser global entre colegios. `school_card` no lo era —cada
# plantel arrancaba en 25-001— y por eso 90 de 290 alumnos compartían carnet
# entre Bolívar y Bello. Ese contador local se queda para `school_card`, que sí
# es interno del colegio; éste es aparte y no se reinicia.
k_nacional = 0

# Generar alumnos para Bolívar: 5 secciones x 20 = 100 alumnos
students_per_section_bol = {}
sec_bol.each_with_index do |(sec_key, section), sec_idx|
  students_per_section_bol[sec_key] = []
  20.times do |i|
    j        = sec_idx * 20 + i
    nombre   = NOMBRES[j % NOMBRES.size]
    apellido = APELLIDOS[apellido_para(j)]
    segundo  = APELLIDOS[segundo_apellido_para(j)]
    num      = (j + 1).to_s.rjust(3, "0")
    card     = "25-#{num}"
    # Correo SOLO en secundaria, y no es un detalle de los datos de prueba:
    # es la regla del dominio hecha visible. Un alumno de 3er grado tiene 8
    # años y no tiene correo; el bachiller de 5to sí puede tener uno.
    # Así los seeds cargan ~240 personas sin correo de una sola vez, que es
    # justo lo que el índice único plano no permitía (MOR-142).
    email    = section.grade.secundaria? ? "#{normalize(nombre)}.#{normalize(apellido)}#{num}@bolivar.edu" : nil
    nace     = nacimiento_para(section.grade, j)
    k_nacional += 1

    student = make_student(
      email: email, nombre: nombre, apellido: apellido, segundo_apellido: segundo,
      card: card, school: school_bolivar, nacimiento: nace, sexo: sexo_para(nombre),
      cedula_escolar: cedula_escolar_para(k_nacional, nace.year)
    )
    students_per_section_bol[sec_key] << student
  end
end
puts "   ✓ #{students_per_section_bol.values.flatten.size} alumnos (Bolívar)"

# Generar alumnos para Bello: 3 secciones x 15 = 45 alumnos
students_per_section_bel = {}
sec_bel.each_with_index do |(sec_key, section), sec_idx|
  students_per_section_bel[sec_key] = []
  15.times do |i|
    j        = sec_idx * 15 + i + 5
    nombre   = NOMBRES[j % NOMBRES.size]
    apellido = APELLIDOS[apellido_para(j)]
    segundo  = APELLIDOS[segundo_apellido_para(j)]
    num      = (sec_idx * 15 + i + 1).to_s.rjust(3, "0")
    card     = "25-#{num}"
    # Correo SOLO en secundaria, y no es un detalle de los datos de prueba:
    # es la regla del dominio hecha visible. Un alumno de 3er grado tiene 8
    # años y no tiene correo; el bachiller de 5to sí puede tener uno.
    # Así los seeds cargan ~240 personas sin correo de una sola vez, que es
    # justo lo que el índice único plano no permitía (MOR-142).
    email    = section.grade.secundaria? ? "#{normalize(nombre)}.#{normalize(apellido)}#{num}@bello.edu" : nil
    nace     = nacimiento_para(section.grade, j)
    k_nacional += 1

    student = make_student(
      email: email, nombre: nombre, apellido: apellido, segundo_apellido: segundo,
      card: card, school: school_bello, nacimiento: nace, sexo: sexo_para(nombre),
      cedula_escolar: cedula_escolar_para(k_nacional, nace.year)
    )
    students_per_section_bel[sec_key] << student
  end
end
puts "   ✓ #{students_per_section_bel.values.flatten.size} alumnos (Bello)"

# =============================================================================
# INSCRIPCIONES — todos los alumnos en su sección
# =============================================================================
puts ""
puts "📝 Inscribiendo alumnos..."

enroll_date = Date.new(2025, 9, 16)

students_per_section_bol.each do |sec_key, students|
  section = sec_bol[sec_key]
  students.each do |student|
    Enrollment.find_or_create_by!(student: student, section: section) do |e|
      e.enrollment_date = enroll_date; e.status = :regular
    end
  end
end

students_per_section_bel.each do |sec_key, students|
  section = sec_bel[sec_key]
  students.each do |student|
    Enrollment.find_or_create_by!(student: student, section: section) do |e|
      e.enrollment_date = enroll_date; e.status = :regular
    end
  end
end

puts "   ✓ #{Enrollment.count} inscripciones creadas"

# =============================================================================
# NOTAS — 1er Año A de Bolívar, para poder VER el cálculo (MOR-93)
# =============================================================================
#
# Cada alumno de esta lista existe para hacer visible una regla del Reglamento
# General de la LOE. No son notas de relleno: son los casos que el cálculo tiene
# que resolver bien, y que hay que poder mirar en pantalla.
#
#   #1  buen alumno            → aprueba cómodo
#   #2  9,50 exacto            → Art. 108: sube a 10 y APRUEBA. Un décimo abajo repite.
#   #3  aplazado con reparación → Art. 112: la nota de la segunda oportunidad manda
#   #4  sin ninguna nota        → sale SIN nota, nunca con cero
#   #5  una actividad sin corregir → esa evaluación sale del promedio con su peso
#
# Castellano va solo en el primer lapso a propósito: sirve para ver que un año a
# medio andar no promedia como si estuviera completo.
puts ""
puts "📝 Cargando notas de Matemática y Castellano (1er Año A, Bolívar)..."

seccion_notas = sec_bol["g1_A"]
alumnos_notas = students_per_section_bol["g1_A"]
lapsos_bol    = EvaluationMoment.where(academic_period: periodo_bolivar).order(:id).to_a

# Examen 40 % · Taller 30 % · Participación 30 % — suman el 100 % del lapso.
PONDERACION = [["Examen", 40.0], ["Taller", 30.0], ["Participación", 30.0]].freeze

# Fechas dentro del año escolar 2025-2026: los lapsos venezolanos cierran en
# diciembre, abril y julio (Art. 110 del Reglamento).
MESES_POR_LAPSO = [[2025, 11], [2026, 3], [2026, 6]].freeze

def actividades_de(seccion, materia, lapso, indice_lapso, cuantas: PONDERACION.size)
  anio, mes = MESES_POR_LAPSO[indice_lapso]

  PONDERACION.first(cuantas).map.with_index do |(nombre, peso), i|
    EvaluationActivity.find_or_create_by!(
      section: seccion, subject: materia, evaluation_moment: lapso,
      description: "#{nombre} — #{lapso.name}"
    ) do |a|
      a.weight_percentage = peso
      a.date_scheduled    = Date.new(anio, mes, 5 + i * 7)
    end
  end
end

# [examen, taller, participación] por lapso. `nil` = sin cargar.
NOTAS_MATEMATICA = {
  1 => [[18, 19, 17], [17, 18, 16], [19, 20, 18]],   # buen alumno
  2 => [[11,  9,  8], [11,  9,  8], [11,  9,  8]],   # 9,50 exacto en los tres → 10
  3 => [[ 7,  9,  8], [ 8,  8,  8], [ 9,  9,  9]],   # aplazado → reparación
  4 => [nil, nil, nil],                              # sin una sola nota cargada
  5 => [[16, nil, nil], nil, nil]                    # solo el examen corregido
}.freeze

materia_mat = s[:mat]
materia_len = s[:len]

lapsos_bol.each_with_index do |lapso, li|
  actividades = actividades_de(seccion_notas, materia_mat, lapso, li)

  alumnos_notas.each_with_index do |alumno, ai|
    puesto = ai + 1
    fila   = NOTAS_MATEMATICA[puesto]

    puntajes =
      if fila
        fila[li]
      else
        # El resto de la sección: notas verosímiles y estables entre corridas.
        base = 10 + ((puesto * 7 + li * 3) % 9)
        [base, base + 1, base - 1].map { |n| n.clamp(1, 20) }
      end

    next if puntajes.nil?

    actividades.each_with_index do |act, i|
      next if puntajes[i].nil?

      ActivityGrade.find_or_create_by!(evaluation_activity: act, student: alumno) do |g|
        g.score = puntajes[i]
      end
    end
  end
end

# Castellano: SOLO el primer lapso, y con el lapso a medio definir — Examen 40 %
# y Taller 30 %, sin la Participación. Son dos casos de QA en uno:
#
#   · el medidor de ponderación tiene que mostrar "faltan 30 %"
#   · el promedio se calcula sobre el 70 % cargado, no sobre 100
#
# Y como Castellano lo dicta otro profesor (prof.torres), sirve además para ver
# que cada uno solo alcanza lo suyo: García no ve estas evaluaciones.
actividades_len = actividades_de(seccion_notas, materia_len, lapsos_bol.first, 0, cuantas: 2)
alumnos_notas.each_with_index do |alumno, ai|
  base = 11 + ((ai * 5) % 8)
  actividades_len.each_with_index do |act, i|
    ActivityGrade.find_or_create_by!(evaluation_activity: act, student: alumno) do |g|
      g.score = (base + i - 1).clamp(1, 20)
    end
  end
end

# =============================================================================
# BELLO · PRIMARIA — notas para que la escala literal se pueda VER (MOR-129)
# =============================================================================
#
# Bolívar demuestra el régimen numérico. Sin esto, el literal A–E no aparecía en
# ninguna pantalla: los seeds solo alimentaban a Bolívar, así que primaria —que
# es la mayoría del mercado— quedaba sin una sola nota que mostrar.
#
# Las notas están elegidas para que la sección recorra **las cinco letras**. Un
# solo alumno con 19 demuestra que el mapa existe; cinco alumnos repartidos
# demuestran que los cortes están donde Cyndi dijo, y de paso dejan a la vista
# el que más importa: la E, que es reprobado.
#
#     20 → A       17 → B       15 → C       11 → D       8 → E
#
# Se carga la MISMA nota en las tres evaluaciones de los tres lapsos, así el
# anual da exactamente ese número (Art. 111: promedio simple de los lapsos) y el
# literal se lee sin tener que hacer cuentas para verificarlo.
seccion_bel   = sec_bel["g1_A"]                                    # 4to Grado A
alumnos_bel   = students_per_section_bel["g1_A"] || []
lapsos_bel    = EvaluationMoment.where(academic_period: periodo_bello).order(:id).to_a
materia_bel   = b[:mat]

LITERALES_DEMO = [20, 17, 15, 11, 8].freeze                        # A · B · C · D · E

lapsos_bel.each_with_index do |lapso, li|
  actividades = actividades_de(seccion_bel, materia_bel, lapso, li)

  alumnos_bel.each_with_index do |alumno, ai|
    objetivo = LITERALES_DEMO[ai] || (10 + ((ai * 3) % 11)).clamp(1, 20)

    actividades.each do |act|
      ActivityGrade.find_or_create_by!(evaluation_activity: act, student: alumno) do |g|
        g.score = objetivo
      end
    end
  end
end

puts "   ✓ #{EvaluationActivity.count} actividades · #{ActivityGrade.count} notas cargadas"
puts "     Bello · 4to Grado A: #{alumnos_bel.size} alumnos con nota anual, recorriendo A–E"

# =============================================================================
# ASISTENCIA — dos semanas de historia, para que el reporte tenga qué mostrar
# =============================================================================
#
# Sin datos, la pantalla de inasistencias es una tabla vacía y no se puede
# evaluar si sirve. Con dos semanas se ve lo que el colegio necesita ver: quién
# acumula faltas, quién llega tarde seguido, y quién ya trajo el justificativo.
#
# El profesor guía es quien la toma (MOR-111), y desde MOR-150 es guía de la
# SECCIÓN. Se fuerza a García en «1er Año A» porque es la credencial que sale en
# el README: quien entre con ella tiene que ver la pantalla con datos, no un
# «sin secciones a cargo».
puts ""
puts "🗓️  Registrando asistencia de las últimas dos semanas..."

sec_bol["g1_A"].update!(leader_teacher: Teacher.find_by(user: User.find_by(email: "prof.garcia@bolivar.edu")))

seccion_asis = sec_bol["g1_A"]
alumnos_asis = students_per_section_bol["g1_A"]
inscripciones_asis = Enrollment.where(section: seccion_asis, student: alumnos_asis).order(:id).to_a

# Diez días hábiles hacia atrás. Los patrones están elegidos para que el reporte
# muestre casos distintos y no una lista plana:
#
#   · el alumno 1 no falta nunca
#   · el 2 acumula 4 faltas SIN justificar   → el caso que dispara una llamada
#   · el 3 falta 2 veces y las dos JUSTIFICADAS → no debe aparecer en el reporte
#   · el 4 llega tarde seguido, que no es lo mismo que faltar
FALTAS = { 2 => [1, 3, 5, 8], 3 => [2, 6] }.freeze
TARDES = { 4 => [1, 2, 4, 7, 9] }.freeze

# Los diez días se cuentan hacia atrás desde el FINAL del lapso que se está
# evaluando, no desde hoy.
#
# Contándolos desde hoy caían fuera del año escolar —en agosto, entre un año y
# el siguiente— y el boletín del primer lapso mostraba cero inasistencias con
# once registros cargados. El dato existía y no se veía, que es la peor de las
# dos maneras de que algo esté mal.
lapso_asis = EvaluationMoment.where(academic_period: periodo_bolivar).order(:id).first
ultimo_dia = [ lapso_asis&.ends_on || Date.current, Date.current ].min

dias_habiles = (0..19).map { |d| ultimo_dia - d }
                      .reject { |f| f.saturday? || f.sunday? }
                      .first(10).reverse

dias_habiles.each_with_index do |dia, di|
  inscripciones_asis.each_with_index do |inscripcion, ai|
    puesto = ai + 1
    estado =
      if FALTAS[puesto]&.include?(di) then :ausente
      elsif TARDES[puesto]&.include?(di) then :tarde
      else :presente
      end

    registro = Attendance.find_or_initialize_by(enrollment: inscripcion, date: dia)
    registro.status = estado
    registro.recorded_by = User.find_by(email: "prof.garcia@bolivar.edu")

    # El alumno 3 sí trajo el justificativo: la secretaría lo cargó al día
    # siguiente. Sirve para ver que el reporte NO lo cuenta.
    if puesto == 3 && estado == :ausente
      registro.justificacion   = "Reposo médico presentado por el representante"
      registro.justificada_en  = dia + 1
      registro.justificada_por = User.find_by(email: "director.bolivar@siga.edu")
    end

    registro.save!
  end
end

# =============================================================================
# SUSCRIPCIONES (MOR-108)
# =============================================================================
#
# Los dos colegios con estados distintos, para poder VER la degradación a solo
# lectura sin tener que fabricarla a mano:
#
#   · Bolívar (200 alumnos) → plan Estándar, al día
#   · Bello   (90 alumnos)  → plan Básico, VENCIDO hace 30 días
#
# Bello vencido es el caso que hay que poder mirar: entra, ve todo, descarga
# boletines y constancias, y no puede cargar una nota. Cortarle el acceso a
# mitad de año escolar sería quitarle las notas a sus alumnos.
puts ""
puts "💳 Registrando suscripciones..."

[
  { colegio: school_bolivar, vence_en: 20,  estado: :activa },
  { colegio: school_bello,   vence_en: -30, estado: :vencida }
].each do |datos|
  alumnos = Subscription.matricula_de(datos[:colegio].id)
  Subscription.find_or_create_by!(school: datos[:colegio]) do |s|
    s.plan = Subscription.plan_para(alumnos)
    s.matricula_facturada = alumnos
    s.precio_mensual = Subscription.precio_para(alumnos)
    s.vigente_desde = Date.current - 1.month
    s.vigente_hasta = Date.current + datos[:vence_en].days
    s.status = datos[:estado]
    s.dias_de_gracia = 15
  end
end

Subscription.all.each do |s|
  puts "   ✓ #{s.school.name.ljust(22)} #{s.etiqueta_de_plan.ljust(10)} $#{s.precio_mensual.to_s.ljust(4)} #{s.etiqueta_de_estado}"
end
puts "     Bello está VENCIDO a propósito: entra y ve todo, pero no puede cargar nada nuevo"

# =============================================================================
# EL EQUIPO DE SIGA (MOR-133)
# =============================================================================
#
# No pertenece a ningún colegio, y esa es toda la corrección: hasta ahora "la
# gente de SIGA" era un `Admin` con rol `desarrollador`, y un `Admin` cuelga de
# un colegio. Esa confusión produjo cuatro fugas en dos días.
puts ""
puts "🛠️  Registrando al equipo de SIGA..."

usuario_siga = User.find_or_create_by!(email: CORREO_DESARROLLADOR) do |u|
  u.first_name = "Equipo"; u.last_name = "SIGA"
  u.document = documento_de_prueba(CORREO_DESARROLLADOR); u.document_type = :cedula_v
  u.password = u.password_confirmation = CLAVE_DE_PRUEBA
end
SigaStaff.find_or_create_by!(user: usuario_siga) { |s| s.role = :fundador }

operaciones = User.find_or_create_by!(email: "operaciones@siga.app") do |u|
  u.first_name = "Ana"; u.last_name = "Operaciones"
  u.document = documento_de_prueba("operaciones@siga.app"); u.document_type = :cedula_v
  u.sex = :female
  u.password = u.password_confirmation = CLAVE_DE_PRUEBA
end
SigaStaff.find_or_create_by!(user: operaciones) { |s| s.role = :operaciones }

puts "   ✓ #{SigaStaff.count} personas en el equipo, NINGUNA con colegio"
puts "     #{usuario_siga.email} (fundador) · operaciones@siga.app (operaciones)"

# =============================================================================
# REPRESENTANTES (MOR-110)
# =============================================================================
#
# Tres casos, y el tercero es el que decide la arquitectura:
#
#   1. Una madre con UN hijo — el caso común, y el que entra directo al detalle.
#   2. Un padre con DOS hijos en el mismo colegio, en grados distintos.
#   3. Una madre con hijos en LOS DOS COLEGIOS. Su usuario es uno, sus
#      inquilinos son dos: es lo que obliga al selector de colegio, y sin
#      sembrarlo no hay forma de ver si funciona.
puts ""
puts "👨‍👩‍👧 Registrando representantes..."

# `email:` puede ser nil, y por eso la búsqueda va por DOCUMENTO: con
# `find_or_create_by!(email: nil)` la segunda representante sin correo
# encontraría a la primera y se quedaría con sus hijos (MOR-142).
#
# `documento_de_prueba` se deriva del nombre justamente para poder identificarla
# cuando no hay correo del cual derivar nada.
def representante!(nombre:, apellido:, telefono:, colegio:, alumnos:,
                   email: nil, parentesco: :madre)
  # ⚠️ Normalizar ANTES de preguntar. `documento_de_prueba` devuelve
  # `"V-12345678"`, pero en la base vive `"12345678"`: el modelo le quita la
  # letra y los signos al guardar (MOR-142). Buscar el valor crudo no encuentra
  # nada y la segunda llamada intenta crear a la misma persona otra vez —
  # exactamente el error que este issue vino a arreglar, cometido acá.
  documento = User.normalizar_documento(
    documento_de_prueba(email.presence || "#{nombre}.#{apellido}"), :cedula_v
  )

  usuario = Current.sin_aislamiento { User.find_by(document: documento) }
  usuario ||= User.create!(
    first_name: nombre, last_name: apellido, email: email,
    document: documento, document_type: :cedula_v,
    sex: parentesco == :padre ? :male : :female,
    # Sin correo no hay contraseña: nadie se la podría hacer llegar, y
    # "Olvidé mi contraseña" tampoco tiene a dónde escribir. Queda esperando
    # el código de activación (`MOR-143`).
    password: (CLAVE_DE_PRUEBA if email.present?)
  )
  rep = Representative.find_or_create_by!(user: usuario, school: colegio) { |r| r.phone = telefono }
  Array(alumnos).each do |alumno|
    StudentRepresentative.find_or_create_by!(representative: rep, student: alumno) do |v|
      v.parentesco = parentesco
      v.principal  = true
    end
  end
  rep
end

alumnos_bol_1a = students_per_section_bol["g1_A"]
alumnos_bol_2a = students_per_section_bol["g2_A"]
alumnos_bel_1a = students_per_section_bel["g1_A"]

# 1 · Un hijo. Entra y ve directamente su boletín.
representante!(email: "carmen.lopez@familia.test", nombre: "Carmen", apellido: "López",
               telefono: "0414-1112233", colegio: school_bolivar,
               alumnos: alumnos_bol_1a[0], parentesco: :madre)

# 2 · Dos hijos en el mismo colegio, grados distintos.
representante!(email: "jose.ramos@familia.test", nombre: "José", apellido: "Ramos",
               telefono: "0424-4445566", colegio: school_bolivar,
               alumnos: [alumnos_bol_1a[1], alumnos_bol_2a[0]], parentesco: :padre)

# 3 · EL CASO DIFÍCIL: hijos en los dos colegios. Dos filas de Representative,
#     una por colegio — igual que un profesor que trabaja en dos. El selector de
#     la pantalla desempata, y solo entre estos dos.
representante!(email: "maria.perez@familia.test", nombre: "María", apellido: "Pérez",
               telefono: "0412-7778899", colegio: school_bolivar,
               alumnos: alumnos_bol_1a[2], parentesco: :madre)
representante!(email: "maria.perez@familia.test", nombre: "María", apellido: "Pérez",
               telefono: "0412-7778899", colegio: school_bello,
               alumnos: alumnos_bel_1a[0], parentesco: :madre)

# 4 · SIN CORREO — el caso que va a producir el importador en masa.
#     Existe, está vinculada a su hija, aparece en los listados… y no puede
#     entrar. Sin sembrarlo no hay forma de VER cómo se ve eso en pantalla
#     antes de que le pase a un colegio de verdad (MOR-142).
representante!(nombre: "Yolanda", apellido: "Guerra",
               telefono: "0416-3334455", colegio: school_bello,
               alumnos: alumnos_bel_1a[1], parentesco: :madre)

puts "   ✓ #{Representative.count} vínculos de representación · #{StudentRepresentative.count} alumnos representados"
puts "     maría.pérez tiene hijos en LOS DOS colegios: #{Representative.where(user: User.find_by(email: 'maria.perez@familia.test')).count} filas"

sin_justificar = Attendance.sin_justificar.count
puts "   ✓ #{Attendance.count} registros en #{dias_habiles.size} días hábiles"
puts "     #{sin_justificar} faltas sin justificar · #{Attendance.where(status: :tarde).count} tardanzas · #{Attendance.where.not(justificada_en: nil).count} justificadas"

# No hace falta llamar a GradeCalculator: desde MOR-96 cada nota recalcula sola
# su lapso y su anual al guardarse. Que los contadores de abajo den distinto de
# cero es la prueba de que el cable está puesto.

# La reparación del alumno #3, después de calcular el anual (Art. 112).
inscripcion_3 = Enrollment.find_by(student: alumnos_notas[2], section: seccion_notas)
FinalGradeBook.find_by(enrollment: inscripcion_3, subject: materia_mat)&.tap do |fgb|
  fgb.update!(remedial_exam_score: 12)
end
GradeCalculator.calculate_final_grade(enrollment: inscripcion_3, subject: materia_mat)

puts "   ✓ #{MomentGrade.count} notas de lapso · #{FinalGradeBook.count} notas definitivas calculadas"
puts ""
PISTA_DEL_CASO = {
  1 => "← anual = promedio simple de los lapsos (Art. 111)",
  2 => "← Art. 108: crudo daba 9,50 y sube a 10. APRUEBA",
  5 => "← solo el examen (40 %): promedia sobre 40, no sobre 100"
}.freeze

puts "   Los cinco casos que hay que poder ver (Matemática, 1er Año A):"
[1, 2, 3, 4, 5].each do |puesto|
  alumno = alumnos_notas[puesto - 1]
  insc   = Enrollment.find_by(student: alumno, section: seccion_notas)
  fgb    = FinalGradeBook.find_by(enrollment: insc, subject: materia_mat)
  lapsos = MomentGrade.where(enrollment: insc, subject: materia_mat).order(:evaluation_moment_id)
                      .pluck(:final_moment_score).map(&:to_i)

  detalle = if fgb.nil?
              "SIN NOTA".ljust(22) + "← no es cero: no hay nada cargado"
            elsif fgb.remedial_exam_score.present?
              "anual #{fgb.annual_average.to_i} + rep. #{fgb.remedial_exam_score.to_i} → #{fgb.final_score.to_i}".ljust(23) +
                "← Art. 112, la segunda oportunidad manda"
            else
              "lapsos #{lapsos.join('·')} → #{fgb.final_score.to_i}".ljust(22) + PISTA_DEL_CASO.fetch(puesto, "")
            end

  puts "   ##{puesto} #{alumno.user.nombre_completo}".ljust(30) + detalle
end

# =============================================================================
# RESUMEN FINAL
# =============================================================================
puts ""
puts "=" * 60
puts "✅ Seeds completados exitosamente"
puts "=" * 60
puts ""
puts "📊 Resumen:"
puts "   Escuelas:          #{School.count}"
puts "   Períodos:          #{AcademicPeriod.count}"
puts "   Departamentos:     #{Department.count}"
puts "   Materias:          #{Subject.count}"
puts "   Grados:            #{Grade.count}"
puts "   Secciones:         #{Section.count}"
puts "   Asignaciones:      #{TeacherSection.count} (profesor-materia-sección)"
puts "   Administradores:   #{Admin.count}"
puts "   Profesores:        #{Teacher.count}"
puts "   Alumnos:       #{Student.count}"
puts "   Inscripciones:     #{Enrollment.count}"
puts ""
puts "🔑 Credenciales (contraseña universal: #{CLAVE_DE_PRUEBA})"
puts ""
puts "   ADMINISTRADORES:"
puts "   #{CORREO_DESARROLLADOR.ljust(28)} → equipo de SIGA · /siga (NO pertenece a ningún colegio)"
puts "   director.bolivar@siga.edu    → director (Bolívar)"
puts "   coord.bolivar@siga.edu       → coordinador (Bolívar)"
puts "   director.bello@siga.edu      → director (Bello)"
puts ""
puts "   PROFESORES BOLÍVAR:"
puts "   prof.garcia@bolivar.edu      → Matemática"
puts "   prof.torres@bolivar.edu      → Castellano y Literatura"
puts "   prof.herrera@bolivar.edu     → Historia / Geografía / Filosofía"
puts "   prof.mendoza@bolivar.edu     → Biología"
puts "   prof.rivas@bolivar.edu       → Física / Química"
puts "   prof.castillo@bolivar.edu    → Inglés"
puts "   prof.moreno@bolivar.edu      → Arte y Patrimonio"
puts "   prof.rojas@bolivar.edu       → Educación Física"
puts ""
puts "   ESTUDIANTES (ejemplo) — solo los de SECUNDARIA tienen correo:"
puts "   alvaro.lopez001@bolivar.edu  → 1er Año A"
puts "   sofia.ramos002@bolivar.edu   → 1er Año A"
puts ""
alumnos_sin_correo = Current.sin_aislamiento do
  Student.unscoped.joins(:user).where(users: { email: nil }).count
end
puts "   Los #{alumnos_sin_correo} alumnos de PRIMARIA (Bello) no tienen correo ni contraseña,"
puts "   que es el caso normal: quien consulta sus notas es su representante."
puts "   Para ver la vista de primaria —notas por literal A–E— entra como"
puts "   director.bello@siga.edu o como carmen.lopez@familia.test."
puts ""
puts "   REPRESENTANTES:"
puts "   carmen.lopez@familia.test    → una hija en Bolívar"
puts "   jose.ramos@familia.test      → dos hijos en Bolívar, grados distintos"
puts "   maria.perez@familia.test     → hijos en LOS DOS colegios (selector de colegio)"
puts "   Yolanda Guerra (Bello)       → SIN CORREO: existe, aparece en el listado,"
puts "                                  y no puede entrar hasta que se lo carguen."
