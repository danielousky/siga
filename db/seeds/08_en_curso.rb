# El año que corre, hasta HOY — y la asistencia de los dos años.
#
# Con el mismo motor del paso 06, pero parado en la fecha de hoy:
#
#     LAPSO TERMINADO    como el año anterior: todo calificado, cerrado y con boletines
#     LAPSO QUE CORRE    lo que ya venció está calificado —salvo el profesor atrasado—,
#                        lo que viene está planificado y sin notas
#     LAPSO POR EMPEZAR  nada
#
# ⚠️ Es acá donde vive lo desparejo, porque es acá donde pasa: el área que nadie
# planificó, la evaluación vencida sin calificar, el plan que no llega al 100 %,
# el alumno que faltó el día del taller. En un año cerrado esos estados no
# existen; en uno que corre son la pantalla de «quién no cargó notas».
#
# Y como la muestra se siembra cada noche, mañana hay un día más de asistencia,
# y el mes que viene otra evaluación calificada.

# ── El ritmo de cada docente ─────────────────────────────────────────────────
#
# De cada veinte áreas-por-sección, en el lapso que corre:
#
#     16  al día        lo vencido está calificado
#      1  atrasado      lo último que venció está sin calificar
#      2  a medias      el plan suma 70 %: le falta una evaluación
#      1  sin plan      ni una evaluación cargada
#
# ⚠️ Uno de cada veinte atrasado, y no tres. Con tres, «Carga de notas» abría
# con veintiún profesores por llamar en un colegio de veintitrés: la pantalla
# que tiene que señalar al que se quedó atrás decía que se quedaron todos.
#
# Sale del nombre de la sección y del área, no de un sorteo: la misma siembra
# deja atrasado al mismo profesor.
def ritmo_sorteado(seccion, materia)
  n = suerte(seccion.grade.name, seccion.name, materia.code, "ritmo", de: 20)
  if n < 16 then :al_dia
  elsif n < 17 then :atrasado
  elsif n < 19 then :a_medias
  else :sin_plan
  end
end

# ⚠️ Lo que ven las tres puertas de la muestra no se deja al sorteo.
#
#     EL PROFESOR (García, Matemática)   tiene trabajo esperándolo al entrar:
#        1er Año B     atrasado   → «le falta calificar el taller»
#        6to Grado A   a medias   → el medidor dice «faltan 30 %»
#        el resto      al día     → hay notas que mirar y corregir
#
#     LA FAMILIA (5to Grado A y 2do Año A)   Matemática y Castellano al día:
#        quien entra como representante ve notas de esta semana, no «Pendiente»
RITMO_FIJO = {
  [ "1er Año", "B", "MAT" ]   => :atrasado,
  [ "6to Grado", "A", "MAT" ] => :a_medias,
  [ "5to Grado", "A", "MAT" ] => :al_dia,
  [ "5to Grado", "A", "LEN" ] => :al_dia,
  [ "5to Grado", "A", "CNA" ] => :al_dia,
  [ "2do Año", "A", "MAT" ]   => :al_dia,
  [ "2do Año", "A", "LEN" ]   => :al_dia,
  [ "2do Año", "A", "ING" ]   => :al_dia,
  [ "1er Año", "A", "MAT" ]   => :al_dia,
  [ "3er Año", "A", "MAT" ]   => :al_dia
}.freeze

def ritmo_de(seccion)
  lambda do |materia|
    RITMO_FIJO[[ seccion.grade.name, seccion.name, materia.code ]] || ritmo_sorteado(seccion, materia)
  end
end

# Lo que tiene de particular cada sección del año que corre.
#
#     4to Grado A   los cinco de la escala literal, otra vez: es la cohorte nueva
#     2do Año A     un alumno sin nota en el último taller de Matemática: «sin
#                   nota» no es cero, y la planilla tiene que mostrar el hueco
def particularidades_de_hoy(seccion)
  grado, nombre = seccion.grade.name, seccion.name

  { objetivo: (grado == "4to Grado" && nombre == "A" ? LITERALES : {}),
    ausentes: (grado == "2do Año" && nombre == "A" ? [ 3 ] : []) }
end

