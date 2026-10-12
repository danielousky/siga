# Lo que deja el uso diario: la cobranza, los mensajes, los documentos, lo que
# el colegio le paga a SIGA, y la bitácora de todo eso.
#
# Son las pantallas que más se abren y las que un colegio recién sembrado tenía
# vacías: Finanzas sin un solo pago, «Suscripción» sin historial, la ficha de un
# representante sin un mensaje. Una pantalla vacía no enseña para qué sirve.

bolivar  = SEMILLA[:bolivar]
bello    = SEMILLA[:bello]
anterior = SEMILLA[:anterior]
en_curso = SEMILLA[:en_curso]

director   = SEMILLA[:director_bolivar]
finanzas   = User.find_by!(email: "finanzas.bolivar@siga.edu")
secretaria = User.find_by!(email: "secretaria.bolivar@siga.edu")

# ── La cobranza a las familias ───────────────────────────────────────────────
#
# Spec: `docs/specs/pagos-de-la-familia.md`. El colegio fija lo que cobra en el
# año —la inscripción y doce mensualidades—, cada alumno tiene sus cuotas, la
# familia reporta su pago y la oficina lo valida.
#
#     AÑO ANTERIOR   todo cobrado, salvo unos pocos que se fueron debiendo
#     AÑO EN CURSO   de cada veinticinco familias:
#                      17  al día            lo vencido, pagado
#                       3  en mora           deben octubre, o septiembre y octubre
#                       2  esperando         reportaron: falta que la oficina valide
#                       1  rechazado         el reporte no coincidió con el banco
#                       2  adelantados       pagaron también lo que viene
#
# ⚠️ Las cuotas se insertan en bruto —son miles— y los REPORTES pasan por el
# modelo, con su comprobante: es lo que la oficina va a abrir para revisar.
paso "💵 Cobranza a las familias"

VOUCHER = Rails.root.join("db/qa/voucher_de_prueba.jpg")

MENSUALIDAD = 45
INSCRIPCION_DEL_ANIO = 120

def sembrar_conceptos!(periodo)
  Fee.calendario_propuesto(periodo, mensualidad: MENSUALIDAD, inscripcion: INSCRIPCION_DEL_ANIO).map do |datos|
    Fee.find_or_create_by!(academic_period: periodo, nombre: datos[:nombre]) do |f|
      f.monto    = datos[:monto]
      f.vence_el = datos[:vence_el]
      f.orden    = datos[:orden]
    end
  end
end

# Las cuotas de un año, de una sola vez. `pagada_hasta` dice, por inscripción,
# hasta qué fecha de vencimiento está pagado.
def emitir_cuotas!(periodo, conceptos, pagada_hasta:)
  ahora = Time.current
  inscripciones = Enrollment.where(section_id: Section.where(academic_period_id: periodo.id).select(:id),
                                   status: :regular).includes(:student).to_a

  filas = inscripciones.flat_map do |inscripcion|
    tope = pagada_hasta.call(inscripcion)

    conceptos.map do |concepto|
      pagado = tope && concepto.vence_el <= tope
      { enrollment_id: inscripcion.id, fee_id: concepto.id, monto: concepto.monto, vence_el: concepto.vence_el,
        # Pagó un par de días antes de que venciera, como paga la mayoría.
        pagado_el: (a_las_diez([ concepto.vence_el - 2, HOY ].min) if pagado),
        school_id: inscripcion.school_id, created_at: ahora, updated_at: ahora }
    end
  end

  filas.each_slice(5_000) { |tanda| Charge.insert_all(tanda) }
  [ inscripciones, filas.size ]
end

# En qué está cada familia este año. Sale del número del alumno: la misma
# siembra deja en mora a la misma gente.
def situacion_de_pago(alumno)
  case suerte(numero_de(alumno), "pago", de: 25)
  when 0..16  then :al_dia
  when 17..19 then :en_mora
  when 20..21 then :esperando
  when 22     then :rechazado
  else :adelantado
  end
end

Current.school = bolivar

conceptos_de_antes = sembrar_conceptos!(anterior)
conceptos_de_hoy   = sembrar_conceptos!(en_curso)

