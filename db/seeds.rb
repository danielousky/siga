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

school_bolivar = School.find_or_create_by!(dea_code: "BOL-001") do |s|
  s.name = "U.E. Simón Bolívar"; s.location = "Caracas, Distrito Capital"; s.school_type = :secondary
end
# Bello es de PRIMARIA a propósito (MOR-129): sin un colegio de primaria
# sembrado, la escala literal A–E no se puede ver funcionando en ninguna
# pantalla — y primaria es la mayoría de los ~3.900 colegios privados del país.
#
# El contraste entre los dos colegios es además el mejor material de la demo:
# mismo sistema, mismas pantallas, y cada uno calificando como le corresponde.
school_bello = School.find_or_create_by!(dea_code: "AND-002") do |s|
  s.name = "U.E. Andrés Bello"; s.location = "Valencia, Carabobo"; s.school_type = :primary
end
puts "   ✓ #{school_bolivar.name} | ✓ #{school_bello.name}"

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
LAPSOS_TRES = [
  { name: "Primer Lapso",  weight: 30.0 },
  { name: "Segundo Lapso", weight: 30.0 },
  { name: "Tercer Lapso",  weight: 40.0 }
].freeze

# 2026-2027 estrena una estructura DISTINTA a propósito: dos lapsos al 50 %.
# Sirve para ver que reorganizar la evaluación de un año nuevo no toca en nada
# la del año anterior ni las notas ya calculadas.
LAPSOS_DOS = [
  { name: "Primer Semestre", weight: 50.0 },
  { name: "Segundo Semestre", weight: 50.0 }
].freeze

{
  periodo_bolivar           => LAPSOS_TRES,
  periodo_bello             => LAPSOS_TRES,
  periodo_bolivar_siguiente => LAPSOS_DOS
}.each do |periodo, lapsos|
  lapsos.each do |lapso|
    EvaluationMoment.find_or_create_by!(name: lapso[:name], academic_period: periodo) do |m|
      m.weight = lapso[:weight]
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

# --- ANDRÉS BELLO — PRIMARIA ---
# Grados, no años: en Venezuela primaria va de 1er a 6to GRADO, y media general
# de 1er a 5to AÑO. La palabra distingue el nivel y un director lo nota.
#
# Al ser `level: :primaria`, cada grado nace con `escala: :literal` (MOR-129):
# sus boletines dicen "A (19)" donde los de Bolívar dicen "19".
gbel = {}
[
  { key: :g1, name: "4to Grado", level: :primaria,
    subjects: [b[:mat], b[:len], b[:sos], b[:bio], b[:ing], b[:art], b[:edf]] },
  { key: :g2, name: "5to Grado", level: :primaria,
    subjects: [b[:mat], b[:len], b[:sos], b[:bio], b[:ing], b[:art], b[:edf]] },
  { key: :g3, name: "6to Grado", level: :primaria,
    subjects: [b[:mat], b[:len], b[:sos], b[:fis], b[:ing], b[:art], b[:edf]] }
].each do |g|
  grade = Grade.find_or_create_by!(name: g[:name], school: school_bello) do |gr|
    gr.level  = g[:level]
    gr.escala = :literal
  end
  g[:subjects].each { |subj| GradeSubject.find_or_create_by!(grade: grade, subject: subj) }
  gbel[g[:key]] = grade
end
puts "   ✓ 3 grados Bello · PRIMARIA, escala literal A–E (#{gbel[:g1].grade_subjects.count} materias por grado)"

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
    uu.name = d[:name]; uu.last_name = d[:last_name]
  end
  Admin.find_or_create_by!(user: u) { |a| a.school = d[:school]; a.role = d[:role] }
end
puts "   ✓ 4 administradores"

# =============================================================================
# PROFESORES - Un especialista por área
# =============================================================================
puts ""
puts "👨‍🏫 Creando profesores..."

def make_teacher(email, name, last_name, id_card, school)
  u = User.find_or_create_by!(email: email) do |uu|
    uu.password = uu.password_confirmation = CLAVE_DE_PRUEBA
    uu.name = name; uu.last_name = last_name; uu.id_card = id_card
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

# Asignar directores de grado
gbol[:g1].update!(leader_teacher: tbol[:sos]) unless gbol[:g1].leader_teacher
gbol[:g2].update!(leader_teacher: tbol[:mat]) unless gbol[:g2].leader_teacher
gbol[:g3].update!(leader_teacher: tbol[:bio]) unless gbol[:g3].leader_teacher
gbol[:g4].update!(leader_teacher: tbol[:fis]) unless gbol[:g4].leader_teacher
gbol[:g5].update!(leader_teacher: tbol[:len]) unless gbol[:g5].leader_teacher

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

puts "   ✓ #{sec_bol.size} secciones (Bolívar) | #{sec_bel.size} secciones (Bello)"

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
puts "🎓 Creando estudiantes..."