# Evalúa una sección en un año, parada en HOY. Sirve para cualquier colegio.
def evaluar_hasta_hoy!(seccion, lapsos, escribe:, cierra:)
  if seccion.grade.califica_con_texto?
    valorar!(seccion, lapsos)
    return 0
  end

  propio = particularidades_de_hoy(seccion)
  cargadas = 0

  lapsos.each_with_index do |lapso, indice|
    case situacion_del_lapso(lapso)
    when :terminado
      cargadas += evaluar_lapso!(seccion, lapso, indice, objetivo: propio[:objetivo])
      informar!(seccion, lapso, indice, escribe: seccion.leader_teacher&.user || escribe,
                                        objetivo: propio[:objetivo])
    when :corriendo
      # Lo de ayer para atrás: lo de hoy todavía no se corrigió.
      cargadas += evaluar_lapso!(seccion, lapso, indice, hasta: HOY - 1, ritmo: ritmo_de(seccion), **propio)
    end
  end

  GradeCalculator.calculate_all_for_section(seccion)
  cerrar_lo_terminado!(seccion, lapsos, por: cierra)
  cargadas
end

paso "📝 #{SEMILLA[:en_curso].name}: lo evaluado hasta hoy"

bolivar  = SEMILLA[:bolivar]
en_curso = SEMILLA[:en_curso]
lapsos_de_hoy = lapsos_de(en_curso)
Current.school = bolivar

secciones_de_hoy = Section.where(academic_period_id: en_curso.id).includes(:grade)
                          .sort_by { |s| [ s.grade.orden.to_i, s.name ] }
SEMILLA[:secciones_de_hoy] = secciones_de_hoy

cargadas = secciones_de_hoy.sum do |seccion|
  evaluar_hasta_hoy!(seccion, lapsos_de_hoy, escribe: SEMILLA[:director_bolivar], cierra: SEMILLA[:coordinadora_bolivar])
end

corre = lapsos_de_hoy.find { |l| situacion_del_lapso(l) == :corriendo }
puts "   ✓ #{cargadas} notas en #{en_curso.name} · " \
     "#{corre ? "corre el #{corre.name.downcase}" : 'ningún lapso corre hoy'}"

if corre
  planes = secciones_de_hoy.reject { |s| s.grade.califica_con_texto? }.flat_map do |seccion|
    seccion.grade.subjects.map { |materia| ritmo_de(seccion).call(materia) }
  end.tally
  puts "     áreas por sección: #{planes[:al_dia].to_i} al día · #{planes[:atrasado].to_i} atrasadas · " \
       "#{planes[:a_medias].to_i} con el plan a medias · #{planes[:sin_plan].to_i} sin plan"

  # ── Los informes del lapso que corre ───────────────────────────────────────
  #
  # A mitad de lapso la mayoría no está escrita, y es lo normal. Van los de las
  # secciones de la familia de la muestra —dos de cada tres, que es como los
  # lleva una maestra—: quien entra como representante encuentra el informe del
  # docente, y quien entra como dirección encuentra a quién le falta.
  indice = lapsos_de_hoy.index(corre)
  con_informes = secciones_de_hoy.select do |s|
    [ [ "3er Nivel", "U" ], [ "5to Grado", "A" ], [ "2do Año", "A" ], [ "1er Grado", "A" ] ].include?([ s.grade.name, s.name ])
  end
  escritos = con_informes.sum do |seccion|
    informar!(seccion, corre, indice, escribe: seccion.leader_teacher&.user || SEMILLA[:director_bolivar],
                                      de_cada_tres: 2)
  end

  # ⚠️ Los tres hijos de la familia de la muestra SÍ tienen el suyo: el «dos de
  # cada tres» va por puesto en la lista, y no puede dejar afuera justo al que
  # se va a mirar.
  SEMILLA[:hijos_de_la_muestra].each do |alumno|
    inscripcion = Enrollment.joins(:section).find_by(student_id: alumno.id, sections: { academic_period_id: en_curso.id })
    next if inscripcion.nil? || Informe.exists?(enrollment_id: inscripcion.id, evaluation_moment_id: corre.id)

    textos = INFORMES.fetch(perfil_de_informe(inscripcion, SEMILLA[:bases][alumno.id]))
    Informe.create!(enrollment: inscripcion, evaluation_moment: corre,
                    escrito_por: inscripcion.section.leader_teacher&.user || SEMILLA[:director_bolivar],
                    cuerpo: textos[numero_de(alumno) % textos.size])
    escritos += 1
  end
  puts "     #{escritos} informes del #{corre.name.downcase} ya escritos: el resto, por escribir"
