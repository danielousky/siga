# Asistencia, suscripciones y lo que deja el uso diario (MOR-224).
paso "🗓️  Asistencia"

# ⚠️ Los días se cuentan hacia atrás desde el FINAL DEL LAPSO, no desde hoy.
#
# Contándolos desde hoy caían fuera del año escolar —en agosto, entre un año y
# el siguiente— y el boletín del primer lapso mostraba cero inasistencias con
# once registros cargados. El dato existía y no se veía, que es la peor de las
# dos maneras de que algo esté mal.
def dias_habiles_hasta(fecha, cuantos: 10)
  ultimo = [ fecha, Date.current ].min
  (0..(cuantos * 2)).map { |d| ultimo - d }
                    .reject { |f| f.saturday? || f.sunday? }
                    .first(cuantos).reverse
end

# Los patrones están elegidos para que el reporte muestre casos distintos y no
# una lista plana:
#
#   · el 1 no falta nunca
#   · el 2 acumula cuatro faltas SIN justificar   → el caso que dispara la llamada
#   · el 3 falta dos veces y las dos JUSTIFICADAS → no debe salir en el reporte
#   · el 4 llega tarde seguido, que no es lo mismo que faltar
FALTAS = { 1 => [ 1, 3, 5, 8 ], 2 => [ 2, 6 ] }.freeze
TARDES = { 3 => [ 1, 2, 4, 7, 9 ] }.freeze

bolivar = SEMILLA[:bolivar]
Current.school = bolivar

lapso_uno = EvaluationMoment.where(academic_period: SEMILLA[:anio_bolivar]).order(:starts_on, :id).first
dias = dias_habiles_hasta(lapso_uno&.ends_on || Date.current)

quien_registra = User.find_by(email: "prof.garcia@bolivar.edu")
quien_justifica = User.find_by(email: "director.bolivar@siga.edu")

# ⚠️ García es guía de «1er Año A» a la fuerza: es la credencial que sale en el
# README, y quien entre con ella tiene que ver la pantalla CON datos, no un
# «sin secciones a cargo».
un_ano_a = Section.joins(:grade).find_by(grades: { name: "1er Año" }, sections: { name: "A" })
un_ano_a&.update!(leader_teacher: Teacher.find_by(user: quien_registra))

# Tres secciones con historia, no una: el reporte de inasistencias se lee por
# colegio, y con una sola sección cargada no se puede ver si agrupa bien.
registros = 0
[ [ "1er Año", "A" ], [ "4to Grado", "A" ], [ "6to Año", "A" ] ].each do |grado, ident|
  seccion = Section.joins(:grade).find_by(grades: { name: grado }, sections: { name: ident })
  next if seccion.nil?

  inscripciones = Enrollment.where(section: seccion).order(:id).to_a

  dias.each_with_index do |dia, di|
    inscripciones.each_with_index do |inscripcion, ai|
      estado = if FALTAS[ai]&.include?(di) then :ausente
               elsif TARDES[ai]&.include?(di) then :tarde
               else :presente
               end

      registro = Attendance.find_or_initialize_by(enrollment: inscripcion, date: dia)
      registro.status = estado
      registro.recorded_by = seccion.leader_teacher&.user || quien_registra

      # El alumno 2 sí trajo el justificativo: la secretaría lo cargó al día
      # siguiente. Sirve para ver que el reporte NO lo cuenta.
      if ai == 2 && estado == :ausente
        registro.justificacion   = "Reposo médico presentado por el representante"
        registro.justificada_en  = dia + 1
        registro.justificada_por = quien_justifica
      end

      registro.save!
      registros += 1
    end
  end
end

sin_justificar = Current.sin_aislamiento { Attendance.unscoped.sin_justificar.count }
puts "   ✓ #{registros} registros en #{dias.size} días hábiles, en tres secciones"
puts "     #{sin_justificar} faltas sin justificar · " \
     "#{Current.sin_aislamiento { Attendance.unscoped.where(status: :tarde).count }} tardanzas"

# ── Suscripciones (MOR-108) ──────────────────────────────────────────────────
#
# Los dos colegios con estados distintos, para poder VER la degradación a solo
# lectura sin fabricarla a mano.
#
# ⚠️ Bello vencido es el caso que hay que poder mirar: entra, ve todo, descarga
# boletines y constancias, y no puede cargar una nota. Cortarle el acceso a
# mitad de año escolar sería quitarle las notas a sus alumnos, y la deuda es del
# colegio — el perjuicio no puede ser del alumno.
paso "💳 Suscripciones"

[
  { colegio: bolivar,          vence_en:  20, estado: :activa },
  { colegio: SEMILLA[:bello],  vence_en: -30, estado: :vencida }
].each do |datos|
  # ⚠️ `Subscription.matricula_de` NO puede pasar por el filtro de nivel: un
  # colegio de 360 alumnos con primaria elegida se facturaría como uno de 190.
  alumnos = Subscription.matricula_de(datos[:colegio].id)
  cotizacion = Subscription.cotizar(alumnos)
  suscripcion = Subscription.find_or_initialize_by(school: datos[:colegio])
  suscripcion.assign_attributes(
    # Por alumno, con el precio de hoy CONGELADO en la fila, como queda un
    # colegio al validarse su pago (spec `del-registro-al-cobro`).
    plan: :por_alumno,
    precio_por_alumno: cotizacion.por_alumno,
    minimo_mensual: cotizacion.minimo,
    matricula_facturada: alumnos,
    precio_mensual: cotizacion.monto,
    vigente_desde: Date.current - 1.month,
    vigente_hasta: Date.current + datos[:vence_en].days,
    status: datos[:estado],
    dias_de_gracia: 15
  )
  suscripcion.save!
end

Current.sin_aislamiento do
  Subscription.unscoped.includes(:school).each do |s|
    puts "   ✓ #{s.school.name.ljust(22)} #{s.etiqueta_de_plan.ljust(10)} " \
         "#{format('%.2f', s.precio_mensual).ljust(7)} $ #{s.matricula_facturada} alumnos · #{s.etiqueta_de_estado}"
  end
end
puts "     Bello está VENCIDO a propósito: entra y ve todo, pero no carga nada nuevo"

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
