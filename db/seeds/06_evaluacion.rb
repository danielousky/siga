# Evaluaciones, notas, valoraciones e informes — y el año anterior, entero.
#
# ## Qué arma este paso
#
#     EL MOTOR      cómo se evalúa UN lapso de UNA sección, hasta una fecha
#     EL ANTERIOR   las dieciséis secciones, los tres lapsos, completos y CERRADOS
#
# El año en curso usa el mismo motor, en el paso 08, hasta el día de hoy.
#
# ## ⚠️ Un año terminado está TERMINADO
#
# Antes se sembraban cuatro secciones completas, cuatro a medias y el resto
# vacías, todo en el mismo año: servía para ver «quién no cargó notas», pero el
# colegio no se parecía a ninguno —ni a uno a mitad de año, ni a uno que ya
# cerró—. Y sin notas definitivas no hay a quién promover, ni certificados, ni
# reparaciones.
#
# Ahora cada cosa vive en su año. Lo desparejo —el profesor atrasado, el plan a
# medio armar, el alumno sin nota— está en el año que CORRE, que es donde pasa.
# El anterior está como queda un año en un colegio que usa el sistema: todo
# calificado, los tres lapsos cerrados por Control de Estudio y cada boletín en
# manos de su familia.
#
# ⚠️ Inicial NO lleva notas, y no es un olvido: la Educación Inicial describe,
# no califica (MOR-218). Lleva sus VALORACIONES, que son texto.
paso "📝 El año anterior: evaluaciones y notas"

# Examen 40 % · Taller 30 % · Participación 30 % — cierran el 100 % del lapso.
#
# El tercer número es EN QUÉ PUNTO del lapso cae cada una: el taller temprano,
# la participación a la mitad y el examen al final. No es decorado: es lo que
# hace que un lapso que corre tenga unas evaluaciones ya calificadas y otras
# todavía por delante.
PLAN_DEL_LAPSO = [ [ "Examen", 40.0, 0.85 ], [ "Taller", 30.0, 0.20 ], [ "Participación", 30.0, 0.50 ] ].freeze

def fecha_en_el_lapso(lapso, fraccion)
  dia_habil(lapso.starts_on + ((lapso.ends_on - lapso.starts_on) * fraccion).round)
end

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
      [ "Distingue seres vivos de objetos inertes", "Nombra lo que necesita una planta",
        "Explica para qué sirven las partes de la planta" ] ]
  ]
}.freeze

# ⚠️ El plan se escribe ANTES que las evaluaciones, y no es orden de gusto.
#
# Desde `MOR-136` (segunda mitad) una evaluación de primaria mide una
# competencia, o no se guarda. Y es además el orden REAL del trabajo del
# docente —escribe su plan, arma sus evaluaciones—.
#
# Para las áreas que no están en `PLAN_DE_PRIMARIA` se arma una competencia
# genérica: sin ella, esas áreas no podrían tener ni una evaluación.
def plan_de(seccion, materia, lapso)
  return [] unless seccion.grade.por_competencias?

  # ⚠️ TRES indicadores, uno por evaluación del lapso. Con dos, la tercera se
  # quedaba sin ninguno libre y `un_indicador_libre` le inventaba uno con el
  # nombre de la evaluación —«Lo que se evalúa en “Participación”»—, que es un
  # texto de relleno saliendo impreso en una boleta de demostración.
  escrito = PLAN_DE_PRIMARIA[materia.code] || [
    [ "Alcanza los objetivos de #{materia.name}",
      [ "Participa en las actividades de la clase", "Cumple con las asignaciones",
        "Trabaja en equipo con sus compañeros" ] ]
  ]

  escrito.map.with_index do |(descripcion, indicadores), orden|
    competencia = Competency.find_or_create_by!(
      section: seccion, subject: materia, evaluation_moment: lapso, descripcion: descripcion
    ) { |c| c.orden = orden }

    indicadores.each_with_index do |texto, i|
      Indicator.find_or_create_by!(competency: competencia, descripcion: texto) { |ind| ind.orden = i }
    end
    competencia.reload
  end
