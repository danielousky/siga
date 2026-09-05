# Evaluaciones, notas y competencias (MOR-224).
#
# ## Qué se carga y qué NO, y por qué importa
#
# Un colegio a mitad de año tiene notas desparejas: secciones al día, secciones
# a medias y secciones que no arrancaron. Cargarle notas a todas las diecinueve
# dejaría vacía la pantalla de «quién no cargó notas», que es de las que más se
# usan — y una demo donde todo está perfecto no muestra para qué sirve el
# sistema.
#
#     COMPLETAS    los tres lapsos, todas las áreas
#     A MEDIAS     solo el primer lapso  →  el año en curso, que es lo normal
#     VACÍAS       ni una nota           →  lo que persigue la dirección
#
# ⚠️ Preescolar NO lleva notas, y no es un olvido: la Educación Inicial
# describe, no califica (MOR-218).
paso "📝 Evaluaciones y notas"

# Examen 40 % · Taller 30 % · Participación 30 % — cierran el 100 % del lapso.
PONDERACION = [ [ "Examen", 40.0 ], [ "Taller", 30.0 ], [ "Participación", 30.0 ] ].freeze

# Los lapsos venezolanos cierran en diciembre, abril y julio (Art. 110).
MESES_POR_LAPSO = [ [ 2025, 11 ], [ 2026, 3 ], [ 2026, 6 ] ].freeze

def actividades_de(seccion, materia, lapso, indice, cuantas: PONDERACION.size)
  anio, mes = MESES_POR_LAPSO[indice]

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

# ⚠️ `insert_all` y no `create!`, y es la diferencia entre nueve segundos y tres
# minutos.
#
# `ActivityGrade#after_save` recalcula el lapso y el anual — que es lo correcto
# en la app: el promedio nunca queda viejo. Pero acá se cargan ~7.000 notas de
# una sentada, y recalcular después de cada una es hacer el mismo trabajo
# setecientas veces.
#
# Se insertan en bruto y se recalcula UNA vez por sección al final, con
# `GradeCalculator.calculate_all_for_section`. El resultado es idéntico; lo que
# cambia es cuántas veces se llega a él.
#
# ⚠️ `school_id` va explícito: `insert_all` no dispara `DerivesSchoolFrom`, y
# sin la columna el RLS deja esas filas invisibles para siempre.
def cargar_notas!(filas)
  return if filas.empty?

  ahora = Time.current
  ActivityGrade.insert_all(
    filas.map { |f| f.merge(created_at: ahora, updated_at: ahora) },
    unique_by: %i[evaluation_activity_id student_id]
  )
end

# Una nota verosímil y ESTABLE entre corridas: la misma semilla da el mismo
# número. Un dato que cambia de una siembra a otra hace que un bug no se pueda
# reproducir.
def nota_verosimil(semilla, piso: 8, techo: 20)
  piso + ((semilla * 7919) % (techo - piso + 1))
end

# ── Los cinco casos que hay que poder VER ────────────────────────────────────
#
# Cada uno existe para hacer visible una regla del Reglamento General de la LOE.
# No son notas de relleno: son lo que el cálculo tiene que resolver bien.
#
#   #1  buen alumno              → aprueba cómodo (Art. 111, promedio simple)
#   #2  9,50 exacto              → Art. 108: sube a 10 y APRUEBA
#   #3  aplazado con reparación  → Art. 112: la segunda oportunidad manda
#   #4  sin ninguna nota         → sale SIN nota, nunca con cero
#   #5  una actividad sin corregir → promedia sobre el peso cargado, no sobre 100
CASOS_DE_MATEMATICA = {
  0 => [ [ 18, 19, 17 ], [ 17, 18, 16 ], [ 19, 20, 18 ] ],
  1 => [ [ 11,  9,  8 ], [ 11,  9,  8 ], [ 11,  9,  8 ] ],
  2 => [ [  7,  9,  8 ], [  8,  8,  8 ], [  9,  9,  9 ] ],
  3 => [ nil, nil, nil ],
  4 => [ [ 16, nil, nil ], nil, nil ]
}.freeze

# ⚠️ El AÑO ESCOLAR va en la búsqueda, y sin él sale la sección equivocada.
#
# Bolívar tiene «1er Año A» TRES veces —2024-2025, 2025-2026 y la copiada a
# 2026-2027— y `find_by` devolvía cualquiera de ellas. El síntoma fue «Lapso no
# pertenece al año escolar de la sección»: se estaban colgando las evaluaciones
# del año en curso de una sección del año que viene.
def seccion_de(colegio, grado, identificador, periodo)
  Current.school = colegio
  Section.joins(:grade).find_by(
    grades: { name: grado },
    sections: { name: identificador, academic_period_id: periodo.id }
  )
