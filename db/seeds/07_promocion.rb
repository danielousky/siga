# De un año al siguiente: el historial, la estructura copiada, la promoción y
# los que entran nuevos.
#
# Es septiembre, hecho con las mismas tres herramientas que usa el colegio:
#
#     1 · CopiarLaEstructura     las secciones y quién dicta qué      (MOR-166)
#     2 · el director ajusta     abre y cierra secciones según las cohortes
#     3 · PromocionDeAlumnos     cada quien a su grado, según sus notas (MOR-169)
#     4 · el nuevo ingreso       los que llegan este año
#
# ⚠️ El año en curso NO está escrito en ninguna tabla: es lo que SALE de esto.
# Quién repite lo deciden sus notas del año anterior, no una lista.

# ── El historial: importado del sistema viejo ────────────────────────────────
#
# Todo alumno que no está en su primer grado viene de algún lado. Sin historial,
# la ficha de un alumno de 5to Año arranca en blanco y la certificación de
# calificaciones no tiene con qué llenarse.
#
# ⚠️ Va con `origen: :importada`, y eso NO es una etiqueta cosmética: es lo que
# impide que `GradeCalculator` borre estas notas. Un libro importado no tiene
# actividades debajo —las evaluaciones que produjeron ese 15 están en papel— y
# la regla de borrar lo que quedó sin respaldo se las llevaría.
#
# Es además el caso REAL de un colegio nuevo en SIGA: trae su historial y sigue
# desde ahí.
paso "📚 Historial importado"

bolivar   = SEMILLA[:bolivar]
historico = SEMILLA[:historico]
anterior  = SEMILLA[:anterior]
en_curso  = SEMILLA[:en_curso]
Current.school = bolivar

libros = []
ahora = Time.current
inscripciones_viejas = 0

SEMILLA[:secciones_bolivar].each do |seccion, _|
  grado = seccion.grade
  next if grado.califica_con_texto?                   # inicial describe, no califica

  orden_anterior = (GradoOficial.orden_de(grado.name) || 1) - 1
  entrada = GradoOficial::CATALOGO.find { |e| e.orden == orden_anterior }
  next if entrada.nil?

  grado_anterior = bolivar.grades.find_by(name: entrada.nombre)
  next if grado_anterior.nil? || grado_anterior.califica_con_texto?

  vieja = Section.find_or_create_by!(name: seccion.name, grade: grado_anterior,
                                     academic_period: historico) { |s| s.capacity = seccion.capacity }
  areas = grado_anterior.subjects.order(:code).to_a

  lista_de(seccion).each do |inscripcion, _|
    alumno = inscripcion.student
    de_antes = Enrollment.find_or_create_by!(student: alumno, section: vieja) do |e|
      e.enrollment_date = dia_de_inscripcion(historico)
      e.status = :regular
      e.created_at = e.updated_at = a_las_diez(dia_de_inscripcion(historico))
    end
    inscripciones_viejas += 1

    areas.each_with_index do |materia, mi|
      # Todos aprobaron: por eso están en el grado siguiente.
      nota = nota_de(numero_de(alumno), materia.code, 9, mi, base: SEMILLA[:bases][alumno.id]).clamp(10, 20)
      libros << { enrollment_id: de_antes.id, subject_id: materia.id, school_id: bolivar.id,
                  annual_average: nota, final_score: nota,
                  origen: FinalGradeBook.origens[:importada], created_at: ahora, updated_at: ahora }
    end
  end
end

FinalGradeBook.insert_all(libros, unique_by: %i[enrollment_id subject_id]) if libros.any?
puts "   ✓ #{inscripciones_viejas} inscripciones en #{historico.name} · #{libros.size} notas definitivas importadas"

# ── 1 · La estructura, copiada ───────────────────────────────────────────────
paso "🗂️  #{en_curso.name}: la estructura copiada"

copia = CopiarLaEstructura.de(anterior, al: en_curso)
puts "   ✓ #{copia.total_secciones} secciones y #{copia.asignaciones} asignaciones, copiadas de #{anterior.name}"

# ── 2 · El director ajusta ───────────────────────────────────────────────────
#
# Copiar deja las secciones del año pasado, pero los ALUMNOS suben de grado: el
# 2do Grado que venía en dos secciones es ahora un 3er Grado de cuarenta y dos,
# y en la copia 3er Grado tiene una sola. Es la cuenta que un director hace en
# la reunión de septiembre:
#
#     SE ABREN    3er Grado B · 5to Grado B · 2do Año B    las cohortes que venían en dos
#     SE CIERRA   4to Grado B                              su cohorte venía en una sola
#
# «1er Grado B» y «1er Año B» se quedan: las llena el nuevo ingreso, que es por
# donde más gente entra a un colegio.
SE_ABREN  = [ [ "3er Grado", "B" ], [ "5to Grado", "B" ], [ "2do Año", "B" ] ].freeze
SE_CIERRA = [ [ "4to Grado", "B" ] ].freeze

abiertas = SE_ABREN.filter_map do |grado, nombre|
  modelo = seccion_de(bolivar, grado, "A", en_curso)
  next if modelo.nil?

  Section.find_or_create_by!(name: nombre, grade: modelo.grade, academic_period: en_curso) do |s|
    s.capacity  = modelo.capacity
    s.classroom = AULA.call(modelo.grade, nombre)
  end
end

asignar_docentes!(bolivar, abiertas.map { |s| [ s, 0 ] }, SEMILLA[:docentes_bolivar])
asignar_guias!(bolivar, abiertas.map { |s| [ s, 0 ] })

