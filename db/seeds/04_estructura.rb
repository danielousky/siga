# Secciones, profesores guía y quién dicta qué (MOR-224).
#
# ## La matrícula, escrita como la ve un director
#
# Es la tabla que un director tiene pegada en la pared en septiembre. Está acá
# entera y a mano porque el reparto NO es uniforme y esa es la gracia: hay
# grados con dos secciones y grados con una, secciones llenas y secciones a
# medias, y la matrícula se achica hacia arriba —el bachillerato pierde alumnos,
# que es lo que pasa en un colegio privado venezolano de verdad.
#
#     360 alumnos en total  →  plan Estándar ($60), el tramo 151–400
#
# Ese número no es casualidad: ~360 es el promedio del mercado después de que la
# matrícula privada cayera de 3,2 M a ~1,4 M. Sembrar 200 lo dejaba en el plan
# Inicial y sembrar 500 en el Grande; ninguno de los dos es el cliente típico.
paso "🏫 Secciones y matrícula"

MATRICULA_DE_BOLIVAR = {
  "1er Nivel" => { "U" => 16 },
  "2do Nivel" => { "U" => 18 },
  "3er Nivel" => { "U" => 20 },

  "1er Grado" => { "A" => 22, "B" => 21 },
  "2do Grado" => { "A" => 22, "B" => 20 },
  "3er Grado" => { "A" => 26 },
  "4to Grado" => { "A" => 21, "B" => 19 },
  "5to Grado" => { "A" => 20 },
  "6to Grado" => { "A" => 19 },

  "1er Año"   => { "A" => 22, "B" => 20 },
  "2do Año"   => { "A" => 20 },
  "3er Año"   => { "A" => 18 },
  "4to Año"   => { "A" => 12 },
  "5to Año"   => { "A" => 10 },

  # El 6to Año técnico: pocos, como en la realidad — la mención es una elección
  # y no todo el mundo la toma.
  "6to Año"   => { "A" => 14 }
}.freeze

MATRICULA_DE_BELLO = {
  "1er Nivel" => { "U" => 10 },
  "3er Nivel" => { "U" => 12 },
  "1er Grado" => { "A" => 16 },
  "4to Grado" => { "A" => 18 },
  "5to Grado" => { "A" => 17 },
  "6to Grado" => { "A" => 17 }
}.freeze

# ⚠️ El cupo es MAYOR que la matrícula, y a propósito. Un cupo igual a los
# inscritos deja todas las secciones «llenas» y esconde el aviso de cupo, que
# es una de las cosas que hay que poder ver.
def cupo_para(inscritos) = inscritos + [ 30 - inscritos, 4 ].max.clamp(2, 10)

def sembrar_secciones!(colegio, matricula, periodo, aula_de:)
  Current.school = colegio

  matricula.filter_map do |nombre_del_grado, secciones|
    grado = colegio.grades.find_by(name: nombre_del_grado)
    next if grado.nil?

    secciones.map do |identificador, inscritos|
      seccion = Section.find_or_create_by!(
        name: identificador, grade: grado, academic_period: periodo
      ) { |s| s.capacity = cupo_para(inscritos) }
      seccion.update!(classroom: aula_de.call(grado, identificador))
      [ seccion, inscritos ]
    end
  end.flatten(1)
end

# El aula lleva el piso adelante, como en un colegio: la primaria abajo y el
# bachillerato arriba.
AULA = lambda do |grado, identificador|
  piso = if grado.preescolar? then "PB"
         elsif grado.primaria?  then "1"
         else "2"
         end
  "Aula #{piso}-#{GradoOficial.orden_de(grado.name)}#{identificador}"
end

SEMILLA[:secciones_bolivar] = sembrar_secciones!(
  SEMILLA[:bolivar], MATRICULA_DE_BOLIVAR, SEMILLA[:anio_bolivar], aula_de: AULA
)
SEMILLA[:secciones_bello] = sembrar_secciones!(
  SEMILLA[:bello], MATRICULA_DE_BELLO, SEMILLA[:anio_bello], aula_de: AULA
)

total = ->(m) { m.values.sum { |s| s.values.sum } }
puts "   ✓ Bolívar: #{SEMILLA[:secciones_bolivar].size} secciones para #{total.(MATRICULA_DE_BOLIVAR)} alumnos"
puts "     Bello:   #{SEMILLA[:secciones_bello].size} secciones para #{total.(MATRICULA_DE_BELLO)} alumnos"

# ── Quién dicta qué ──────────────────────────────────────────────────────────
#
# Se reparte por ÁREA: cada docente declaró qué códigos dicta, y acá se le
# asignan las secciones donde esa área existe. Un área con varios docentes se
# reparte entre ellos, rotando por sección.
#
# ⚠️ Rotar y no darle todo al primero: si el de Inglés se quedara con las
# diecinueve secciones, la demo mostraría un colegio con un solo profesor
# haciendo todo, y «quién no cargó notas» daría siempre el mismo nombre.
paso "📋 Asignaciones"