end

# Reparte entre sus evaluaciones los indicadores que quedaron sueltos.
#
# ⚠️ En un lapso TERMINADO no puede quedar ninguno sin evaluación: un indicador
# vive dentro de la evaluación que lo mide, y uno suelto no se imprime en la
# boleta. El reparto es cíclico: tres indicadores entre dos evaluaciones quedan
# 2 y 1.
def repartir_los_indicadores_sueltos(seccion, lapso)
  Competency.where(section_id: seccion.id, evaluation_moment_id: lapso.id)
            .includes(:indicators, :evaluation_activities).find_each do |competencia|
    miden = competencia.evaluation_activities.to_a
    next if miden.empty?

    competencia.indicators.reject(&:medido?).each_with_index do |indicador, i|
      indicador.update!(evaluation_activity: miden[i % miden.size])
    end
  end
end

# ⚠️ Un indicador PROPIO por evaluación: no se repiten entre evaluaciones, así
# que dos actividades de la misma competencia miden cosas distintas de ella.
def un_indicador_libre(competencia, nombre)
  competencia.indicators.libres.first ||
    competencia.indicators.create!(descripcion: "Lo que se evalúa en «#{nombre}»",
                                   orden: (competencia.indicators.maximum(:orden) || -1) + 1)
end

# Las evaluaciones de un área en un lapso: el plan entero, con su fecha cada
# una. `cuantas: 2` deja el lapso a medio planificar —Examen 40 % y Taller
# 30 %, sin la Participación—, que es el caso del medidor «faltan 30 %».
def actividades_de(seccion, materia, lapso, cuantas: PLAN_DEL_LAPSO.size)
  plan = plan_de(seccion, materia, lapso)

  PLAN_DEL_LAPSO.first(cuantas).map.with_index do |(nombre, peso, fraccion), i|
    actividad = EvaluationActivity.find_or_initialize_by(
      section: seccion, subject: materia, evaluation_moment: lapso,
      description: "#{nombre} — #{lapso.name}"
    )
    next actividad if actividad.persisted?

    actividad.weight_percentage = peso
    actividad.date_scheduled    = fecha_en_el_lapso(lapso, fraccion)

    # ⚠️ Se reparten las competencias del plan entre las tres evaluaciones, y
    # cada una se lleva un indicador distinto. En bachillerato `plan` viene
    # vacío y esto no hace nada: allá no hay competencias.
    if plan.any?
      competencia = plan[i % plan.size]
      actividad.competency_ids = [ competencia.id ]
      actividad.indicators     = [ un_indicador_libre(competencia, nombre) ]
    end

    actividad.save!
    actividad
  end
end

# ⚠️ `insert_all` y no `create!`, y es la diferencia entre segundos y minutos.
#
# `ActivityGrade#after_save` recalcula el lapso y el anual — que es lo correcto
# en la app: el promedio nunca queda viejo. Pero acá se cargan decenas de miles
# de notas de una sentada, y recalcular después de cada una es hacer el mismo
# trabajo miles de veces.
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
  filas.each_slice(5_000) do |tanda|
    ActivityGrade.insert_all(
      tanda.map { |f| f.merge(created_at: ahora, updated_at: ahora) },
      unique_by: %i[evaluation_activity_id student_id]
    )
  end
end

# ⚠️ El AÑO ESCOLAR va en la búsqueda, y sin él sale la sección equivocada:
# «1er Año A» existe una vez por año, y `find_by` devolvía cualquiera.
def seccion_de(colegio, grado, identificador, periodo)
  Current.school = colegio
  Section.joins(:grade).find_by(
    grades: { name: grado },
    sections: { name: identificador, academic_period_id: periodo.id }
  )
end

# Las inscripciones de una sección en el orden de la lista, cada una con su
# PUESTO —que es por donde se fijan los casos con nombre—.
def lista_de(seccion)
  Enrollment.where(section: seccion).includes(:student).order(:id).each_with_index.to_a