end

def alumnos_de(seccion)
  Enrollment.where(section: seccion).includes(:student).order(:id).map(&:student)
end

def lapsos_de(periodo)
  EvaluationMoment.where(academic_period: periodo).order(:starts_on, :id).to_a
end

# Carga una sección entera. `hasta_el_lapso` es lo que la hace parecer un año en
# curso en vez de un año terminado.
def evaluar_seccion!(seccion, lapsos, hasta_el_lapso: 3, casos: {}, objetivo: nil)
  alumnos = alumnos_de(seccion)
  return if alumnos.empty?

  filas = []
  materias = seccion.grade.subjects.order(:code).to_a

  materias.each_with_index do |materia, mi|
    lapsos.first(hasta_el_lapso).each_with_index do |lapso, li|
      actividades = actividades_de(seccion, materia, lapso, li)

      alumnos.each_with_index do |alumno, ai|
        # Los casos con nombre solo aplican a la PRIMERA materia de la lista:
        # el resto de las áreas de esos mismos alumnos lleva notas normales, que
        # es lo que hace que su boletín se vea como un boletín.
        puntajes =
          if mi.zero? && casos.key?(ai)
            casos[ai][li]
          elsif objetivo
            Array.new(actividades.size) { objetivo[ai] || nota_verosimil(ai + li) }
          else
            base = nota_verosimil(ai * 3 + mi * 5 + li)
            [ base, (base + 2).clamp(1, 20), (base - 1).clamp(1, 20) ]
          end
        next if puntajes.nil?

        actividades.each_with_index do |actividad, i|
          next if puntajes[i].nil?

          filas << { evaluation_activity_id: actividad.id, student_id: alumno.id,
                     score: puntajes[i], school_id: seccion.school_id }
        end
      end
    end
  end

  cargar_notas!(filas)
  GradeCalculator.calculate_all_for_section(seccion)
  filas.size
end

bolivar = SEMILLA[:bolivar]
bello   = SEMILLA[:bello]
lapsos_bol = lapsos_de(SEMILLA[:anio_bolivar])
lapsos_bel = lapsos_de(SEMILLA[:anio_bello])

cargadas = 0

# 1 · 1er Año A — el año completo, con los cinco casos en Matemática.
#
# ⚠️ Matemática tiene que ser la PRIMERA por código para que los casos caigan
# ahí: las áreas se recorren en orden de código y `MAT` va antes que las demás
# de bachillerato salvo `ART`, `BIO`, `CNA`, `EDF`, `FSN`, `GCR`, `GHC`, `ING`,
# `LEN`. Se pasa explícita en vez de confiar en el orden.
un_ano_a = seccion_de(bolivar, "1er Año", "A", SEMILLA[:anio_bolivar])
if un_ano_a
  materias = un_ano_a.grade.subjects.order(:code).to_a
  mat = materias.find { |m| m.code == "MAT" }
  otras = materias - [ mat ]

  # Matemática, con los casos.
  filas = []
  lapsos_bol.each_with_index do |lapso, li|
    actividades = actividades_de(un_ano_a, mat, lapso, li)
    alumnos_de(un_ano_a).each_with_index do |alumno, ai|
      puntajes = CASOS_DE_MATEMATICA.key?(ai) ? CASOS_DE_MATEMATICA[ai][li] :
                   [ nota_verosimil(ai + li), nota_verosimil(ai + li + 1), nota_verosimil(ai + li + 2) ]
      next if puntajes.nil?

      actividades.each_with_index do |actividad, i|
        next if puntajes[i].nil?
        filas << { evaluation_activity_id: actividad.id, student_id: alumno.id,
                   score: puntajes[i], school_id: un_ano_a.school_id }
      end
    end
  end
  cargar_notas!(filas)
  cargadas += filas.size

  # Las demás áreas: los tres lapsos, salvo Castellano que va SOLO en el primero
  # y con el lapso a medio definir —Examen 40 % y Taller 30 %, sin la
  # Participación—. Son dos casos de QA en uno: el medidor tiene que mostrar
  # «faltan 30 %», y el promedio se calcula sobre el 70 % cargado.
  otras.each do |materia|
    solo_primero = materia.code == "LEN"
    filas = []
    lapsos_bol.first(solo_primero ? 1 : 3).each_with_index do |lapso, li|
      actividades = actividades_de(un_ano_a, materia, lapso, li, cuantas: solo_primero ? 2 : 3)
      alumnos_de(un_ano_a).each_with_index do |alumno, ai|
        actividades.each_with_index do |actividad, i|
          filas << { evaluation_activity_id: actividad.id, student_id: alumno.id,
                     score: nota_verosimil(ai * 3 + li + i), school_id: un_ano_a.school_id }
        end
      end
    end
    cargar_notas!(filas)
    cargadas += filas.size
  end
  GradeCalculator.calculate_all_for_section(un_ano_a)