def asignar_docentes!(colegio, secciones, docentes)
  Current.school = colegio

  # código de área → los docentes que la dictan, en orden estable
  por_area = Hash.new { |h, k| h[k] = [] }
  docentes.each_value do |(docente, areas)|
    areas.each { |codigo| por_area[codigo] << docente }
  end

  vueltas = Hash.new(0)
  secciones.each do |seccion, _inscritos|
    seccion.grade.subjects.order(:code).each do |materia|
      candidatos = por_area[materia.code]
      next if candidatos.empty?

      docente = candidatos[vueltas[materia.code] % candidatos.size]
      vueltas[materia.code] += 1
      TeacherSection.find_or_create_by!(teacher: docente, section: seccion, subject: materia)
    end
  end
end

asignar_docentes!(SEMILLA[:bolivar], SEMILLA[:secciones_bolivar], SEMILLA[:docentes_bolivar])
asignar_docentes!(SEMILLA[:bello],   SEMILLA[:secciones_bello],   SEMILLA[:docentes_bello])
puts "   ✓ #{Current.sin_aislamiento { TeacherSection.unscoped.count }} asignaciones"

# ── Profesor guía ────────────────────────────────────────────────────────────
#
# Cuelga de la SECCIÓN, no del grado (MOR-209): «1er Año A» tiene su guía y
# «1er Año B» el suyo. Con el guía colgando del grado, el de «1er Año» pasaba
# lista de A y de B —de alumnos que no son suyos— y el de B no veía su sección.
#
# ⚠️ Se asigna SIN `unless`, a diferencia de casi todo este archivo. Son datos
# de demostración y tienen que dar el mismo resultado cada vez: con el guard,
# una corrida anterior gana para siempre y la demo termina mostrando el mismo
# profesor en las diecinueve secciones.
#
# ⚠️ Y una sección queda SIN guía a propósito. Es opcional —«sin guía, la
# asistencia solo la toma la dirección»— y si todas lo tuvieran, ese camino no
# se vería nunca.
paso "🎯 Profesores guía"

def asignar_guias!(colegio, secciones)
  Current.school = colegio

  secciones.each_with_index do |(seccion, _), i|
    # El guía sale de quien YA dicta en esa sección: un guía que no le da clase
    # a sus propios alumnos no existe.
    candidatos = TeacherSection.where(section: seccion).order(:subject_id).map(&:teacher).uniq
    seccion.update!(leader_teacher: candidatos[i % candidatos.size]) if candidatos.any?
  end
end

asignar_guias!(SEMILLA[:bolivar], SEMILLA[:secciones_bolivar])
asignar_guias!(SEMILLA[:bello],   SEMILLA[:secciones_bello])

Current.school = SEMILLA[:bolivar]
sin_guia = Section.find_by(name: "B", grade: SEMILLA[:bolivar].grades.find_by(name: "4to Grado"))
sin_guia&.update!(leader_teacher: nil)

# El coordinador de grado es OPCIONAL y coordina a los guías; NO pasa lista.
# Se cargan tres para que la demo muestre los dos casos: la mayoría de los
# colegios no tiene el cargo.
SEMILLA[:bolivar].grades.each { |g| g.update!(coordinator_teacher: nil) }
coordinadores = {
  "1er Grado" => "maestra.torres",
  "1er Año"   => "prof.herrera",
  "6to Año"   => "prof.medina"
}
coordinadores.each do |nombre_del_grado, correo|
  grado = SEMILLA[:bolivar].grades.find_by(name: nombre_del_grado)
  docente, = SEMILLA[:docentes_bolivar][correo]
  grado&.update!(coordinator_teacher: docente)
end

puts "   ✓ guías asignados · 4to Grado B queda SIN guía a propósito"
puts "     #{coordinadores.size} grados con coordinador; el resto sin el cargo, que es lo normal"

# ── El año que viene, ya armado ──────────────────────────────────────────────
#
# Un colegio en septiembre tiene el año siguiente con su estructura copiada y
# sin un solo alumno adentro: es exactamente el estado desde el que se promueve
# (MOR-169). Sin sembrarlo, esa pantalla no se puede ver funcionando.
Current.school = SEMILLA[:bolivar]
copia = CopiarLaEstructura.de(SEMILLA[:anio_bolivar], al: SEMILLA[:anio_bolivar_2027])
puts "   ✓ 2026-2027: #{copia.total_secciones} secciones y #{copia.asignaciones} asignaciones copiadas, sin alumnos"