SE_CIERRA.each do |grado, nombre|
  sobra = seccion_de(bolivar, grado, nombre, en_curso)
  next if sobra.nil?

  TeacherSection.where(section: sobra).destroy_all
  sobra.destroy!
end

puts "   ✓ se abren #{SE_ABREN.map { |g, n| "#{g} #{n}" }.join(' · ')}; " \
     "se cierra #{SE_CIERRA.map { |g, n| "#{g} #{n}" }.join(' · ')}"

# ── 3 · La promoción ─────────────────────────────────────────────────────────
#
# ⚠️ `promover_sin_datos: true` es por Inicial: no lleva notas definitivas, así
# que para la promoción son «sin datos». Es la decisión que el director toma con
# un clic —«Pasar a todos al siguiente grado»— y queda registrada como suya.
paso "🎓 Promoción a #{en_curso.name}"

Current.school = bolivar
promocion = PromocionDeAlumnos.new(anterior, en_curso, promover_sin_datos: true)
cuenta    = promocion.conteo
resultado = promocion.aplicar

SEMILLA[:promocion] = { cuenta: cuenta, resultado: resultado }

# Se inscribieron en septiembre, no el día en que corre la siembra.
se_inscribieron = dia_de_inscripcion(en_curso)
Enrollment.where(section_id: Section.where(academic_period_id: en_curso.id).select(:id))
          .update_all(enrollment_date: se_inscribieron, created_at: a_las_diez(se_inscribieron),
                      updated_at: a_las_diez(se_inscribieron))

puts "   ✓ #{resultado.inscritos} inscritos en #{en_curso.name}: " \
     "#{cuenta[:promueve].to_i + cuenta[:sin_datos].to_i} pasan de grado · #{cuenta[:repite].to_i} repiten · " \
     "#{cuenta[:egresa].to_i} egresan"
puts "     ⚠️  #{resultado.avisos.size} avisos: #{resultado.avisos.first(3).join(' · ')}" if resultado.avisos.any?

# ⚠️ La familia de la muestra tiene que haber PASADO: es la primera impresión de
# quien entra como representante, y un hijo repitiendo no es la que se quiere
# dar. Si un cambio en los perfiles la deja atrás, la siembra lo dice en vez de
# sembrar una muestra torcida.
HIJOS_DE_LA_MUESTRA.each do |grado, seccion, puesto|
  alumno = SEMILLA[:alumnos_bolivar].find { |s, _| s.grade.name == grado && s.name == seccion }&.last&.at(puesto)
  next if alumno.nil?

  hoy = Enrollment.joins(:section).find_by(student_id: alumno.id, sections: { academic_period_id: en_curso.id })
  antes = GradoOficial.orden_de(grado)
  ahora_en = hoy && GradoOficial.orden_de(hoy.section.grade.name)

  unless ahora_en == antes + 1
    abort "\n✗ #{alumno.user.nombre_completo}, de la familia de la muestra, no pasó de #{grado}: " \
          "quedó en #{hoy&.section&.grade&.name || 'ningún grado'}. Revisar PERFIL_FIJO."
  end
end

# ── 4 · El nuevo ingreso ─────────────────────────────────────────────────────
#
# Los que llegan este año. Entran sobre todo por las tres puertas de un colegio
# —el primer nivel de Inicial, el 1er Grado y el 1er Año— y alguno suelto a
# mitad del camino.
#
# ⚠️ No traen historial, y es el caso NORMAL: sus notas anteriores están en el
# colegio de donde vienen. Su ficha arranca en blanco y así tiene que verse.
paso "🆕 Nuevo ingreso"

NUEVO_INGRESO = {
  "1er Nivel" => { "U" => 16 },
  "2do Nivel" => { "U" => 2 },
  "1er Grado" => { "B" => 14 },
  "1er Año"   => { "B" => 13 },
  "4to Año"   => { "A" => 1 }
}.freeze

nuevas = a_escala(NUEVO_INGRESO).flat_map do |grado, secciones|
  secciones.filter_map do |nombre, cuantos|
    seccion = seccion_de(bolivar, grado, nombre, en_curso)
    [ seccion, cuantos ] if seccion
  end
end

# ⚠️ Arrancan en 500: la cédula escolar es única en todo el país, y los de la
# matrícula del año anterior ocupan del 1 al 360.
SEMILLA[:nuevos_bolivar] = sembrar_alumnos!(bolivar, nuevas, dominio: "bolivar.edu", desde: 500,
                                            periodo: en_curso, correos_desde: 500)
inscribir!(bolivar, SEMILLA[:nuevos_bolivar], periodo: en_curso, escalonada: true)
sembrar_representantes!(bolivar, SEMILLA[:nuevos_bolivar], dominio: "familia.test", desde: 500)

Current.school = bolivar
total = Enrollment.where(section_id: Section.where(academic_period_id: en_curso.id).select(:id), status: :regular).count
puts "   ✓ #{SEMILLA[:nuevos_bolivar].values.sum(&:size)} alumnos nuevos · #{total} inscritos en #{en_curso.name}"

# ── En vacaciones: el año que viene, armado y vacío ──────────────────────────
#
# Solo existe cuando el año en curso ya terminó (`SEMILLA[:siguiente]`, paso
# 01). Su estructura se copia DESPUÉS de calificar el año —paso 08—, porque es
# el estado desde el que se promueve: secciones listas y ni un alumno adentro.