end

# ── Bello: su único año, hasta hoy ───────────────────────────────────────────
Current.school = SEMILLA[:bello]
lapsos_de_bello = lapsos_de(SEMILLA[:bello_en_curso])
director_de_bello = User.find_by!(email: "director.bello@siga.edu")

notas_de_bello = SEMILLA[:secciones_bello].sum do |seccion, _|
  evaluar_hasta_hoy!(seccion, lapsos_de_bello, escribe: director_de_bello, cierra: director_de_bello)
end
puts "   ✓ #{notas_de_bello} notas en Bello, #{SEMILLA[:bello_en_curso].name}"

# ── En vacaciones: el año que viene, armado y vacío ──────────────────────────
#
# Un colegio en agosto tiene el año siguiente con su estructura copiada y sin un
# solo alumno adentro: es exactamente el estado desde el que se promueve
# (MOR-169). Solo pasa cuando el año en curso ya terminó.
if SEMILLA[:siguiente]
  Current.school = bolivar
  copia = CopiarLaEstructura.de(en_curso, al: SEMILLA[:siguiente])
  puts "   ✓ #{SEMILLA[:siguiente].name}: #{copia.total_secciones} secciones copiadas, sin alumnos — " \
       "falta promover"
end

# ── Asistencia ───────────────────────────────────────────────────────────────
#
# ⚠️ Los días salen de los LAPSOS, no del calendario corrido: entre un lapso y
# el siguiente hay vacaciones, y pasar lista el 28 de diciembre es un dato que
# no puede existir.
#
#     AÑO ANTERIOR   los últimos diez días de clase de cada lapso
#     AÑO EN CURSO   las últimas tres semanas, hasta AYER
#
# Hoy no se pasó lista todavía, y es a propósito: quien entra como profesor
# guía encuentra la lista de hoy esperándolo.
#
# Los patrones están elegidos para que el reporte muestre casos distintos y no
# una lista plana:
#
#   · el puesto 1 acumula faltas SIN justificar      → el caso que dispara la llamada
#   · el puesto 2 falta dos veces, las dos JUSTIFICADAS → no debe salir en el reporte
#   · el puesto 3 llega tarde seguido, que no es lo mismo que faltar
#   · y el resto falta de vez en cuando, como en cualquier salón
paso "🗓️  Asistencia"

FALTAS = { 1 => [ 1, 3, 5, 8 ], 2 => [ 2, 6 ] }.freeze
TARDES = { 3 => [ 1, 2, 4, 7, 9 ] }.freeze

def dias_de_clase(lapsos, hasta:)
  lapsos.flat_map { |lapso| dias_habiles(lapso.starts_on, [ lapso.ends_on, hasta ].min) }
end

# Pasa lista de una sección en esos días. Se inserta en bruto: son miles de
# filas y nada se calcula a partir de ellas.
def pasar_lista!(seccion, dias, registra:, justifica:)
  return 0 if dias.empty?

  ahora = Time.current
  filas = []

  lista_de(seccion).each do |inscripcion, puesto|
    next unless inscripcion.regular?

    k = numero_de(inscripcion.student)
    dias.each_with_index do |dia, di|
      n = di % 10
      estado = if FALTAS[puesto]&.include?(n) then :ausente
               elsif TARDES[puesto]&.include?(n) then :tarde
               elsif suerte(k, dia, de: 40).zero? then :ausente   # alguno falta, de vez en cuando
               else :presente
               end

      fila = { enrollment_id: inscripcion.id, date: dia, status: Attendance.statuses[estado],
               recorded_by_id: registra.id, justificacion: nil, justificada_en: nil,
               justificada_por_id: nil, school_id: seccion.school_id, created_at: ahora, updated_at: ahora }

      # El puesto 2 sí trajo el justificativo: la secretaría lo cargó al día
      # siguiente. Sirve para ver que el reporte NO lo cuenta.
      if puesto == 2 && estado == :ausente
        fila.merge!(justificacion: "Reposo médico presentado por el representante",
                    justificada_en: a_las_diez(dia + 1), justificada_por_id: justifica.id)
      end

      filas << fila
    end
  end

  filas.each_slice(5_000) { |tanda| Attendance.insert_all(tanda, unique_by: %i[enrollment_id date]) }
  filas.size