end

# 2 · Un año COMPLETO de punta a punta: 5to Año A (diez alumnos) y el 6to Año
#     técnico. Son los que alimentan la certificación 31059 y las reparaciones.
[ [ "5to Año", "A" ], [ "6to Año", "A" ] ].each do |grado, identificador|
  seccion = seccion_de(bolivar, grado, identificador, SEMILLA[:anio_bolivar])
  cargadas += evaluar_seccion!(seccion, lapsos_bol).to_i if seccion
end

# 3 · Primaria de Bolívar por LITERAL: 4to Grado A recorre las cinco letras.
#
#     20 → A       17 → B       15 → C       11 → D       8 → E
#
# Un solo alumno con 19 demuestra que el mapa existe; cinco repartidos
# demuestran que los cortes están donde tienen que estar, y dejan a la vista el
# que más importa: la E, que es reprobado.
LITERALES = [ 20, 17, 15, 11, 8 ].freeze

[ [ bolivar, "4to Grado", "A", lapsos_bol, SEMILLA[:anio_bolivar] ],
  [ bello,   "4to Grado", "A", lapsos_bel, SEMILLA[:anio_bello] ] ].each do |colegio, grado, ident, lapsos, periodo|
  seccion = seccion_de(colegio, grado, ident, periodo)
  next if seccion.nil?

  objetivo = LITERALES.each_with_index.to_h { |nota, i| [ i, nota ] }
  cargadas += evaluar_seccion!(seccion, lapsos, objetivo: objetivo).to_i
end

# 4 · A MEDIAS — solo el primer lapso. Es el estado normal de un año en curso.
[ [ "1er Año", "B" ], [ "2do Año", "A" ], [ "3er Año", "A" ], [ "1er Grado", "A" ] ].each do |grado, ident|
  seccion = seccion_de(bolivar, grado, ident, SEMILLA[:anio_bolivar])
  cargadas += evaluar_seccion!(seccion, lapsos_bol, hasta_el_lapso: 1).to_i if seccion
end

Current.school = bolivar
puts "   ✓ #{cargadas} notas cargadas · #{Current.sin_aislamiento { EvaluationActivity.unscoped.count }} evaluaciones"
sin_notas = Current.sin_aislamiento do
  Section.unscoped.where(school_id: bolivar.id, academic_period_id: SEMILLA[:anio_bolivar].id)
         .where.not(id: EvaluationActivity.unscoped.select(:section_id)).count
end
puts "     #{sin_notas} secciones SIN una sola nota: es lo que persigue «quién no cargó notas»"

# ── La reparación (Art. 112) ─────────────────────────────────────────────────
#
# ⚠️ `debe_reparar?` NO es `aplazado?`. Quién tiene DERECHO a reparar lo decide
# el promedio ANUAL; `aplazado?` mira la definitiva, que ya incluye la
# reparación. Con `aplazado?`, el alumno desaparecía de la planilla en el
# instante en que se le cargaba una reparación aprobatoria.
Current.school = bolivar
if un_ano_a
  mat = un_ano_a.grade.subjects.find_by(code: "MAT")
  tercero = alumnos_de(un_ano_a)[2]
  inscripcion = Enrollment.find_by(student: tercero, section: un_ano_a)

  libro = FinalGradeBook.find_by(enrollment: inscripcion, subject: mat)
  libro&.update!(remedial_exam_score: 12)
  GradeCalculator.calculate_final_grade(enrollment: inscripcion, subject: mat) if libro
end

# ── El historial: 2024-2025, importado ───────────────────────────────────────
#
# Todo alumno que no está en su primer grado viene de algún lado. Sin historial,
# la ficha de un alumno de 5to Año arranca en blanco, el boletín no tiene con
# qué comparar y la constancia de un egresado no existe.
#
# ⚠️ Va con `origen: :importada`, y eso NO es una etiqueta cosmética: es lo que
# impide que `GradeCalculator` borre estas notas. Un libro importado no tiene
# actividades debajo —las cinco evaluaciones que produjeron ese 15 están en
# papel— y la regla de borrar lo que quedó sin respaldo se las llevaría.
#
# Es además el caso REAL de un colegio nuevo en SIGA: trae su historial y sigue
# desde ahí.
paso "📚 Historial del año pasado (importado)"