# El año anterior: cobrado entero, salvo seis que se fueron debiendo desde junio.
ultimo_de_antes = conceptos_de_antes.map(&:vence_el).max
junio = conceptos_de_antes.find { |c| c.nombre == "Junio" }&.vence_el
_, cuotas_de_antes = emitir_cuotas!(anterior, conceptos_de_antes, pagada_hasta: lambda { |inscripcion|
  (numero_de(inscripcion.student) % 60).zero? ? junio - 1 : ultimo_de_antes
})

# El año en curso. «Lo vencido» es lo que venció hasta HOY.
vencido = conceptos_de_hoy.select { |c| c.vence_el <= HOY }.map(&:vence_el).max
un_mes_mas = conceptos_de_hoy.map(&:vence_el).select { |d| d > HOY }.min(2).last

# ⚠️ Los que se van a mirar no se dejan al sorteo:
#
#     la familia de la muestra   al día — y Diego con octubre «en revisión»
#     Miguel Pérez (María Pérez) en mora: es la pantalla «primero póngase al día»
#     Sofía Ramos (José Ramos)   rechazado: el motivo se lee en su pantalla
#     Álvaro López (Carmen López) al día
hijos = SEMILLA[:hijos_de_la_muestra]
un_ano_a_de_antes = SEMILLA[:alumnos_bolivar].find { |s, _| s.grade.name == "1er Año" && s.name == "A" }&.last || []
PAGO_FIJO = {
  hijos[0]&.id => :al_dia, hijos[1]&.id => :esperando, hijos[2]&.id => :al_dia,
  un_ano_a_de_antes[0]&.id => :al_dia, un_ano_a_de_antes[1]&.id => :rechazado, un_ano_a_de_antes[2]&.id => :en_mora
}.reject { |alumno_id, _| alumno_id.nil? }.freeze

# ⚠️ El plan se decide ANTES de emitir, con sus topes.
#
# Los reportes se acotan —doce esperando, seis rechazados—, y no es por tiempo:
# con treinta en la bandeja ya no se REVISA nada, se escrolea. Pero el tope
# tiene que conocerse antes de emitir las cuotas: decidido después, los que
# quedaban fuera del tope tenían la cuota sin pagar y sin reporte, o sea en
# mora, y el colegio de la muestra amanecía con uno de cada cinco alumnos
# debiendo. Quien queda fuera del tope —o no tiene quien reporte por él, porque
# su representante no tiene correo— está al día.
TOPES_DE_REPORTES = { esperando: 12, rechazado: 6 }.freeze

def representante_de(alumno)
  StudentRepresentative.where(student_id: alumno.id).order(principal: :desc, id: :asc).first&.representative
end

puede_reportar = ->(alumno) { representante_de(alumno)&.user&.email.present? }
van = Hash.new(0)

plan_de_pagos = Enrollment.where(section_id: Section.where(academic_period_id: en_curso.id).select(:id), status: :regular)
                          .includes(:student)
                          .sort_by { |i| [ PAGO_FIJO.key?(i.student_id) ? 0 : 1, i.id ] }   # los fijos, primero
                          .to_h do |inscripcion|
  alumno = inscripcion.student
  que = PAGO_FIJO[alumno.id] || situacion_de_pago(alumno)

  if TOPES_DE_REPORTES.key?(que)
    if van[que] < TOPES_DE_REPORTES[que] && puede_reportar.call(alumno)
      van[que] += 1
    else
      que = :al_dia
    end
  end
  [ alumno.id, que ]
end

situacion = ->(alumno) { plan_de_pagos.fetch(alumno.id, :al_dia) }

inscripciones_de_hoy, cuotas_de_hoy = emitir_cuotas!(en_curso, conceptos_de_hoy, pagada_hasta: lambda { |inscripcion|
  next nil if vencido.nil?

  case situacion.call(inscripcion.student)
  when :al_dia     then vencido
  when :adelantado then un_mes_mas || vencido
  when :en_mora    then numero_de(inscripcion.student).even? ? vencido - 20 : vencido - 50   # debe una, o dos
  else vencido - 20   # esperando y rechazado: pagaron todo menos la última
  end
})

puts "   ✓ #{conceptos_de_hoy.size} conceptos por año · #{cuotas_de_antes} cuotas en #{anterior.name} · " \
     "#{cuotas_de_hoy} en #{en_curso.name}"