end

def lapsos_de(periodo)
  EvaluationMoment.where(academic_period: periodo).order(:starts_on, :id).to_a
end

# ── EL MOTOR ─────────────────────────────────────────────────────────────────
#
# Evalúa UN lapso de UNA sección, hasta una fecha. Devuelve cuántas notas cargó.
#
#     hasta      solo se califica lo que ya pasó: un lapso que corre tiene
#                evaluaciones por delante, planificadas y sin notas
#     ritmo      por área: `:al_dia`, `:atrasado` (lo último que venció está sin
#                calificar), `:a_medias` (el plan no llega al 100 %) o
#                `:sin_plan` (ni una evaluación)
#     casos      notas escritas a mano para un área y un puesto: son los que
#                hacen visible una regla del Reglamento
#     objetivo   la misma nota en todo, por puesto: los cinco de la escala literal
#     ausentes   puestos que no tienen nota en la última evaluación calificada
#                de Matemática: «sin nota» no es cero, y hay que poder verlo
#
# El perfil fijo de un alumno (`SEMILLA[:bases]`) lo sigue de un año al otro:
# va por alumno y no por puesto, porque al promoverlo cambia de lista.
def evaluar_lapso!(seccion, lapso, indice, hasta: lapso.ends_on, ritmo: nil, casos: {}, objetivo: {},
                   ausentes: [])
  lista = lista_de(seccion).select { |inscripcion, _| inscripcion.regular? }
  return 0 if lista.empty?

  filas = []

  seccion.grade.subjects.order(:code).each do |materia|
    paso_del_area = ritmo ? ritmo.call(materia) : :al_dia
    next if paso_del_area == :sin_plan

    actividades = actividades_de(seccion, materia, lapso, cuantas: paso_del_area == :a_medias ? 2 : 3)
    vencidas = actividades.select { |a| a.date_scheduled <= hasta }.sort_by(&:date_scheduled)
    # El atrasado tiene sin calificar lo último que venció.
    vencidas = vencidas[0...-1] if paso_del_area == :atrasado
    sin_la_ultima = vencidas.last

    vencidas.each do |actividad|
      i = actividades.index(actividad)

      lista.each do |inscripcion, puesto|
        next if ausentes.include?(puesto) && actividad == sin_la_ultima && materia.code == "MAT"

        puntaje = if casos.dig(materia.code, puesto)
                    casos[materia.code][puesto][indice]&.at(i)
                  elsif objetivo[puesto]
                    objetivo[puesto]
                  else
                    nota_de(numero_de(inscripcion.student), materia.code, indice, i,
                            base: SEMILLA[:bases][inscripcion.student_id])
                  end
        next if puntaje.nil?

        filas << { evaluation_activity_id: actividad.id, student_id: inscripcion.student_id,
                   score: puntaje, school_id: seccion.school_id }
      end
    end
  end

  repartir_los_indicadores_sueltos(seccion, lapso) if hasta >= lapso.ends_on
  cargar_notas!(filas)
  filas.size
end

# ── Los tres casos que hay que poder VER ─────────────────────────────────────
#
# Cada uno existe para hacer visible una regla del Reglamento General de la LOE,
# en la Matemática de «1er Año A» del año anterior. Van en el orden de
# `PLAN_DEL_LAPSO`: examen, taller, participación.
#
#   #1  buen alumno              → aprueba cómodo (Art. 111, promedio simple)
#   #2  9,50 exacto              → Art. 108: sube a 10 y APRUEBA
#   #3  aplazado con reparación  → Art. 112: la segunda oportunidad manda
#
# ⚠️ Eran cinco. El alumno «sin ninguna nota» y el de «una actividad sin
# corregir» se mudaron al año en curso (paso 08): son estados de un lapso que
# CORRE. En un año cerrado, un alumno sin nota en Matemática deja a su sección
# sin poder cerrar ningún lapso, y a veintidós familias sin boletín.
CASOS_DE_MATEMATICA = {
  0 => [ [ 18, 19, 17 ], [ 17, 18, 16 ], [ 19, 20, 18 ] ],
  1 => [ [ 11,  9,  8 ], [ 11,  9,  8 ], [ 11,  9,  8 ] ],
  2 => [ [  7,  9,  8 ], [  8,  8,  8 ], [  9,  9,  9 ] ]
}.freeze