anterior = SEMILLA[:anio_bolivar_2025]
Current.school = bolivar

libros = []
inscripciones_viejas = []
ahora = Time.current

SEMILLA[:secciones_bolivar].each do |seccion, _|
  grado = seccion.grade
  next if grado.preescolar?                       # inicial describe, no califica

  orden_anterior = (GradoOficial.orden_de(grado.name) || 1) - 1
  entrada = GradoOficial::CATALOGO.find { |e| e.orden == orden_anterior }
  next if entrada.nil?

  grado_anterior = bolivar.grades.find_by(name: entrada.nombre)
  next if grado_anterior.nil?

  vieja = Section.find_or_create_by!(name: seccion.name, grade: grado_anterior,
                                     academic_period: anterior) { |s| s.capacity = seccion.capacity }

  alumnos_de(seccion).each do |alumno|
    inscripcion = Enrollment.find_or_create_by!(student: alumno, section: vieja) do |e|
      e.enrollment_date = Date.new(2024, 9, 17)
      e.status = :regular
    end
    inscripciones_viejas << [ inscripcion, grado_anterior ]
  end
end

inscripciones_viejas.each_with_index do |(inscripcion, grado_anterior), i|
  grado_anterior.subjects.order(:code).each_with_index do |materia, mi|
    next if FinalGradeBook.exists?(enrollment: inscripcion, subject: materia)

    nota = nota_verosimil(i * 3 + mi, piso: 9, techo: 20)
    libros << { enrollment_id: inscripcion.id, subject_id: materia.id,
                school_id: bolivar.id, annual_average: nota, final_score: nota,
                origen: FinalGradeBook.origens[:importada],
                created_at: ahora, updated_at: ahora }
  end
end

FinalGradeBook.insert_all(libros) if libros.any?
puts "   ✓ #{inscripciones_viejas.size} inscripciones en 2024-2025 · #{libros.size} notas definitivas importadas"

# ── Competencias e indicadores (MOR-136) ─────────────────────────────────────
#
# El plan de evaluación de primaria, escrito como lo escribe una maestra: la
# competencia dice QUÉ se evalúa y los indicadores dicen qué significa. Se
# imprimen en la boleta; no se califican aparte.
paso "🧩 Plan de evaluación por competencias"

PLAN_DE_PRIMARIA = {
  "MAT" => [
    [ "Resuelve problemas de adición y sustracción con números naturales",
      [ "Suma y resta con reagrupación", "Resuelve problemas de dos pasos",
        "Estima el resultado antes de calcular" ] ],
    [ "Reconoce y compara figuras geométricas del entorno",
      [ "Identifica figuras planas por sus lados", "Compara tamaños y posiciones" ] ]
  ],
  "LEN" => [
    [ "Lee en voz alta con fluidez y comprende lo leído",
      [ "Respeta los signos de puntuación", "Responde preguntas sobre el texto",
        "Reconstruye la secuencia de los hechos" ] ],
    [ "Produce textos escritos con intención comunicativa",
      [ "Separa las palabras correctamente", "Usa mayúscula al iniciar la oración" ] ]
  ],
  "CNA" => [
    [ "Reconoce los seres vivos de su entorno y sus necesidades",
      [ "Distingue seres vivos de objetos inertes", "Nombra lo que necesita una planta" ] ]
  ]
}.freeze

Current.school = bolivar
competencias = 0

[ [ bolivar, "4to Grado", lapsos_bol ], [ bolivar, "1er Grado", lapsos_bol ] ].each do |colegio, grado, lapsos|
  Current.school = colegio
  seccion = seccion_de(colegio, grado, "A", SEMILLA[:anio_bolivar])
  next if seccion.nil?

  PLAN_DE_PRIMARIA.each do |codigo, plan|
    materia = seccion.grade.subjects.find_by(code: codigo)
    next if materia.nil?

    # Solo el PRIMER lapso: el plan se escribe lapso por lapso, y tenerlos los
    # tres llenos escondería el botón de «traer el del lapso anterior».
    plan.each_with_index do |(descripcion, indicadores), orden|
      competencia = Competency.find_or_create_by!(
        section: seccion, subject: materia, evaluation_moment: lapsos.first,
        descripcion: descripcion
      ) { |c| c.orden = orden }
      competencias += 1

      indicadores.each_with_index do |texto, i|
        Indicator.find_or_create_by!(competency: competencia, descripcion: texto) { |ind| ind.orden = i }
      end
    end
  end
