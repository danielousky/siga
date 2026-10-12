# La gente que trabaja: equipo de SIGA, dirección y docentes (MOR-224).
paso "🛠️  Equipo de SIGA"

# ⚠️ NO pertenece a ningún colegio (MOR-133). Hasta que se separó, «la gente de
# SIGA» era un `Admin` con rol `desarrollador` — y un `Admin` cuelga de un
# colegio. Esa confusión produjo cuatro fugas en dos días.
def del_equipo!(email:, nombre:, apellido:, rol:)
  usuario = User.find_or_create_by!(email: email) do |u|
    u.first_name = nombre; u.last_name = apellido
    u.document = documento_de_prueba(email); u.document_type = :cedula_v
    u.sex = sexo_para(nombre)
    # ⚠️ La del EQUIPO, que en la muestra no es la pública: `/siga` guarda las
    # cuentas a donde se paga. Ver `SeedGuard#clave_del_equipo`.
    u.password = u.password_confirmation = CLAVE_DEL_EQUIPO
  end
  SigaStaff.find_or_create_by!(user: usuario) { |s| s.role = rol }
  usuario
end

del_equipo!(email: CORREO_DESARROLLADOR, nombre: "Equipo", apellido: "SIGA", rol: :fundador)
del_equipo!(email: "operaciones@siga.app", nombre: "Ana", apellido: "Operaciones", rol: :operaciones)
puts "   ✓ #{SigaStaff.count} personas en el equipo, NINGUNA con colegio"

# ── Dirección ────────────────────────────────────────────────────────────────
#
# ⚠️ Los seis cargos, y no solo «director». Cada uno ve una cosa distinta
# (`ApplicationController::DIRECCION`), y con un solo cargo sembrado no hay
# forma de comprobar en pantalla que la secretaria no llega a Finanzas.
paso "👤 Dirección"

def administrador!(email:, nombre:, apellido:, colegio:, rol:)
  usuario = User.find_or_create_by!(email: email) do |u|
    u.password = u.password_confirmation = CLAVE_DE_PRUEBA
    u.first_name = nombre; u.last_name = apellido
    u.document = documento_de_prueba(email); u.document_type = :cedula_v
    u.sex = sexo_para(nombre)
  end
  Admin.find_or_create_by!(user: usuario, school: colegio) { |a| a.role = rol }
end

bolivar = SEMILLA[:bolivar]
bello   = SEMILLA[:bello]

# ⚠️ El correo del director es el de la MUESTRA (`Muestra::CUENTAS`): lo fijó
# Daniel el 12 de octubre de 2026 —«pongámosles director.bolivar@mail.com»—.
# Hasta ese día fue `director.bolivar@siga.edu`, de cuando la demo vivía en
# producción y la usaban los brokers; esa base se vació el 17 de septiembre.
[
  { email: CORREO_DEL_DIRECTOR,           nombre: "Ramón",   apellido: "Díaz",      colegio: bolivar, rol: :director },
  { email: "coord.bolivar@siga.edu",      nombre: "Carmen",  apellido: "Rodríguez", colegio: bolivar, rol: :coordinador },
  { email: "secretaria.bolivar@siga.edu", nombre: "Yaneth",  apellido: "Bastidas",  colegio: bolivar, rol: :secretaria },
  { email: "finanzas.bolivar@siga.edu",   nombre: "Régulo",  apellido: "Marcano",   colegio: bolivar, rol: :finanzas },
  { email: "director.bello@siga.edu",     nombre: "Luisa",   apellido: "Martínez",  colegio: bello,   rol: :director },
  { email: "secretaria.bello@siga.edu",   nombre: "Nélida",  apellido: "Aponte",    colegio: bello,   rol: :secretaria }
].each { |d| administrador!(**d) }
puts "   ✓ #{Admin.count} administradores · los seis cargos representados en Bolívar"

# ── Docentes ─────────────────────────────────────────────────────────────────
#
# Un colegio de trescientos sesenta alumnos con los tres niveles tiene entre
# veinticinco y treinta docentes, y cada nivel se organiza distinto:
#
#     INICIAL     una maestra por sección, dicta las TRES áreas
#     PRIMARIA    una maestra guía por sección + especialistas que rotan
#     MEDIA       un profesor por área, que la dicta en varios años
#
# ⚠️ Que un mismo profesor dicte en DOS niveles no es un descuido de la demo:
# es el caso normal de un colegio mediano —el de Matemática cubre 5to y 6to
# Grado y los tres primeros años— y es justo lo que hace visible que el plan por
# competencias sea de primaria y no de bachillerato.
paso "👨‍🏫 Docentes"