# Primaria por LITERAL: «4to Grado A» recorre las cinco letras.
#
#     20 → A       17 → B       15 → C       11 → D       8 → E
#
# Un solo alumno con 19 demuestra que el mapa existe; cinco repartidos
# demuestran que los cortes están donde tienen que estar, y dejan a la vista el
# que más importa: la E, que es reprobado.
LITERALES = { 0 => 20, 1 => 17, 2 => 15, 3 => 11, 4 => 8 }.freeze

# Lo que tiene de particular cada sección del año anterior.
def particularidades_de(seccion)
  grado, nombre = seccion.grade.name, seccion.name

  { casos: (grado == "1er Año" && nombre == "A" ? { "MAT" => CASOS_DE_MATEMATICA } : {}),
    objetivo: (grado == "4to Grado" && nombre == "A" ? LITERALES : {}) }
end

bolivar  = SEMILLA[:bolivar]
anterior = SEMILLA[:anterior]
lapsos_del_anterior = lapsos_de(anterior)

Current.school = bolivar
cargadas = 0

SEMILLA[:secciones_bolivar].each do |seccion, _|
  next if seccion.grade.califica_con_texto?

  propio = particularidades_de(seccion)
  lapsos_del_anterior.each_with_index do |lapso, indice|
    cargadas += evaluar_lapso!(seccion, lapso, indice, **propio)
  end
  GradeCalculator.calculate_all_for_section(seccion)
end

puts "   ✓ #{cargadas} notas en #{anterior.name}: las #{SEMILLA[:secciones_bolivar].count { |s, _| !s.grade.califica_con_texto? }} " \
     "secciones calificadas, los tres lapsos"

# ── La reparación (Art. 112) ─────────────────────────────────────────────────
#
# ⚠️ `debe_reparar?` NO es `aplazado?`. Quién tiene DERECHO a reparar lo decide
# el promedio ANUAL; `aplazado?` mira la definitiva, que ya incluye la
# reparación. Con `aplazado?`, el alumno desaparecía de la planilla en el
# instante en que se le cargaba una reparación aprobatoria.
#
# De cada veinte que tenían que reparar:
#
#     12  repararon y APROBARON     la segunda oportunidad manda: pasan
#      5  repararon y NO alcanzó    la materia queda aplazada
#      3  NO se presentaron         siguen en la planilla, con el campo vacío
#
# Los últimos son los que hacen que `/reparaciones` del año anterior no sea una
# lista terminada: hay algo que cargar.
paso "🩹 Reparaciones"

def reparar!(libro, nota)
  libro.remedial_exam_score = nota
  libro.calcular_definitiva
  libro.save!
end

por_reparar = FinalGradeBook.where(enrollment_id: Enrollment.where(section_id: SEMILLA[:secciones_bolivar].map { |s, _| s.id },
                                                                    status: :regular).select(:id))
                            .includes(:subject, enrollment: :student)
                            .select(&:debe_reparar?)

aprobaron = no_alcanzo = pendientes = 0
por_reparar.each do |libro|
  le_toco = suerte(numero_de(libro.enrollment.student), libro.subject.code, "reparacion", de: 20)

  if le_toco < 12
    reparar!(libro, 10 + (le_toco % 4))
    aprobaron += 1
  elsif le_toco < 17
    reparar!(libro, 6 + (le_toco % 4))
    no_alcanzo += 1
  else
    pendientes += 1
  end
end

