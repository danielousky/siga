# Los horarios de Media del año en curso (spec `horarios`, tanda 2).
#
#    el turno       el de la foto: de 7:10 a 1:00, horas de 40 minutos, receso a las 9:50
#    las secciones  armadas sin un choque (`ArmarElHorario`) y publicadas
#    1er Año B      en borrador y con 6 horas por ubicar, a propósito: es donde
#                   la dirección prueba armar, como en la maqueta
#
# ⚠️ La carga es la de la MUESTRA, no la del plan: el plan pide 44 a 46 horas y
# la semana tiene 40, y Herrera dicta dos áreas en siete secciones. Con la del
# plan, cada sección amanecería con horas que no caben —es un aviso cierto, pero
# no lo primero que debe ver quien prueba—. Se baja de dos en dos lo más
# grande hasta que cada grado quepa en 38 horas —el viernes sale antes, como en
# la foto— y ningún profesor pase de 38.
paso "🗓️  Horarios de Media"

bolivar  = SEMILLA[:bolivar]
en_curso = SEMILLA[:en_curso]
Current.school = bolivar

TOPE_DE_LA_SEMANA = 38

turno = TurnoDelAnio.asegurar!(en_curso)
media = Section.where(academic_period_id: en_curso.id).joins(:grade)
               .where(grades: { level: %w[secundaria media_tecnica] }).includes(:grade)
               .sort_by { |s| [ s.grade.orden.to_i, s.name ] }

pensum = GradeSubject.where(grade_id: media.map(&:grade_id).uniq).includes(:grade, :subject).to_a
pensum.each do |gs|
  gs.weekly_hours = CargaHorariaOficial.horas_para(gs.subject.name, gs.grade.name) || 2
end

bajar = lambda do |candidatas|
  gs = candidatas.select { |c| c.weekly_hours >= 4 }.max_by { |c| [ c.weekly_hours, c.subject.name ] }
  gs && (gs.weekly_hours -= 2)
end

pensum.group_by(&:grade_id).each_value do |del_grado|
  bajar.call(del_grado) while del_grado.sum(&:weekly_hours) > TOPE_DE_LA_SEMANA
end

asignaciones = TeacherSection.where(section_id: media.map(&:id)).includes(:section).to_a
carga_de = ->(a) { pensum.find { |gs| gs.grade_id == a.section.grade_id && gs.subject_id == a.subject_id } }
loop do
  por_profesor = asignaciones.group_by(&:teacher_id).transform_values { |as| as.sum { |a| carga_de.(a)&.weekly_hours.to_i } }
  pesado = por_profesor.select { |_, horas| horas > TOPE_DE_LA_SEMANA }.keys.first
  break unless pesado

  break unless bajar.call(asignaciones.select { |a| a.teacher_id == pesado }.filter_map { |a| carga_de.(a) }.uniq)
end
pensum.each(&:save!)

clases = ArmarElHorario.new(media, turno.reload).armar!

# 1er Año B: tres bloques vuelven a «por ubicar» —seis horas—, y queda en borrador.
borrador = media.find { |s| s.grade.name == "1er Año" && s.name == "B" }
if borrador
  Lesson.where(section: borrador).group_by(&:subject_id).values
        .select { |de_un_area| de_un_area.size >= 2 }.first(3)
        .each { |de_un_area| Lesson.where(id: de_un_area.sort_by { |c| [ c.day, c.starts_min ] }.first(2).map(&:id)).delete_all }
end
Section.where(id: media.map(&:id)).where.not(id: borrador&.id).update_all(timetable_published_at: Time.current)

completas = media.count { |s| CargaDeLaSeccion.new(s).faltan.zero? }
puts "   ✓ #{clases} clases en #{media.size} secciones de Media, #{completas} completas y publicadas; " \
     "#{borrador ? "1er Año B en borrador, con #{CargaDeLaSeccion.new(borrador).faltan} horas por ubicar" : 'sin 1er Año B'}"