end

Current.school = bolivar
secretaria = User.find_by!(email: "secretaria.bolivar@siga.edu")
registros = 0

# El año anterior: los últimos diez días de cada lapso.
SEMILLA[:secciones_bolivar].each do |seccion, _|
  dias = lapsos_de(SEMILLA[:anterior]).flat_map { |lapso| dias_habiles(lapso.starts_on, lapso.ends_on).last(10) }
  registros += pasar_lista!(seccion, dias, registra: seccion.leader_teacher&.user || SEMILLA[:director_bolivar],
                                           justifica: secretaria)
end

# El año en curso: las últimas tres semanas, hasta ayer.
dias_de_hoy = dias_de_clase(lapsos_de_hoy, hasta: HOY - 1).last(15)
secciones_de_hoy.each do |seccion|
  # ⚠️ Sin guía, la asistencia la toma la dirección: y la dirección no llega a
  # todas las secciones todos los días. Esa queda con la lista sin pasar.
  next if seccion.leader_teacher.nil?

  registros += pasar_lista!(seccion, dias_de_hoy, registra: seccion.leader_teacher.user, justifica: secretaria)
end

# ⚠️ La asistencia de la familia de la muestra va A MANO. Su puesto en la lista
# cambió con la promoción, y el patrón por puesto podía dejar a Diego con cuatro
# faltas sin justificar: la primera pantalla de quien entra como representante
# sería una alarma. Lo que se quiere ver ahí es un caso de cada uno:
#
#     CAMILA     una falta SIN justificar, hace unos días  → el aviso de «falta el justificativo»
#     DIEGO      asistencia perfecta
#     VALENTINA  una falta JUSTIFICADA y una tardanza
camila, diego, valentina = SEMILLA[:hijos_de_la_muestra]
{ camila => { 3 => :ausente }, diego => {},
  valentina => { 6 => :ausente_justificada, 2 => :tarde } }.each do |alumno, excepciones|
  next if alumno.nil?

  inscripcion = Enrollment.joins(:section).find_by(student_id: alumno.id, sections: { academic_period_id: en_curso.id })
  next if inscripcion.nil?

  Attendance.where(enrollment_id: inscripcion.id).delete_all
  guia = inscripcion.section.leader_teacher&.user || SEMILLA[:director_bolivar]

  dias_de_hoy.reverse.each_with_index do |dia, hace|
    que = excepciones[hace] || :presente
    Attendance.create!(
      enrollment: inscripcion, date: dia, recorded_by: guia,
      status: (que == :ausente_justificada ? :ausente : que),
      justificacion: ("Consulta médica: trajo la constancia" if que == :ausente_justificada),
      justificada_en: (a_las_diez(dia + 1) if que == :ausente_justificada),
      justificada_por: (secretaria if que == :ausente_justificada)
    )
  end
end

Current.school = SEMILLA[:bello]
dias_de_bello = dias_de_clase(lapsos_de_bello, hasta: HOY - 1).last(15)
SEMILLA[:secciones_bello].each do |seccion, _|
  registros += pasar_lista!(seccion, dias_de_bello,
                            registra: seccion.leader_teacher&.user || director_de_bello, justifica: director_de_bello)
end

Current.school = bolivar
sin_justificar = Current.sin_aislamiento { Attendance.unscoped.sin_justificar.count }
puts "   ✓ #{registros} registros de asistencia · #{dias_de_hoy.size} días de #{en_curso.name}, hasta ayer"
puts "     #{sin_justificar} faltas sin justificar · " \
     "#{Current.sin_aislamiento { Attendance.unscoped.where(status: :tarde).count }} tardanzas · hoy, sin pasar"