# El caso #3 no se deja al sorteo: Miguel Pérez sacó 8 de anual en Matemática,
# reparó con 12, y su definitiva es 12.
un_ano_a = SEMILLA[:secciones_bolivar].find { |s, _| s.grade.name == "1er Año" && s.name == "A" }&.first
if un_ano_a
  inscripcion, = lista_de(un_ano_a)[2]
  libro = FinalGradeBook.find_by(enrollment: inscripcion, subject: un_ano_a.grade.subjects.find_by(code: "MAT"))
  reparar!(libro, 12) if libro
end

puts "   ✓ #{por_reparar.size} materias por reparar: #{aprobaron} reparadas y aprobadas · " \
     "#{no_alcanzo} reparadas sin alcanzar · #{pendientes} sin presentar"

# ── Las valoraciones de Inicial (MOR-218) ────────────────────────────────────
#
# La Educación Inicial no pone notas: describe. Cada niño lleva, por lapso, un
# texto en cada una de sus tres áreas.
VALORACIONES = {
  "FPS" => [
    "Se integra al grupo con confianza y espera su turno para hablar. Empieza a resolver los desacuerdos conversando.",
    "Reconoce sus pertenencias y las cuida. Todavía busca al adulto cuando algo no le sale: hay que animarlo a intentar otra vez.",
    "Expresa lo que siente con palabras y consuela a sus compañeros. Sigue las rutinas del aula sin que se le recuerden.",
    "Participa en los juegos del grupo, aunque prefiere mirar antes de entrar. Se despide de su familia sin angustia."
  ],
  "RCA" => [
    "Observa con curiosidad las plantas y los animales del patio, y pregunta por qué. Clasifica objetos por color y tamaño.",
    "Cuenta hasta diez señalando cada objeto. Reconoce el círculo, el cuadrado y el triángulo en lo que tiene alrededor.",
    "Cuida el agua y bota la basura en su lugar sin que se le pida. Ordena una secuencia de tres momentos del día.",
    "Compara cantidades —más, menos, igual— con material concreto. Le cuesta todavía ubicar arriba, abajo, delante y detrás."
  ],
  "CYR" => [
    "Cuenta lo que hizo el fin de semana en orden y con detalles. Reconoce su nombre escrito y empieza a trazarlo.",
    "Escucha un cuento completo y anticipa lo que va a pasar. Dibuja la figura humana con cabeza, tronco y extremidades.",
    "Canta las canciones del aula y marca el ritmo con las palmas. Toma el creyón con la pinza correcta.",
    "Hace preguntas sobre las palabras que no conoce. Reconoce las vocales en los carteles del salón."
  ]
}.freeze

# Escribe las valoraciones de los lapsos que ya terminaron y —en el que corre—
# las de las áreas que la maestra ya tuvo tiempo de mirar. Se insertan en bruto,
# como las notas: son texto, y nada las recalcula.
def valorar!(seccion, lapsos, hasta: HOY)
  return 0 unless seccion.grade.califica_con_texto?

  areas = seccion.grade.subjects.order(:code).to_a
  ahora = Time.current
  filas = []

  lapsos.each_with_index do |lapso, indice|
    situacion = lapso.ends_on < hasta ? :terminado : (lapso.starts_on <= hasta ? :corriendo : :por_empezar)
    next if situacion == :por_empezar

    lista_de(seccion).each do |inscripcion, puesto|
      next unless inscripcion.regular?

      areas.each_with_index do |area, ai|
        # A mitad de lapso la maestra lleva escritas unas sí y otras no.
        next if situacion == :corriendo && (puesto + ai).odd?

        textos = VALORACIONES.fetch(area.code)
        filas << { enrollment_id: inscripcion.id, subject_id: area.id, evaluation_moment_id: lapso.id,
                   descripcion: textos[(numero_de(inscripcion.student) + indice + ai) % textos.size],
                   origen: MomentGrade.origens[:calculada], school_id: seccion.school_id,
                   created_at: ahora, updated_at: ahora }
      end
    end
  end

  MomentGrade.insert_all(filas, unique_by: %i[enrollment_id subject_id evaluation_moment_id]) if filas.any?
  filas.size
end