# ── Los reportes de pago ─────────────────────────────────────────────────────
#
# ⚠️ Solo de la ÚLTIMA cuota vencida, y con fecha de esta semana: el modelo no
# deja reportar un pago de hace más de un mes, y está bien que no deje.
#
def reportar_pago!(inscripcion, cuota, representante, hace_dias:, nota: nil, con_voucher: true)
  persona = representante.user
  reporte = PaymentReport.new(
    representative: representante,
    referencia: "#{(numero_de(inscripcion.student) * 7919 % 9000 + 1000)}-#{format('%04d', inscripcion.id % 10_000)}",
    banco: Banco::CODIGOS[numero_de(inscripcion.student) % 4],
    monto: cuota.monto * 36.5, pagado_el: HOY - hace_dias,
    depositante_nombre: persona.nombre_completo, depositante_documento: persona.document,
    nota: nota
  )
  if con_voucher && VOUCHER.exist?
    reporte.voucher.attach(io: File.open(VOUCHER), filename: "comprobante.jpg", content_type: "image/jpeg")
  end
  reporte.save!
  reporte.declarar!([ cuota ])
  reporte.update_columns(created_at: a_las_diez(HOY - hace_dias) + 5.hours)
  reporte
end

esperando = rechazados = validados = 0

if vencido
  ultima = conceptos_de_hoy.select { |c| c.vence_el <= HOY }.max_by(&:vence_el)
  cuota_de = lambda do |inscripcion|
    Charge.find_by(enrollment_id: inscripcion.id, fee_id: ultima.id)
  end

  # Los fijos primero: si el tope los dejara afuera, la familia de la muestra
  # no tendría su pago «en revisión».
  en_orden = inscripciones_de_hoy.sort_by { |i| [ PAGO_FIJO.key?(i.student_id) ? 0 : 1, i.id ] }

  en_orden.each do |inscripcion|
    alumno = inscripcion.student
    representante = representante_de(alumno)
    next if representante.nil? || representante.user.email.blank?

    cuota = cuota_de.call(inscripcion)
    next if cuota.nil? || cuota.pagado?

    case situacion.call(alumno)
    when :esperando
      reportar_pago!(inscripcion, cuota, representante, hace_dias: 1 + (esperando % 3),
                     nota: (esperando.zero? ? "Transferí desde la cuenta de su papá." : nil))
      esperando += 1
    when :rechazado
      reporte = reportar_pago!(inscripcion, cuota, representante, hace_dias: 4 + (rechazados % 3))
      reporte.rechazar!(por: finanzas, cuando: a_las_diez(HOY - 2),
                        motivo: [ "La referencia no aparece en el estado de cuenta del colegio.",
                                  "El monto transferido no cubre la cuota: faltan Bs. 320,00.",
                                  "El comprobante es de otro banco: verifique a qué cuenta transfirió." ][rechazados % 3])
      rechazados += 1
    end
  end

  # Y unos cuantos que SÍ se validaron esta semana: la oficina tiene historia.
  inscripciones_de_hoy.select { |i| situacion.call(i.student) == :al_dia }.first(10).each_with_index do |inscripcion, n|
    representante = representante_de(inscripcion.student)
    next if representante.nil? || representante.user.email.blank?

    cuota = cuota_de.call(inscripcion)
    next if cuota.nil?

    # Estaba pagada a mano; se vuelve a dejar pendiente para que la valide un
    # reporte, que es como se paga de verdad.
    cuota.update_columns(pagado_el: nil)
    reporte = reportar_pago!(inscripcion, cuota, representante, hace_dias: 6 + (n % 4), con_voucher: n < 3)
    reporte.validar!(por: finanzas, cuando: a_las_diez(HOY - 5 - (n % 3)))
    validados += 1
  end
end

en_mora = inscripciones_de_hoy.count { |i| EstadoDeCuenta.de(i).en_mora? }
puts "   ✓ reportes de pago: #{esperando} esperando revisión · #{rechazados} rechazados · #{validados} validados"
puts "     #{en_mora} alumnos en mora hoy, de #{inscripciones_de_hoy.size}"

# ── Mensajes a las familias (MOR-181 · MOR-186) ──────────────────────────────
#
# Lo que el colegio le escribió a cada quien, desde su ficha. En la muestra no
# salió ninguno —ahí no sale correo—, pero el registro es el mismo: a quién,
# quién, qué, cuándo y a qué dirección.
paso "✉️  Mensajes a las familias"