# `areas` son los códigos que dicta; la asignación a secciones se hace en el
# paso siguiente, cuando las secciones existen.
DOCENTES_DE_BOLIVAR = [
  # Educación Inicial — polivalentes, cada una con su sección
  { correo: "maestra.colmenares", nombre: "Yubisay",  apellido: "Colmenares", areas: %w[FPS RCA CYR] },
  { correo: "maestra.nieves",     nombre: "Migdalia", apellido: "Nieves",     areas: %w[FPS RCA CYR] },
  { correo: "maestra.villalba",   nombre: "Rosaura",  apellido: "Villalba",   areas: %w[FPS RCA CYR] },

  # Primaria — guías, cada una con el tronco de su sección
  { correo: "maestra.torres",     nombre: "María",    apellido: "Torres",     areas: %w[LEN CSO] },
  { correo: "maestra.silva",      nombre: "Zulay",    apellido: "Silva",      areas: %w[LEN CSO] },
  { correo: "maestra.quintero",   nombre: "Marisela", apellido: "Quintero",   areas: %w[LEN CSO] },
  { correo: "maestra.ochoa",      nombre: "Belkis",   apellido: "Ochoa",      areas: %w[CNA CSO] },
  { correo: "maestra.zambrano",   nombre: "Nayibe",   apellido: "Zambrano",   areas: %w[CNA CSO] },
  { correo: "maestro.bermudez",   nombre: "Ismael",   apellido: "Bermúdez",   areas: %w[LEN CNA] },

  # Especialistas que rotan por toda la primaria
  { correo: "prof.castillo",      nombre: "Patricia", apellido: "Castillo",   areas: %w[ING] },
  { correo: "prof.rojas",         nombre: "Andrés",   apellido: "Rojas",      areas: %w[EDF] },
  { correo: "prof.moreno",        nombre: "Sofía",    apellido: "Moreno",     areas: %w[EST ART GCR] },
  { correo: "prof.bastidas",      nombre: "Jhonny",   apellido: "Bastidas",   areas: %w[COM EPT] },

  # ⚠️ García cubre primaria Y bachillerato, y es el profesor de la MUESTRA: su
  # correo sale de `Muestra::CUENTAS` y no del dominio del colegio. La clave
  # `prof.garcia` se queda: es como lo nombran los demás pasos de la siembra.
  { correo: "prof.garcia",        nombre: "Carlos",   apellido: "García",     areas: %w[MAT],
    email: CORREO_DEL_PROFESOR },

  # Educación Media
  { correo: "prof.herrera",       nombre: "José",     apellido: "Herrera",    areas: %w[GHC FSN] },
  { correo: "prof.mendoza",       nombre: "Ana",      apellido: "Mendoza",    areas: %w[CNA BIO] },
  { correo: "prof.rivas",         nombre: "Luís",     apellido: "Rivas",      areas: %w[FIS CTI] },
  { correo: "prof.marcano",       nombre: "Douglas",  apellido: "Marcano",    areas: %w[QUI] },
  { correo: "prof.guzman",        nombre: "Elena",    apellido: "Guzmán",     areas: %w[LEN] },
  { correo: "prof.aponte",        nombre: "Yolimar",  apellido: "Aponte",     areas: %w[OYC] },

  # Media Técnica — mención Informática
  { correo: "prof.parra",         nombre: "Ricardo",  apellido: "Parra",      areas: %w[PRG BDA] },
  { correo: "prof.medina",        nombre: "Freddy",   apellido: "Medina",     areas: %w[MEQ PPR PSP] }
].freeze

DOCENTES_DE_BELLO = [
  { correo: "maestra.suarez", nombre: "Gabriela", apellido: "Suárez", areas: %w[FPS RCA CYR] },
  { correo: "maestra.leon",   nombre: "Elena",    apellido: "León",   areas: %w[LEN CSO CNA] },
  { correo: "maestra.gil",    nombre: "Carmen",   apellido: "Gil",    areas: %w[LEN CSO CNA] },
  { correo: "prof.vega",      nombre: "Pedro",    apellido: "Vega",   areas: %w[MAT] },
  { correo: "prof.blanco",    nombre: "Antonio",  apellido: "Blanco", areas: %w[ING] },
  { correo: "prof.reyes",     nombre: "Omar",     apellido: "Reyes",  areas: %w[EDF EST] }
].freeze

# El documento es determinista y sale del correo: un profesor SIEMPRE tiene
# cédula, y tiene que ser la misma en cada corrida.
def sembrar_docentes!(lista, colegio:, dominio:)
  Current.school = colegio

  lista.index_by { |d| d[:correo] }.transform_values do |d|
    correo = d[:email] || "#{d[:correo]}@#{dominio}"
    docente = profesor!(email: correo, nombre: d[:nombre], apellido: d[:apellido],
                        documento: documento_de_prueba(correo), colegio: colegio)
    [ docente, d[:areas] ]
  end
end

SEMILLA[:docentes_bolivar] = sembrar_docentes!(DOCENTES_DE_BOLIVAR, colegio: bolivar, dominio: "bolivar.edu")
SEMILLA[:docentes_bello]   = sembrar_docentes!(DOCENTES_DE_BELLO,   colegio: bello,   dominio: "bello.edu")

puts "   ✓ #{DOCENTES_DE_BOLIVAR.size} docentes en Bolívar · #{DOCENTES_DE_BELLO.size} en Bello"
puts "     #{CORREO_DEL_PROFESOR} dicta Matemática en primaria Y en media"
