# =============================================================================
# SIGA - Seeds de Desarrollo
# Pensum venezolano completo con cobertura total de secciones
# =============================================================================

puts "🌱 Iniciando carga de datos de prueba..."
puts ""

# =============================================================================
# ESCUELAS
# =============================================================================
puts "📚 Creando escuelas..."

school_bolivar = School.find_or_create_by!(dea_code: "BOL-001") do |s|
  s.name = "U.E. Simón Bolívar"; s.location = "Caracas, Distrito Capital"; s.school_type = :secondary
end
school_bello = School.find_or_create_by!(dea_code: "AND-002") do |s|
  s.name = "U.E. Andrés Bello"; s.location = "Valencia, Carabobo"; s.school_type = :secondary
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
puts "   ✓ Períodos 2025-2026 creados"

# =============================================================================
# MOMENTOS DE EVALUACIÓN
# =============================================================================
puts "📊 Creando momentos de evaluación..."

momento1 = EvaluationMoment.find_or_create_by!(name: "Primer Lapso")  { |m| m.weight = 30.0 }
momento2 = EvaluationMoment.find_or_create_by!(name: "Segundo Lapso") { |m| m.weight = 30.0 }
momento3 = EvaluationMoment.find_or_create_by!(name: "Tercer Lapso")  { |m| m.weight = 40.0 }
puts "   ✓ Tres lapsos (30% / 30% / 40%)"

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
    edufisica:   { school: school_bolivar, name: "Educación Física" },
  },
  bello: {
    matematica:  { school: school_bello, name: "Matemática" },
    ciencias:    { school: school_bello, name: "Ciencias Naturales" },
    sociales:    { school: school_bello, name: "Ciencias Sociales" },
    lengua:      { school: school_bello, name: "Lengua y Literatura" },
    idiomas:     { school: school_bello, name: "Idiomas Modernos" },
    arte:        { school: school_bello, name: "Arte y Cultura" },
    edufisica:   { school: school_bello, name: "Educación Física" },
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
s[:mat]  = Subject.find_or_create_by!(code: "BOL-MAT")  { |x| x.name = "Matemática";                x.department = dept[:bolivar][:matematica] }
s[:bio]  = Subject.find_or_create_by!(code: "BOL-BIO")  { |x| x.name = "Biología";                  x.department = dept[:bolivar][:ciencias] }
s[:fis]  = Subject.find_or_create_by!(code: "BOL-FIS")  { |x| x.name = "Física";                    x.department = dept[:bolivar][:ciencias] }
s[:qui]  = Subject.find_or_create_by!(code: "BOL-QUI")  { |x| x.name = "Química";                   x.department = dept[:bolivar][:ciencias] }
s[:his]  = Subject.find_or_create_by!(code: "BOL-HIS")  { |x| x.name = "Historia de Venezuela";     x.department = dept[:bolivar][:sociales] }
s[:geo]  = Subject.find_or_create_by!(code: "BOL-GEO")  { |x| x.name = "Geografía de Venezuela";    x.department = dept[:bolivar][:sociales] }
s[:len]  = Subject.find_or_create_by!(code: "BOL-LEN")  { |x| x.name = "Castellano y Literatura";   x.department = dept[:bolivar][:lengua] }
s[:ing]  = Subject.find_or_create_by!(code: "BOL-ING")  { |x| x.name = "Inglés";                    x.department = dept[:bolivar][:idiomas] }
s[:art]  = Subject.find_or_create_by!(code: "BOL-ART")  { |x| x.name = "Arte y Patrimonio";          x.department = dept[:bolivar][:arte] }
s[:edf]  = Subject.find_or_create_by!(code: "BOL-EDF")  { |x| x.name = "Educación Física";           x.department = dept[:bolivar][:edufisica] }
s[:fil]  = Subject.find_or_create_by!(code: "BOL-FIL")  { |x| x.name = "Filosofía";                 x.department = dept[:bolivar][:sociales] }

b = {} # subjects bello
b[:mat]  = Subject.find_or_create_by!(code: "BEL-MAT")  { |x| x.name = "Matemática";                x.department = dept[:bello][:matematica] }
b[:bio]  = Subject.find_or_create_by!(code: "BEL-BIO")  { |x| x.name = "Biología";                  x.department = dept[:bello][:ciencias] }
b[:fis]  = Subject.find_or_create_by!(code: "BEL-FIS")  { |x| x.name = "Física";                    x.department = dept[:bello][:ciencias] }
b[:sos]  = Subject.find_or_create_by!(code: "BEL-SOS")  { |x| x.name = "Ciencias Sociales";         x.department = dept[:bello][:sociales] }
b[:len]  = Subject.find_or_create_by!(code: "BEL-LEN")  { |x| x.name = "Castellano y Literatura";   x.department = dept[:bello][:lengua] }
b[:ing]  = Subject.find_or_create_by!(code: "BEL-ING")  { |x| x.name = "Inglés";                    x.department = dept[:bello][:idiomas] }
b[:art]  = Subject.find_or_create_by!(code: "BEL-ART")  { |x| x.name = "Arte y Patrimonio";          x.department = dept[:bello][:arte] }
b[:edf]  = Subject.find_or_create_by!(code: "BEL-EDF")  { |x| x.name = "Educación Física";           x.department = dept[:bello][:edufisica] }

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
  { key: :g1, name: "1er Año - Bolívar", level: :secundaria,
    subjects: [s[:mat], s[:len], s[:his], s[:geo], s[:bio], s[:ing], s[:art], s[:edf]] },
  { key: :g2, name: "2do Año - Bolívar", level: :secundaria,
    subjects: [s[:mat], s[:len], s[:his], s[:geo], s[:bio], s[:ing], s[:art], s[:edf]] },
  { key: :g3, name: "3er Año - Bolívar", level: :secundaria,
    subjects: [s[:mat], s[:len], s[:his], s[:geo], s[:bio], s[:fis], s[:ing], s[:art], s[:edf]] },
  { key: :g4, name: "4to Año - Bolívar", level: :secundaria,
    subjects: [s[:mat], s[:len], s[:his], s[:fis], s[:qui], s[:ing], s[:fil], s[:edf]] },
  { key: :g5, name: "5to Año - Bolívar", level: :secundaria,
    subjects: [s[:mat], s[:len], s[:his], s[:fis], s[:qui], s[:ing], s[:fil], s[:edf]] },
].each do |g|
  grade = Grade.find_or_create_by!(name: g[:name]) { |gr| gr.level = g[:level] }
  g[:subjects].each { |subj| GradeSubject.find_or_create_by!(grade: grade, subject: subj) }
  gbol[g[:key]] = grade