def mensaje!(colegio, para:, de:, asunto:, cuerpo:, hace_dias:)
  return if para.nil? || para.email.blank?

  mensaje = Mensaje.create!(school: colegio, destinatario: para, remitente: de, asunto: asunto,
                            cuerpo: cuerpo, correo: para.email)
  mensaje.update_columns(created_at: a_las_diez(HOY - hace_dias), updated_at: a_las_diez(HOY - hace_dias))
  mensaje
end

Current.school = bolivar
andreina = User.find_by(email: CORREO_DE_LA_REPRESENTANTE)
maria    = User.find_by(email: "maria.perez@familia.test")
jose     = User.find_by(email: "jose.ramos@familia.test")
carmen   = User.find_by(email: "carmen.lopez@familia.test")

mensajes = [
  mensaje!(bolivar, para: andreina, de: secretaria, hace_dias: 12,
           asunto: "Reunión de representantes de 5to Grado",
           cuerpo: "Buenas tardes. Le recordamos que la reunión de representantes de 5to Grado A es este " \
                   "viernes a las 7:30 a. m., en el aula 1-8. Se entregará el plan de evaluación del lapso."),
  mensaje!(bolivar, para: andreina, de: secretaria, hace_dias: 4,
           asunto: "Falta el justificativo de Camila",
           cuerpo: "Buen día. Camila faltó el martes y no tenemos el justificativo. Si tiene el reposo, " \
                   "puede traerlo a secretaría o enviarlo por este medio."),
  mensaje!(bolivar, para: andreina, de: director, hace_dias: 1,
           asunto: "Recibimos su reporte de pago",
           cuerpo: "Buenas tardes. Recibimos el reporte del pago de octubre de Diego. Administración lo " \
                   "valida en las próximas veinticuatro horas; no hace falta que lo reporte de nuevo."),
  mensaje!(bolivar, para: maria, de: finanzas, hace_dias: 3,
           asunto: "Cuota de octubre pendiente",
           cuerpo: "Buen día. Le escribimos porque la cuota de octubre de Miguel sigue pendiente. Si ya " \
                   "pagó, por favor repórtelo desde su cuenta con el comprobante."),
  mensaje!(bolivar, para: jose, de: finanzas, hace_dias: 2,
           asunto: "Su reporte de pago no pudo validarse",
           cuerpo: "Buenas tardes. La referencia que reportó no aparece en el estado de cuenta del colegio. " \
                   "Por favor verifique el número y repórtelo otra vez."),
  mensaje!(bolivar, para: carmen, de: secretaria, hace_dias: 9,
           asunto: "Constancia de estudios lista",
           cuerpo: "Buen día. La constancia de estudios de Álvaro ya está emitida. Puede retirarla en " \
                   "secretaría o verificarla en línea con el código que lleva al pie.")
].compact
puts "   ✓ #{mensajes.size} mensajes, cada uno en la ficha de su destinatario"

# ── Constancias de estudio ───────────────────────────────────────────────────
#
# El documento que más pide una familia. Cada una lleva un código que cualquiera
# verifica en `/verificar` sin llamar al colegio — y el código es FIJO, para que
# el que se anotó ayer para enseñarlo siga existiendo hoy.
paso "📄 Constancias"

Current.school = bolivar
con_constancia = (un_ano_a_de_antes.first(1) + hijos.last(1) + inscripciones_de_hoy.first(6).map(&:student)).uniq

constancias = con_constancia.each_with_index.filter_map do |alumno, n|
  inscripcion = inscripciones_de_hoy.find { |i| i.student_id == alumno.id }
  next if inscripcion.nil?

  constancia = Constancia.emitir!(inscripcion, por: secretaria)
  constancia.update_columns(code: codigo_fijo("CON", alumno.school_card, en_curso.name),
                            created_at: a_las_diez(HOY - 2 - n), updated_at: a_las_diez(HOY - 2 - n))
  constancia
end
SEMILLA[:constancias] = constancias
puts "   ✓ #{constancias.size} constancias emitidas · para probar /verificar: #{constancias.first&.code}"

