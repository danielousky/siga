require "test_helper"

# Copiar el plan a las secciones hermanas (etapa ③).
#
# Daniel: *«él puede clonar o copiar esa planificación de esa sección… debería
# haber una opción de replicar a las otras secciones hermanas»*.
#
# ⚠️ Copiar competencias ya existía. Lo que faltaba —y es la mitad más pesada
# del trabajo de septiembre— son las EVALUACIONES: un profesor con tres
# secciones hermanas escribía las mismas cuatro doce veces.
class ReplicarLaPlanificacionTest < ActiveSupport::TestCase
  setup do
    @esc = escenario_academico(nivel: :primaria, alumnos: 2)
    @lapso = @esc.lapso(2)   # el 1 ya tiene una actividad de peso 100

    @origen, @destino = con_el_colegio(@esc.colegio) do
      hermana = Section.create!(grade: @esc.seccion.grade, academic_period: @esc.periodo,
                                name: "Z", capacity: 30)
      docente = Teacher.create!(user: User.create!(first_name: "Ana", last_name: "Prueba",
                                                   email: "ana.replica@test.edu", password: "123123",
                                                   document: "V-77000111", document_type: :cedula_v),
                                school: @esc.colegio)
      [ TeacherSection.create!(teacher: docente, section: @esc.seccion, subject: @esc.materia),
        TeacherSection.create!(teacher: docente, section: hermana, subject: @esc.materia) ]
    end
  end

  def replicar = con_el_colegio(@esc.colegio) do
    ReplicarLaPlanificacion.para(desde: @origen, hacia: @destino, lapso: @lapso)
  end

  def plan_del_destino = con_el_colegio(@esc.colegio) do
    Competency.del_plan(@destino.section_id, @destino.subject_id, @lapso.id).to_a
  end

  def evaluaciones_del_destino = con_el_colegio(@esc.colegio) do
    EvaluationActivity.where(section_id: @destino.section_id, subject_id: @destino.subject_id,
                             evaluation_moment_id: @lapso.id).includes(:competencies).to_a
  end

  # ── Lo que se copia ───────────────────────────────────────────────────────

  test "copia las competencias con sus indicadores" do
    con_el_colegio(@esc.colegio) do
      c = Competency.create!(section: @esc.seccion, subject: @esc.materia,
                             evaluation_moment: @lapso, descripcion: "Resuelve problemas")
      c.indicators.create!(descripcion: "Suma con reagrupación", orden: 0)
      c.indicators.create!(descripcion: "Estima el resultado", orden: 1)
    end

    assert_equal 1, replicar.competencias

    copiada = plan_del_destino.first
    assert_equal "Resuelve problemas", copiada.descripcion
    assert_equal [ "Suma con reagrupación", "Estima el resultado" ],
                 con_el_colegio(@esc.colegio) { copiada.indicators.en_orden.map(&:descripcion) }
  end

  test "copia las evaluaciones con su peso y su fecha" do
    con_el_colegio(@esc.colegio) do
      actividad(@esc, lapso: @lapso, peso: 40, descripcion: "Examen")
            .update!(date_scheduled: Date.new(2025, 11, 8))
      actividad(@esc, lapso: @lapso, peso: 30, descripcion: "Taller")
    end

    assert_equal 2, replicar.evaluaciones

    examen = evaluaciones_del_destino.find { |e| e.description == "Examen" }
    assert_equal 40, examen.weight_percentage
    assert_equal Date.new(2025, 11, 8), examen.date_scheduled
  end

  # ⚠️ LA PARTE DIFÍCIL: el enganche se RE-APUNTA a la competencia del DESTINO.
  #
  # Una evaluación copiada no puede seguir midiendo la del origen —esa es de
  # otra sección—. Sin esto, la copia deja las evaluaciones sin medir nada, y
  # una competencia que ninguna evaluación mide sale en la boleta SIN nivel.
  test "la evaluación copiada mide la competencia del DESTINO, no la del origen" do
    original = con_el_colegio(@esc.colegio) do
      c = Competency.create!(section: @esc.seccion, subject: @esc.materia,
                             evaluation_moment: @lapso, descripcion: "Resuelve problemas")
      actividad(@esc, lapso: @lapso, peso: 40, descripcion: "Examen", mide: c)
      c
    end

    replicar

    copiada = evaluaciones_del_destino.find { |e| e.description == "Examen" }
    medidas = con_el_colegio(@esc.colegio) { copiada.competencies.to_a }

    assert_equal 1, medidas.size
    assert_not_equal original.id, medidas.first.id, "quedó apuntando a la competencia del origen"
    assert_equal @destino.section_id, medidas.first.section_id
    assert_equal "Resuelve problemas", medidas.first.descripcion
  end

  # ── Lo que NO se copia ────────────────────────────────────────────────────

  test "las notas no se copian: son de los alumnos de esa sección" do
    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @lapso, peso: 40, descripcion: "Examen")
      Enrollment.where(section: @esc.seccion, status: :regular).each { |i| nota(examen, i.student, 15) }
    end

    replicar

    copiada = evaluaciones_del_destino.first
    assert_equal 0, con_el_colegio(@esc.colegio) { copiada.activity_grades.count }
  end

  # ── Idempotencia ──────────────────────────────────────────────────────────

  test "correrlo dos veces no duplica nada" do
    con_el_colegio(@esc.colegio) do
      Competency.create!(section: @esc.seccion, subject: @esc.materia,
                         evaluation_moment: @lapso, descripcion: "Resuelve problemas")
      actividad(@esc, lapso: @lapso, peso: 40, descripcion: "Examen")
    end

    replicar
    segunda = replicar

    assert_equal 0, segunda.competencias
    assert_equal 0, segunda.evaluaciones
    assert_equal 1, plan_del_destino.size
    assert_equal 1, evaluaciones_del_destino.size
  end

  # ── ERROR vs AVISO ────────────────────────────────────────────────────────
  #
  # ⚠️ Acá NADA es error. Si el destino ya tiene su 100 % repartido, la
  # evaluación que viene no cabe: se salta, se dice, y las otras se copian.
  # Abortar la copia entera dejaría al profesor sin las que sí cabían.
  test "lo que no cabe por ponderación se salta, se avisa, y el resto se copia" do
    con_el_colegio(@esc.colegio) do
      actividad(@esc, lapso: @lapso, peso: 60, descripcion: "Examen")
      actividad(@esc, lapso: @lapso, peso: 30, descripcion: "Taller")
      # El destino ya tiene el 70 % comprometido: el Examen del 60 no entra,
      # pero el Taller del 30 cierra justo en 100.
      #
      # ⚠️ Lo suyo también mide algo: es primaria, y desde `MOR-136` una
      # evaluación sin competencia ni indicador no se guarda.
      suya = Competency.create!(section_id: @destino.section_id, subject_id: @destino.subject_id,
                                evaluation_moment: @lapso, descripcion: "Lo que ya tenía")
      suya.indicators.create!(descripcion: "Su indicador", orden: 0)
      lo_suyo = EvaluationActivity.new(section_id: @destino.section_id, subject_id: @destino.subject_id,
                                       evaluation_moment: @lapso, description: "Lo suyo",
                                       weight_percentage: 70, date_scheduled: Date.new(2025, 10, 1))
      lo_suyo.competency_ids = [ suya.id ]
      lo_suyo.indicators     = suya.indicators.to_a
      lo_suyo.save!
    end

    resultado = replicar

    assert_equal 1, resultado.evaluaciones, "el Taller del 30 sí cabía"
    assert_equal 1, resultado.avisos.size
    assert_match(/Examen/, resultado.avisos.first)
    assert_includes evaluaciones_del_destino.map(&:description), "Taller"
  end

  # ── La otra puerta: traer el plan del año pasado ──────────────────────────
  #
  # ⚠️ Acá SÍ vienen las evaluaciones, con la fecha corrida un año.
  #
  # La primera versión traía solo las competencias, con el argumento de que las
  # fechas del año pasado son de otro calendario. Daniel lo corrigió: la fecha
  # no es un obstáculo, es una traducción —mismo día y mes, el año que
  # corresponde—. Y es literalmente lo que pedía Cyndi.
  # ⚠️ «Todo» solo si lo dictaba EL MISMO profesor (`con_evaluaciones: true`).
  # Quién lo decide es el controller; acá se prueba que el servicio obedezca.
  test "del año pasado del mismo profesor viene todo, con la fecha corrida un año" do
    anterior, lapso_anterior = con_el_colegio(@esc.colegio) do
      periodo = AcademicPeriod.create!(name: "2024-2025", start_date: Date.new(2024, 9, 1),
                                       end_date: Date.new(2025, 7, 31))
      lapso = EvaluationMoment.create!(academic_period: periodo, name: "2do Lapso",
                                       starts_on: Date.new(2024, 11, 1), ends_on: Date.new(2025, 2, 28))
      seccion = Section.create!(grade: @esc.seccion.grade, academic_period: periodo,
                                name: "A", capacity: 30)
      c = Competency.create!(section: seccion, subject: @esc.materia,
                             evaluation_moment: lapso, descripcion: "Resuelve problemas")
      c.indicators.create!(descripcion: "Suma con reagrupación", orden: 0)
      e = EvaluationActivity.new(section: seccion, subject: @esc.materia,
                                 evaluation_moment: lapso, description: "Examen",
                                 weight_percentage: 40, date_scheduled: Date.new(2024, 11, 8))
      e.competency_ids = [ c.id ]
      e.indicators     = c.indicators.to_a
      e.save!
      [ Struct.new(:section_id, :subject_id).new(seccion.id, @esc.materia.id), lapso ]
    end

    hecho = con_el_colegio(@esc.colegio) do
      ReplicarLaPlanificacion.del_ano_pasado(desde: anterior, lapso_de_origen: lapso_anterior,
                                             hacia: @destino, lapso: @lapso,
                                             con_evaluaciones: true)
    end

    assert_equal 1, hecho.competencias
    assert_equal 1, hecho.evaluaciones, "las evaluaciones del año pasado también se traen"

    copiada = evaluaciones_del_destino.first
    assert_equal 40, copiada.weight_percentage

    # ⚠️ Mismo día y mes, el año del lapso destino: 8 de noviembre de 2024 →
    # 8 de noviembre de 2025.
    assert_equal Date.new(2025, 11, 8), copiada.date_scheduled

    # Y su enganche apunta a la competencia recién creada acá, no a la vieja.
    medidas = con_el_colegio(@esc.colegio) { copiada.competencies.to_a }
    assert_equal 1, medidas.size
    assert_equal @destino.section_id, medidas.first.section_id
  end

  # ⚠️ Y de OTRO profesor vienen solo las competencias con sus indicadores.
  #
  # Daniel, 17 de septiembre: *«las evaluaciones no. Esas deben ser agregadas
  # nuevas, a menos que sea el mismo profe»*. Una evaluación es una decisión
  # pedagógica de quien evalúa —el peso, la fecha, qué mide— y heredarla de otro
  # le pone al profesor nuevo un criterio ajeno que además no va a revisar,
  # porque vino puesto. La competencia sí: describe qué enseña el grado.
  test "del año pasado de OTRO profesor vienen solo las competencias" do
    anterior, lapso_anterior = con_el_colegio(@esc.colegio) do
      periodo = AcademicPeriod.create!(name: "2024-2025", start_date: Date.new(2024, 9, 1),
                                       end_date: Date.new(2025, 7, 31))
      lapso = EvaluationMoment.create!(academic_period: periodo, name: "2do Lapso")
      seccion = Section.create!(grade: @esc.seccion.grade, academic_period: periodo,
                                name: "A", capacity: 30)
      c = Competency.create!(section: seccion, subject: @esc.materia,
                             evaluation_moment: lapso, descripcion: "Resuelve problemas")
      c.indicators.create!(descripcion: "Suma con reagrupación", orden: 0)
      e = EvaluationActivity.new(section: seccion, subject: @esc.materia,
                                 evaluation_moment: lapso, description: "Examen de la otra",
                                 weight_percentage: 40, date_scheduled: Date.new(2024, 11, 8))
      e.competency_ids = [ c.id ]
      e.indicators     = c.indicators.to_a
      e.save!
      [ Struct.new(:section_id, :subject_id).new(seccion.id, @esc.materia.id), lapso ]
    end

    hecho = con_el_colegio(@esc.colegio) do
      ReplicarLaPlanificacion.del_ano_pasado(desde: anterior, lapso_de_origen: lapso_anterior,
                                             hacia: @destino, lapso: @lapso)
    end

    assert_equal 1, hecho.competencias, "las competencias sí se heredan: describen qué enseña el grado"
    assert_equal 0, hecho.evaluaciones
    assert_empty evaluaciones_del_destino,
                 "el peso y la fecha del examen de otro profesor no son un plan que heredar"

    # Y el indicador llegó igual, LIBRE: la profesora nueva decide qué evaluación
    # lo mide.
    con_el_colegio(@esc.colegio) do
      copiada = Competency.del_plan(@destino.section_id, @destino.subject_id, @lapso.id).first
      assert_equal [ "Suma con reagrupación" ], copiada.indicators.map(&:descripcion)
      assert_equal 1, copiada.indicators.libres.count
    end
  end

  # ⚠️ Los indicadores también viajan: son la mitad de lo que Cyndi no quería
  # volver a escribir.
  test "del año pasado vienen los indicadores" do
    anterior, lapso_anterior = con_el_colegio(@esc.colegio) do
      periodo = AcademicPeriod.create!(name: "2024-2025", start_date: Date.new(2024, 9, 1),
                                       end_date: Date.new(2025, 7, 31))
      lapso = EvaluationMoment.create!(academic_period: periodo, name: "2do Lapso",
                                       starts_on: Date.new(2024, 11, 1), ends_on: Date.new(2025, 2, 28))
      seccion = Section.create!(grade: @esc.seccion.grade, academic_period: periodo,
                                name: "A", capacity: 30)
      c = Competency.create!(section: seccion, subject: @esc.materia,
                             evaluation_moment: lapso, descripcion: "Resuelve problemas")
      c.indicators.create!(descripcion: "Suma con reagrupación", orden: 0)
      c.indicators.create!(descripcion: "Estima el resultado", orden: 1)
      [ Struct.new(:section_id, :subject_id).new(seccion.id, @esc.materia.id), lapso ]
    end

    con_el_colegio(@esc.colegio) do
      ReplicarLaPlanificacion.del_ano_pasado(desde: anterior, lapso_de_origen: lapso_anterior,
                                             hacia: @destino, lapso: @lapso)
    end

    copiada = plan_del_destino.first
    assert_equal [ "Suma con reagrupación", "Estima el resultado" ],
                 con_el_colegio(@esc.colegio) { copiada.indicators.en_orden.map(&:descripcion) }
  end
end