NOMBRES = %w[Álvaro Sofía Miguel Laura Andrés Valentina Carlos Isabella José María
             Luis Ana Diego Camila Rafael Daniela Fernando Paula Gabriel Natalia
             Sebastián Valeria Eduardo Lucía Omar Paola Héctor Gabriela Erick Verónica].freeze

APELLIDOS = %w[López Ramos Pérez Guzmán Mora Reyes Salinas Vargas Blanco Cruz
               Fuentes Jiménez Herrera Suárez Castillo Mendoza Rojas Torres García Silva
               Díaz Romero Fernández Ortega Soto Cabrera Medina Ríos Vega Parra].freeze

def normalize(str)
  str.downcase.tr('áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUUN').downcase
end

def make_student(email, name, last_name, card, school)
  u = User.find_or_create_by!(email: email) do |uu|
    uu.password = uu.password_confirmation = CLAVE_DE_PRUEBA
    uu.name = name; uu.last_name = last_name
  end
  Student.find_or_create_by!(user: u) { |st| st.school_card = card; st.school = school }
end

# Generar estudiantes para Bolívar: 5 secciones x 20 = 100 estudiantes
students_per_section_bol = {}
sec_bol.each_with_index do |(sec_key, section), sec_idx|
  students_per_section_bol[sec_key] = []
  20.times do |i|
    nombre   = NOMBRES[(sec_idx * 20 + i) % NOMBRES.size]
    apellido = APELLIDOS[(sec_idx * 20 + i) % APELLIDOS.size]
    num      = (sec_idx * 20 + i + 1).to_s.rjust(3, "0")
    card     = "25-#{num}"
    email    = "#{normalize(nombre)}.#{normalize(apellido)}#{num}@bolivar.edu"

    student = make_student(email, nombre, apellido, card, school_bolivar)
    students_per_section_bol[sec_key] << student
  end
end
puts "   ✓ #{students_per_section_bol.values.flatten.size} estudiantes (Bolívar)"

# Generar estudiantes para Bello: 3 secciones x 15 = 45 estudiantes
students_per_section_bel = {}
sec_bel.each_with_index do |(sec_key, section), sec_idx|
  students_per_section_bel[sec_key] = []
  15.times do |i|
    nombre   = NOMBRES[(sec_idx * 15 + i + 5) % NOMBRES.size]
    apellido = APELLIDOS[(sec_idx * 15 + i + 5) % APELLIDOS.size]
    num      = (sec_idx * 15 + i + 1).to_s.rjust(3, "0")
    card     = "25-#{num}"
    email    = "#{normalize(nombre)}.#{normalize(apellido)}#{num}@bello.edu"

    student = make_student(email, nombre, apellido, card, school_bello)
    students_per_section_bel[sec_key] << student
  end
end
puts "   ✓ #{students_per_section_bel.values.flatten.size} estudiantes (Bello)"

# =============================================================================
# INSCRIPCIONES — todos los estudiantes en su sección
# =============================================================================
puts ""
puts "📝 Inscribiendo estudiantes..."

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
# El profesor guía es quien la toma (MOR-111), así que primero hay que asignarlo:
# sin `leader_teacher`, la pantalla de asistencia no le aparece a nadie.
puts ""
puts "🗓️  Registrando asistencia de las últimas dos semanas..."

gbol[:g1].update!(leader_teacher: Teacher.find_by(user: User.find_by(email: "prof.garcia@bolivar.edu")))

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

dias_habiles = (0..13).map { |d| Date.current - d }.reject { |f| f.saturday? || f.sunday? }.first(10)

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
  u.name = "Equipo"; u.last_name = "SIGA"
  u.password = u.password_confirmation = CLAVE_DE_PRUEBA
end
SigaStaff.find_or_create_by!(user: usuario_siga) { |s| s.role = :fundador }

operaciones = User.find_or_create_by!(email: "operaciones@siga.app") do |u|
  u.name = "Ana"; u.last_name = "Operaciones"
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

def representante!(email:, nombre:, apellido:, telefono:, colegio:, alumnos:, parentesco: :madre)
  usuario = User.find_or_create_by!(email: email) do |u|
    u.name = nombre; u.last_name = apellido; u.password = u.password_confirmation = CLAVE_DE_PRUEBA
  end
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

  puts "   ##{puesto} #{alumno.user.name} #{alumno.user.last_name}".ljust(30) + detalle
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
puts "   Estudiantes:       #{Student.count}"
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
puts "   ESTUDIANTES (ejemplo):"
puts "   alvaro.lopez001@bolivar.edu  → 1er Año A"
puts "   sofia.ramos002@bolivar.edu   → 1er Año A"
puts "   paula.medina001@bello.edu    → 4to Grado A (Bello · PRIMARIA, notas por literal A–E)"
