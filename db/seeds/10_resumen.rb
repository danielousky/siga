# Qué quedó sembrado, y con qué se entra (MOR-224).
#
# El resumen no es adorno: es lo que se lee después de `bin/rails db:seed` para
# saber si la siembra salió bien, y de dónde salen las credenciales que se le
# pasan a un broker.
Current.school = SEMILLA[:bolivar]

def contar_todo
  Current.sin_aislamiento do
    { colegios: School.unscoped.count, anios: AcademicPeriod.unscoped.count,
      grados: Grade.unscoped.count, areas: Subject.unscoped.count,
      secciones: Section.unscoped.count, asignaciones: TeacherSection.unscoped.count,
      docentes: Teacher.unscoped.count, direccion: Admin.unscoped.count,
      alumnos: Student.unscoped.count, representantes: Representative.unscoped.count,
      inscripciones: Enrollment.unscoped.count,
      evaluaciones: EvaluationActivity.unscoped.count,
      notas: ActivityGrade.unscoped.count,
      lapsos_calculados: MomentGrade.unscoped.count,
      definitivas: FinalGradeBook.unscoped.count,
      competencias: Competency.unscoped.count,
      asistencia: Attendance.unscoped.count,
      boletines: ReportCard.unscoped.count, cierres: SectionClosure.unscoped.count,
      informes: Informe.unscoped.count, cuotas: Charge.unscoped.count,
      reportes: PaymentReport.unscoped.count, mensajes: Mensaje.unscoped.count,
      constancias: Constancia.unscoped.count, bitacora: ActivityLog.unscoped.count }
  end
end

n = contar_todo

puts ""
puts "=" * 68
puts "✅ Siembra completa"
puts "=" * 68
puts ""
printf("   %-22s %6d      %-22s %6d\n", "Colegios",       n[:colegios],      "Años escolares", n[:anios])
printf("   %-22s %6d      %-22s %6d\n", "Grados",         n[:grados],        "Áreas",          n[:areas])
printf("   %-22s %6d      %-22s %6d\n", "Secciones",      n[:secciones],     "Asignaciones",   n[:asignaciones])
printf("   %-22s %6d      %-22s %6d\n", "Docentes",       n[:docentes],      "Dirección",      n[:direccion])
printf("   %-22s %6d      %-22s %6d\n", "Alumnos",        n[:alumnos],       "Representantes", n[:representantes])
printf("   %-22s %6d      %-22s %6d\n", "Inscripciones",  n[:inscripciones], "Asistencia",     n[:asistencia])
printf("   %-22s %6d      %-22s %6d\n", "Evaluaciones",   n[:evaluaciones],  "Notas",          n[:notas])
printf("   %-22s %6d      %-22s %6d\n", "Notas de lapso", n[:lapsos_calculados], "Definitivas", n[:definitivas])
printf("   %-22s %6d      %-22s %6d\n", "Competencias",   n[:competencias],  "Informes",       n[:informes])
printf("   %-22s %6d      %-22s %6d\n", "Boletines",      n[:boletines],     "Lapsos cerrados", n[:cierres])
printf("   %-22s %6d      %-22s %6d\n", "Cuotas",         n[:cuotas],        "Reportes de pago", n[:reportes])
printf("   %-22s %6d      %-22s %6d\n", "Mensajes",       n[:mensajes],      "Constancias",    n[:constancias])
printf("   %-22s %6d\n", "Bitácora", n[:bitacora])

puts ""
puts "   U.E. SIMÓN BOLÍVAR — los tres niveles y la Media Técnica"
# ⚠️ El año escolar va EXPLÍCITO en la consulta, no por `del_anio_de_la_sesion`.
#
# La siembra no es una petición: nadie fijó `Current.academic_period`, así que
# el scope no filtra nada y contaba también las inscripciones del año pasado —
# el resumen sumaba 666 alumnos de un colegio de 360. La primera vez que se ve,
# parece que la siembra duplicó todo.
Current.school = SEMILLA[:bolivar]
en_curso = SEMILLA[:en_curso]

SEMILLA[:bolivar].grades.en_orden.group_by { |g| GradoOficial.se_elige_como(g.level) }.each do |nivel, grados|
  alumnos = Enrollment.joins(section: :grade)
                      .where(sections: { academic_period_id: en_curso.id })
                      .where(grades: { id: grados.map(&:id) }).count
  puts "     #{GradoOficial::ETIQUETAS[nivel].ljust(14)} #{grados.size} grados · #{alumnos} alumnos"
end
puts "     #{'TOTAL'.ljust(14)} #{Enrollment.joins(:section).where(sections: { academic_period_id: en_curso.id }).count} inscripciones en #{en_curso.name}"

puts ""
puts "🔑 Credenciales — contraseña universal: #{CLAVE_DE_PRUEBA}"
puts ""
puts "   ⚠️  Las tres puertas de la muestra (`Muestra::CUENTAS`):"
puts "   #{CORREO_DEL_DIRECTOR.ljust(32)} director · el colegio completo"
puts "   #{CORREO_DEL_PROFESOR.ljust(32)} Matemática en PRIMARIA y en MEDIA"
puts "   #{CORREO_DE_LA_REPRESENTANTE.ljust(32)} representante · tres hijos, uno por nivel"
puts ""
puts "   maria.perez@familia.test      representante con hijos en LOS DOS colegios"
puts "   alvaro.lopez001@bolivar.edu   alumno de 1er Año A"
puts ""
puts "   #{CORREO_DESARROLLADOR.ljust(29)} equipo de SIGA · /siga (sin colegio)" \
     "#{' · en la muestra, con otra clave' if Muestra.activa?}"
puts "   coord.bolivar@siga.edu        coordinación"
puts "   secretaria.bolivar@siga.edu   secretaría"
puts "   finanzas.bolivar@siga.edu     finanzas"
puts "   director.bello@siga.edu       el segundo colegio, con la suscripción VENCIDA"
puts ""
puts "   carmen.lopez@familia.test     una hija"
puts "   jose.ramos@familia.test       dos hijos, grados distintos"
puts "   Yolanda Guerra (Bello)        SIN correo: existe, sale en el listado y no entra"
puts ""
puts "   Para probar /verificar sin entrar:"
puts "   #{SEMILLA[:constancias]&.first&.code || '—'}   una constancia de estudios"
puts "   #{Current.sin_aislamiento { ReportCard.unscoped.liberados.order(:id).first&.code } || '—'}   un boletín"
puts ""
puts "   Docentes de primaria, para ver el plan por COMPETENCIAS:"
puts "   maestra.torres@bolivar.edu · maestra.silva@bolivar.edu · #{CORREO_DEL_PROFESOR}"
puts ""