end
puts "   ✓ 5 grados Bolívar (#{gbol[:g1].grade_subjects.count} materias en 1ro; #{gbol[:g4].grade_subjects.count} en 4to)"

# --- ANDRÉS BELLO ---
gbel = {}
[
  { key: :g1, name: "1er Año - Bello", level: :secundaria,
    subjects: [b[:mat], b[:len], b[:sos], b[:bio], b[:ing], b[:art], b[:edf]] },
  { key: :g2, name: "2do Año - Bello", level: :secundaria,
    subjects: [b[:mat], b[:len], b[:sos], b[:bio], b[:ing], b[:art], b[:edf]] },
  { key: :g3, name: "3er Año - Bello", level: :secundaria,
    subjects: [b[:mat], b[:len], b[:sos], b[:fis], b[:ing], b[:art], b[:edf]] },
].each do |g|
  grade = Grade.find_or_create_by!(name: g[:name]) { |gr| gr.level = g[:level] }
  g[:subjects].each { |subj| GradeSubject.find_or_create_by!(grade: grade, subject: subj) }
  gbel[g[:key]] = grade
end
puts "   ✓ 3 grados Bello (#{gbel[:g1].grade_subjects.count} materias por grado)"

# =============================================================================
# ADMIN - Mi usuario
# =============================================================================
puts ""
puts "👤 Configurando administradores..."

admin_user = User.find_or_create_by!(email: "moros.daniel@gmail.com") do |u|
  u.password = u.password_confirmation = "123123"
  u.name = "Daniel"; u.last_name = "Moros"
end
Admin.find_or_create_by!(user: admin_user) { |a| a.school = school_bolivar; a.role = :desarrollador }

[
  { email: "director.bolivar@siga.edu",  name: "Ramón",  last_name: "Díaz",      school: school_bolivar, role: :director },
  { email: "coord.bolivar@siga.edu",     name: "Carmen", last_name: "Rodríguez", school: school_bolivar, role: :coordinador },
  { email: "director.bello@siga.edu",    name: "Luisa",  last_name: "Martínez",  school: school_bello,   role: :director },
].each do |d|
  u = User.find_or_create_by!(email: d[:email]) do |uu|
    uu.password = uu.password_confirmation = "123123"
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
    uu.password = uu.password_confirmation = "123123"
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
  edf:  make_teacher("prof.rojas@bolivar.edu",     "Andrés",    "Rojas",     "V-89012345", school_bolivar),
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
  edf:  make_teacher("prof.reyes@bello.edu",   "Omar",      "Reyes",   "V-55667788", school_bello),
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
  s[:fil] => tbol[:len], # Filosofía la imparte el de Lengua (común en liceos)
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
  b[:edf] => tbel[:edf],
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
    uu.password = uu.password_confirmation = "123123"
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
    card     = "BOL-25-#{num}"
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
    card     = "BEL-25-#{num}"
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
puts "🔑 Credenciales (contraseña universal: 123123)"
puts ""
puts "   ADMINISTRADORES:"
puts "   moros.daniel@gmail.com       → desarrollador (Bolívar)"
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
puts "   paula.medina001@bello.edu    → 1er Año A (Bello)"