paso "🌱 Valoraciones de Educación Inicial"

Current.school = bolivar
valoraciones = SEMILLA[:secciones_bolivar].sum { |seccion, _| valorar!(seccion, lapsos_del_anterior) }
puts "   ✓ #{valoraciones} valoraciones en #{anterior.name}: Inicial describe, no califica"

# ── Los informes descriptivos (MOR-216) ──────────────────────────────────────
#
# Un informe por alumno y por lapso: lo escribe el docente guía, y sin él el
# lapso no se puede cerrar. Lo que dice sale del perfil del alumno —no es lo
# mismo lo que se le escribe a quien va sobrado que a quien está por repetir—.
INFORMES = {
  sobresaliente: [
    "Trabaja con autonomía y termina antes que el grupo: conviene darle retos mayores para que no se aburra. Ayuda a sus compañeros con paciencia.",
    "Excelente lapso. Participa con criterio propio y sustenta lo que dice. Hay que cuidar que no se confíe en las evaluaciones largas.",
    "Mantiene un rendimiento muy alto en todas las áreas y es referencia para el grupo. Le vendría bien animarse a exponer más en público."
  ],
  bueno: [
    "Trabaja con constancia y termina lo que empieza. Le cuesta pedir ayuda cuando no entiende: hay que animarlo a preguntar en el momento y no al final de la clase.",
    "Buen lapso, con una mejora clara desde el anterior. En los problemas de dos pasos se apura y responde antes de leer todo el enunciado.",
    "Cumple con sus asignaciones y participa cuando se le pregunta. Puede dar más: conviene un horario fijo de estudio en casa, corto pero diario."
  ],
  regular: [
    "Se distrae al final de la mañana y conviene sentarlo adelante. Cuando está atento resuelve sin dificultad, y eso se nota en las evaluaciones de la primera hora.",
    "Aprueba, pero con lo justo. Entrega las asignaciones incompletas: hay que revisar el cuaderno en casa dos veces por semana.",
    "Avanzó en lectura, pero Matemática le sigue costando. Se recomienda practicar en casa diez minutos diarios, sin esperar a la víspera de la evaluación."
  ],
  en_riesgo: [
    "Tiene varias áreas por debajo de lo esperado y está en riesgo de no aprobar el año. Es necesario que su representante venga al colegio para acordar un plan de apoyo.",
    "Falta con frecuencia y eso se refleja en sus notas: no logra seguir el hilo de las clases. Se citó al representante y todavía no ha asistido.",
    "No entrega las asignaciones y llega sin el material. Cuando trabaja acompañado demuestra que puede: necesita seguimiento diario en casa."
  ],
  inicial: [
    "Llegó al aula con mucha timidez y hoy participa en la ronda con entusiasmo. Conviene seguir leyéndole un cuento cada noche.",
    "Es un niño alegre y curioso. Todavía le cuesta compartir los juguetes: en casa ayuda jugar por turnos, con un reloj de arena.",
    "Avanzó mucho en su lenguaje durante este lapso: arma oraciones completas y cuenta lo que le pasó. Disfruta la música y el dibujo."
  ]
}.freeze

def perfil_de_informe(inscripcion, base_fija)
  return :inicial if inscripcion.section.grade.califica_con_texto?

  case base_fija || base_del_alumno(numero_de(inscripcion.student))
  when 17.. then :sobresaliente
  when 14.. then :bueno
  when 12.. then :regular
  else :en_riesgo
  end
end

# Escribe los informes de una sección para un lapso. `proporcion` es cuántos de
# cada tres: un lapso terminado los tiene todos; uno que corre, dos de cada tres.
def informar!(seccion, lapso, indice, escribe:, de_cada_tres: 3, objetivo: {})
  ahora = Time.current
  filas = lista_de(seccion).filter_map do |inscripcion, puesto|
    next unless inscripcion.regular?
    next if (puesto % 3) >= de_cada_tres

    base = SEMILLA[:bases][inscripcion.student_id] || objetivo[puesto]
    textos = INFORMES.fetch(perfil_de_informe(inscripcion, base))
    { enrollment_id: inscripcion.id, evaluation_moment_id: lapso.id, escrito_por_id: escribe.id,
      cuerpo: textos[(numero_de(inscripcion.student) + indice) % textos.size],
      school_id: seccion.school_id, created_at: ahora, updated_at: ahora }
  end

  Informe.insert_all(filas, unique_by: %i[enrollment_id evaluation_moment_id]) if filas.any?
  filas.size