# ── Suscripciones: lo que el colegio le paga a SIGA ──────────────────────────
#
# Spec `del-registro-al-cobro`. Los dos colegios en estados distintos, para
# poder VER la degradación a solo lectura sin fabricarla a mano.
#
#     BOLÍVAR   activa, y vence en diez días: sin avisos a la vista. Con su
#               historia: dos meses validados y un reporte que se rechazó.
#     BELLO     vencida hace un mes: entra, ve todo, descarga boletines y
#               constancias, y no puede cargar una nota.
#
# ⚠️ Bello vencido es el caso que hay que poder mirar. Cortarle el acceso a
# mitad de año escolar sería quitarle las notas a sus alumnos, y la deuda es del
# colegio — el perjuicio no puede ser del alumno.
paso "💳 Suscripciones"

equipo = Current.sin_aislamiento { SigaStaff.joins(:user).find_by(role: :fundador)&.user }

def suscribir!(colegio, vence_en:, estado:)
  # ⚠️ `Subscription.matricula_de` NO puede pasar por el filtro de nivel: un
  # colegio de 360 alumnos con primaria elegida se facturaría como uno de 190.
  alumnos = Subscription.matricula_de(colegio.id)
  cotizacion = Subscription.cotizar(alumnos)

  suscripcion = Subscription.find_or_initialize_by(school: colegio)
  suscripcion.assign_attributes(
    # Por alumno, con el precio de hoy CONGELADO en la fila, como queda un
    # colegio al validarse su pago.
    plan: :por_alumno,
    precio_por_alumno: cotizacion.por_alumno, minimo_mensual: cotizacion.minimo,
    matricula_facturada: alumnos, precio_mensual: cotizacion.monto,
    vigente_desde: HOY + vence_en.days - 1.month, vigente_hasta: HOY + vence_en.days,
    status: estado, dias_de_gracia: 15
  )
  suscripcion.save!
  suscripcion
end

# Un pago de la suscripción que YA pasó: se escribe con su resultado. Los de
# hace más de un mes no pasarían la validación del modelo —que solo deja
# reportar pagos recientes—, y está bien que no pasen: esto es historia.
def pago_de_la_suscripcion!(suscripcion, por:, revisa:, hace_dias:, estado:, medio: "pago_movil", motivo: nil,
                            cubre: nil)
  cuando = a_las_diez(HOY - hace_dias)
  pago = SubscriptionPayment.nuevo_para(
    suscripcion, por: por, medio: medio, pagado_el: HOY - hace_dias,
    monto: (medio == "pago_movil" ? suscripcion.precio_mensual * 36.5 : suscripcion.precio_mensual),
    referencia: (medio == "efectivo" ? nil : "SG#{format('%06d', (suscripcion.school_id * 131 + hace_dias * 977) % 1_000_000)}"),
    nota: nil
  )
  pago.assign_attributes(estado: estado, revisado_por: revisa, revisado_el: cuando + 6.hours, motivo: motivo,
                         cubre_desde: cubre&.first, cubre_hasta: cubre&.last, created_at: cuando, updated_at: cuando)
  if medio != "efectivo" && VOUCHER.exist?
    pago.comprobante.attach(io: File.open(VOUCHER), filename: "comprobante.jpg", content_type: "image/jpeg")
  end
  pago.save!(validate: false)
  pago
end

Current.school = bolivar
suscripcion_de_bolivar = suscribir!(bolivar, vence_en: 10, estado: :activa)
desde, hasta = suscripcion_de_bolivar.vigente_desde, suscripcion_de_bolivar.vigente_hasta

pago_de_la_suscripcion!(suscripcion_de_bolivar, por: director, revisa: equipo, hace_dias: 53, estado: "validado",
                        cubre: [ desde - 1.month, desde ])
pago_de_la_suscripcion!(suscripcion_de_bolivar, por: finanzas, revisa: equipo, hace_dias: 24, estado: "rechazado",
                        motivo: "La referencia no aparece en la cuenta: revise el número y repórtelo otra vez.")
pago_de_la_suscripcion!(suscripcion_de_bolivar, por: finanzas, revisa: equipo, hace_dias: 22, estado: "validado",
                        medio: "binance", cubre: [ desde, hasta ])

Current.school = bello
director_de_bello = User.find_by!(email: "director.bello@siga.edu")
suscripcion_de_bello = suscribir!(bello, vence_en: -30, estado: :vencida)
pago_de_la_suscripcion!(suscripcion_de_bello, por: director_de_bello, revisa: equipo, hace_dias: 62, estado: "validado",
                        cubre: [ suscripcion_de_bello.vigente_desde, suscripcion_de_bello.vigente_hasta ])