end

# ── Etiquetar las evaluaciones con lo que evalúan ────────────────────────────
#
# El enganche entre el PLAN y la NOTA. Sin esto las competencias existen y no
# aparecen en ninguna boleta — que es para lo único que existen.
#
# ⚠️ Se etiquetan las del PRIMER lapso, que es donde está el plan. Las de los
# otros dos quedan sin etiqueta a propósito: es el estado normal de un año en
# curso, y hace visible que una evaluación sin etiquetar sigue funcionando.
Current.school = bolivar
etiquetadas = 0

[ [ bolivar, "4to Grado" ], [ bolivar, "1er Grado" ] ].each do |colegio, grado|
  Current.school = colegio
  seccion = seccion_de(colegio, grado, "A", SEMILLA[:anio_bolivar])
  next if seccion.nil?

  primer_lapso = lapsos_bol.first
  EvaluationActivity.where(section_id: seccion.id, evaluation_moment_id: primer_lapso.id)
                    .find_each do |actividad|
    plan = Competency.del_plan(actividad.section_id, actividad.subject_id,
                               actividad.evaluation_moment_id).to_a
    next if plan.empty?

    # Cada evaluación etiqueta UNA competencia, rotando: así ninguna queda sin
    # evaluar y ninguna acapara las tres.
    competencia = plan[etiquetadas % plan.size]
    ActivityCompetency.find_or_create_by!(competency: competencia, evaluation_activity: actividad)
    etiquetadas += 1
  end
end

# ── Los informes descriptivos (MOR-216) ──────────────────────────────────────
#
# ⚠️ Algunos SÍ y otros NO, a propósito. Un colegio a mitad de lapso tiene la
# mitad escritos, y la boleta de un alumno sin informe tiene que salir igual —
# sin un renglón vacío ni un título huérfano. Con todos escritos ese caso no se
# ve nunca.
paso "✍️  Informes descriptivos"

INFORMES = [
  "Avanzó mucho en la lectura en voz alta durante este lapso. Todavía se apura al " \
  "leer y se salta los signos de puntuación; conviene practicar en casa diez minutos " \
  "diarios con un cuento que le guste.",

  "Trabaja con constancia y termina lo que empieza. Le cuesta pedir ayuda cuando no " \
  "entiende: hay que animarla a preguntar en el momento y no al final de la clase.",

  "Domina las operaciones básicas y ayuda a sus compañeros cuando terminan tarde. " \
  "En los problemas de dos pasos se apura y responde antes de leer todo el enunciado.",

  "Se distrae al final de la mañana y conviene sentarlo adelante. Cuando está atento " \
  "resuelve sin dificultad, y eso se nota en las evaluaciones de la primera hora.",

  "Mejoró mucho desde octubre, sobre todo en la escritura: separa bien las palabras y " \
  "empezó a usar mayúscula al iniciar la oración sin que se le recuerde."
].freeze

escritos = 0

[ [ bolivar, "4to Grado" ], [ bolivar, "1er Grado" ] ].each do |colegio, grado|
  Current.school = colegio
  seccion = seccion_de(colegio, grado, "A", SEMILLA[:anio_bolivar])
  next if seccion.nil?

  guia = seccion.leader_teacher&.user || User.find_by(email: "director.bolivar@siga.edu")
  next if guia.nil?

  primer_lapso = lapsos_bol.first
  Enrollment.where(section_id: seccion.id, status: :regular).order(:id).each_with_index do |inscripcion, i|
    # Dos de cada tres: el estado real de una maestra a mitad de lapso.
    next if (i % 3) == 2

    Informe.find_or_create_by!(enrollment: inscripcion, evaluation_moment: primer_lapso) do |informe|
      informe.escrito_por = guia
      informe.cuerpo = INFORMES[i % INFORMES.size]
    end
    escritos += 1
  end
end

Current.school = bolivar
puts "   ✓ #{escritos} informes escritos · el tercio restante queda SIN informe, a propósito"

Current.school = bolivar
puts "   ✓ #{competencias} competencias con sus indicadores, en 1er y 4to Grado"
puts "     #{etiquetadas} evaluaciones del 1er lapso etiquetadas con lo que evalúan"