end

paso "✍️  Informes descriptivos"

Current.school = bolivar
director = User.find_by!(email: CORREO_DEL_DIRECTOR)
SEMILLA[:director_bolivar] = director

informes = SEMILLA[:secciones_bolivar].sum do |seccion, _|
  propio = particularidades_de(seccion)
  quien = seccion.leader_teacher&.user || director

  lapsos_del_anterior.each_with_index.sum do |(lapso, indice)|
    informar!(seccion, lapso, indice, escribe: quien, objetivo: propio[:objetivo])
  end
end
puts "   ✓ #{informes} informes en #{anterior.name}: uno por alumno y por lapso"

# ── Cerrar los lapsos: el visto bueno de Control de Estudio ──────────────────
#
# Es lo que convierte un año calificado en un año TERMINADO: se emiten los
# boletines, la familia los ve y el profesor deja de poder tocar las notas.
#
# ⚠️ Con el MISMO código que usa el colegio (`BoletinesDelLapso#cerrar!`), no
# con filas escritas a mano: un boletín es una foto de las notas, y la foto la
# tiene que tomar quien sabe tomarla.
#
# ⚠️ Inicial no cierra: no tiene boletín por lapso —lo suyo son las
# valoraciones y el informe—, y `BoletinesDelLapso` cuenta notas con número.
#
# Los códigos van FIJOS (`codigo_fijo`): la muestra se siembra cada noche, y el
# código que alguien anotó para enseñar `/verificar` tiene que seguir existiendo.
def cerrar_lo_terminado!(seccion, lapsos, por:)
  return 0 if seccion.grade.califica_con_texto?

  lapsos.sum do |lapso|
    next 0 unless lapso.ends_on < HOY

    boletines = BoletinesDelLapso.de(seccion, lapso)
    next 0 if boletines.cerrada? || !boletines.se_puede_cerrar?

    # Control de Estudio cierra unos días después de que termina el lapso —y
    # nunca en el futuro, si el lapso terminó ayer—.
    cuando = [ a_las_diez(dia_habil(lapso.ends_on + 3)), Time.current ].min
    cierre = boletines.cerrar!(por: por, cuando: cuando)

    cierre.boletines.each do |boletin|
      alumno = boletin.enrollment.student
      boletin.update_columns(code: codigo_fijo("BOL", alumno.school_card, seccion.academic_period.name, lapso.name),
                             created_at: cuando, updated_at: cuando)
    end
    cierre.boletines.size
  end
end

paso "🔒 Lapsos cerrados y boletines"

Current.school = bolivar
coordinadora = User.find_by!(email: "coord.bolivar@siga.edu")
SEMILLA[:coordinadora_bolivar] = coordinadora

boletines = SEMILLA[:secciones_bolivar].sum do |seccion, _|
  cerrar_lo_terminado!(seccion, lapsos_del_anterior, por: coordinadora)
end

sin_cerrar = SEMILLA[:secciones_bolivar].count do |seccion, _|
  !seccion.grade.califica_con_texto? &&
    lapsos_del_anterior.any? { |lapso| !SectionClosure.cerrado?(section_id: seccion.id, evaluation_moment_id: lapso.id) }
end

puts "   ✓ #{boletines} boletines emitidos y en manos de las familias · " \
     "#{SectionClosure.count} cierres de lapso en #{anterior.name}"
puts "     ⚠️  #{sin_cerrar} secciones con algún lapso SIN cerrar: revisar por qué" if sin_cerrar.positive?