Current.sin_aislamiento do
  Subscription.unscoped.includes(:school).order(:id).each do |s|
    pagos = SubscriptionPayment.unscoped.where(school_id: s.school_id).group(:estado).count
    puts "   ✓ #{s.school.name.ljust(22)} #{format('%.2f', s.precio_mensual).rjust(7)} $ · " \
         "#{s.matricula_facturada} alumnos · #{s.etiqueta_de_estado} · " \
         "pagos: #{pagos.map { |estado, n| "#{n} #{estado}" }.join(', ')}"
  end
end
puts "     Bello está VENCIDO a propósito: entra y ve todo, pero no carga nada nuevo"

# ── Los ajustes de SIGA: a dónde se paga ─────────────────────────────────────
#
# Sin ellos, «Suscripción» no tiene qué enseñar bajo «cómo pagar» (spec
# `del-registro-al-cobro`, § 5.3): un medio se ofrece solo con sus datos
# completos.
#
# ⚠️ Son datos DE EJEMPLO y se nota a propósito. La muestra es pública: una
# cuenta bancaria con forma de verdadera invitaría a alguien a transferirle a
# nadie. El titular lo dice, y los números son ceros.
#
# ⚠️ El WhatsApp NO se inventa: un número falso abre un chat con un desconocido.
# Sale de `SIGA_WHATSAPP` si la instancia lo tiene, y si no, no hay botón.
#
# En desarrollo se siembran solo si no hay ninguno —para no pisar los que
# alguien cargó probando `/siga/ajustes`—; en la muestra, siempre.
paso "⚙️  Ajustes de SIGA"

ajustes = SigaSetting.first || SigaSetting.new
if ajustes.new_record? || Muestra.activa?
  ajustes.update!(
    whatsapp: SigaSetting.whatsapp_del_entorno,
    titular: "SIGA · datos de ejemplo", documento: "J-00000000-0",
    pago_movil_banco: "0102", pago_movil_telefono: "0414-0000000",
    cuenta: "01020000000000000000", binance: "pagos@ejemplo.test"
  )
  puts "   ✓ cómo pagar: #{ajustes.medios.map { |m| SubscriptionPayment::MEDIOS.dig(m, :nombre) }.join(' · ')}"
  puts "     WhatsApp: #{ajustes.whatsapp.presence || 'sin número (falta SIGA_WHATSAPP): no se dibuja el botón'}"
else
  puts "   · ya había ajustes cargados: no se tocan"
end

# ── Las importaciones ────────────────────────────────────────────────────────
#
# Así llegó este colegio a SIGA: tres planillas, en el orden en que se suben.
# La FILA es la bitácora —quién cargó qué y con qué resultado—; el archivo ya no
# está, porque se borra a los treinta días (`PurgarPlanillasJob`).
paso "📥 Importaciones"

Current.school = bolivar
cuando_llego = a_las_diez(dia_habil(anterior.start_date - 20))

# Los números son los de verdad: lo que quedó en la base después de «importar».
secciones_importadas = SEMILLA[:secciones_bolivar].map { |s, _| "#{s.grade.name} #{s.name}" }
asignaciones_importadas = TeacherSection.where(section_id: SEMILLA[:secciones_bolivar].map { |s, _| s.id }).count
con_historial = Enrollment.where(section_id: Section.where(academic_period_id: SEMILLA[:historico].id).select(:id))
definitivas_importadas = FinalGradeBook.where(enrollment_id: con_historial.select(:id)).count
sin_correo = Representative.joins(:user).where(users: { email: nil }).limit(40).map { |r| r.user.apellidos_y_nombres }

[ { tipo: :pensum, nombre_del_archivo: "areas-y-profesores.xlsx", filas_leidas: asignaciones_importadas,
    resultado: { "materias_creadas" => bolivar.subjects.count, "materias_reutilizadas" => 0,
                 "profesores_creados" => Teacher.count, "profesores_reutilizados" => 0,
                 "asignaciones" => asignaciones_importadas, "secciones" => secciones_importadas, "fallidas" => [] } },
  { tipo: :matricula, nombre_del_archivo: "matricula-#{anterior.name}.xlsx", filas_leidas: 360,
    resultado: { "alumnos_creados" => 360, "alumnos_actualizados" => 0, "inscripciones" => 360,
                 "representantes_creados" => 308, "representantes_reutilizados" => 52,
                 "secciones" => secciones_importadas, "sin_correo" => sin_correo, "fallidas" => [] } },
  { tipo: :historial, nombre_del_archivo: "notas-#{SEMILLA[:historico].name}.xlsx", filas_leidas: con_historial.count,
    resultado: { "notas_de_lapso" => 0, "definitivas" => definitivas_importadas, "alumnos_creados" => 0,
                 "alumnos_reutilizados" => con_historial.count, "inscripciones" => con_historial.count,
                 "anos" => [ SEMILLA[:historico].name ], "fallidas" => [] } }
].each_with_index do |datos, n|
  importacion = Importacion.find_or_initialize_by(school: bolivar, nombre_del_archivo: datos[:nombre_del_archivo])
  importacion.assign_attributes(datos.merge(subido_por: secretaria, estado: :confirmada,
                                            academic_period: (datos[:tipo] == :historial ? nil : anterior),
                                            created_at: cuando_llego + n.days, updated_at: cuando_llego + n.days))
  importacion.save!
end
puts "   ✓ #{Importacion.count} importaciones: áreas y profesores · matrícula · notas anteriores"

# ── La bitácora ──────────────────────────────────────────────────────────────
#
# «¿Quién le cambió esa nota?», «¿por qué mi hijo quedó en 2do Año B?». La
# bitácora contesta eso, y un colegio con un año de uso la tiene llena.
#
# ⚠️ Se escribe UN hecho por cosa que pasó, no una fila por alumno: la promoción
# de trescientos es una línea, con quién la corrió y qué dio.
paso "🧾 Bitácora"

def anotar!(colegio, quien:, accion:, mensaje:, hace_dias: 0, cuando: nil, hora: 10, metadata: {})
  momento = cuando || (HOY - hace_dias).in_time_zone.change(hour: hora)
  ActivityLog.create!(user: quien, school: colegio, action: accion, message: mensaje, metadata: metadata,
                      ip_address: "190.202.#{(hace_dias * 7) % 250}.#{(hora * 11) % 250}",
                      created_at: momento, updated_at: momento)
end

Current.school = bolivar
coordinadora = SEMILLA[:coordinadora_bolivar]
garcia = User.find_by!(email: CORREO_DEL_PROFESOR)
promocion = SEMILLA[:promocion]
inicio = en_curso.start_date

anotar!(bolivar, quien: secretaria, accion: "pensum_importada", cuando: cuando_llego,
        mensaje: "#{secretaria.nombre_completo} importó las áreas y los profesores: 26 áreas, 23 docentes")
anotar!(bolivar, quien: secretaria, accion: "matricula_importada", cuando: cuando_llego + 1.day,
        mensaje: "#{secretaria.nombre_completo} importó la matrícula de #{anterior.name}: 360 alumnos")

lapsos_de(anterior).each do |lapso|
  anotar!(bolivar, quien: coordinadora, accion: "lapso_cerrado", cuando: a_las_diez(dia_habil(lapso.ends_on + 3)),
          mensaje: "#{coordinadora.nombre_completo} cerró #{lapso.name} de #{anterior.name}: " \
                   "#{SEMILLA[:secciones_bolivar].count { |s, _| !s.grade.califica_con_texto? }} secciones, con sus boletines liberados")
end

anotar!(bolivar, quien: director, accion: "period_created", cuando: a_las_diez(inicio - 30),
        mensaje: "#{director.nombre_completo} creó el año escolar #{en_curso.name}")
anotar!(bolivar, quien: director, accion: "estructura_copiada", cuando: a_las_diez(inicio - 29),
        mensaje: "#{director.nombre_completo} copió la estructura de #{anterior.name} a #{en_curso.name}: " \
                 "las secciones y quién dicta qué")
if promocion
  cuenta = promocion[:cuenta]
  anotar!(bolivar, quien: director, accion: "alumnos_promovidos", cuando: a_las_diez(inicio - 28),
          mensaje: "#{director.nombre_completo} promovió a los alumnos de #{anterior.name} a #{en_curso.name}: " \
                   "#{cuenta[:promueve].to_i + cuenta[:sin_datos].to_i} pasan, #{cuenta[:repite].to_i} repiten, " \
                   "#{cuenta[:egresa].to_i} egresan",
          metadata: { desde: anterior.name, hasta: en_curso.name, sin_datos: "pasar a todos" })
end

anotar!(bolivar, quien: secretaria, accion: "constancia_emitida", hace_dias: 2, hora: 11,
        mensaje: "#{secretaria.nombre_completo} emitió #{constancias.size} constancias de estudio")
anotar!(bolivar, quien: finanzas, accion: "reporte_updated", hace_dias: 2, hora: 15,
        mensaje: "#{finanzas.nombre_completo} revisó los pagos reportados: #{validados} validados, #{rechazados} rechazados")
anotar!(bolivar, quien: secretaria, accion: "mensaje_enviado", hace_dias: 4, hora: 9,
        mensaje: "#{secretaria.nombre_completo} le escribió a #{andreina&.nombre_completo}: «Falta el justificativo de Camila»")
anotar!(bolivar, quien: finanzas, accion: "suscripcion_pago_reportado", hace_dias: 22, hora: 9,
        mensaje: "#{finanzas.nombre_completo} reportó el pago de la suscripción")
anotar!(bolivar, quien: equipo || director, accion: "suscripcion_pago_validado", hace_dias: 22, hora: 16,
        mensaje: "SIGA validó el pago de la suscripción: activa hasta el #{I18n.l(hasta, format: :long)}")
anotar!(bolivar, quien: garcia, accion: "login", hace_dias: 1, hora: 7,
        mensaje: "#{garcia.nombre_completo} inició sesión")
anotar!(bolivar, quien: director, accion: "login", hace_dias: 1, hora: 8,
        mensaje: "#{director.nombre_completo} inició sesión")

puts "   ✓ #{ActivityLog.count} hechos en la bitácora de Bolívar, desde que llegó a SIGA"

# ── El pipeline comercial ────────────────────────────────────────────────────
#
# El panel de SIGA sin solicitudes es una tabla vacía, y es la primera pantalla
# que se mira para saber si el negocio se mueve. Los sistemas que declaran son
# los reales del mercado (`§ Contexto de mercado`).
paso "📬 Solicitudes de demostración"

SOLICITUDES = [
  { name: "Yajaira Colmenares", institution: "U.E. Colegio Santa Rosa de Lima",
    email: "direccion@santarosa.edu.ve", phone: "0212-9871122",
    current_system: :escritorio, current_system_detail: "SAE",
    status: :contactado, veces: 2,
    message: "Tenemos el sistema de escritorio desde 2011. Los representantes piden ver las notas por internet." },
  { name: "Régulo Marcano", institution: "Colegio Nuestra Señora del Carmen",
    email: "regulo.marcano@carmen.edu.ve", phone: "0414-5567788",
    current_system: :planillas, status: :pendiente, veces: 1,
    message: "Somos 180 alumnos, de preescolar a sexto grado. Todo lo llevamos en Excel." },
  { name: "Ninoska Bastidas", institution: "U.E. Instituto Andrés Eloy Blanco",
    email: "ninoska@aeblanco.edu.ve", phone: "0424-3345566",
    current_system: :otro, current_system_detail: "Un sistema que nos hizo un profesor",
    status: :demo_programado, veces: 3,
    message: "El que nos lo hizo se fue del país y nadie le puede meter mano." },
  { name: "Tomás Villalba", institution: "Colegio Fe y Alegría La Vega",
    email: "tvillalba@feyalegria.org.ve", phone: "0212-4432211",
    current_system: :ninguno, status: :completado, veces: 1,
    message: "Somos red, nos interesa ver los tres planteles juntos." },
  { name: "Alicia Nieves", institution: "U.E.P. Monseñor Pellín",
    email: "anieves@pellin.edu.ve", phone: "0416-2234455",
    current_system: :portal_web, current_system_detail: "Educasis",
    status: :rechazado, veces: 1,
    message: "Renovamos con nuestro proveedor este año." }
].freeze

Current.sin_aislamiento do
  SOLICITUDES.each do |datos|
    DemoRequest.find_or_create_by!(email: datos[:email]) do |d|
      d.assign_attributes(datos.except(:email))
    end
  end
end
puts "   ✓ #{Current.sin_aislamiento { DemoRequest.unscoped.count }} solicitudes, " \
     "en los cinco estados del pipeline"
