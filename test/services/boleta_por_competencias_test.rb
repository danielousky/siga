require "test_helper"

# La boleta con competencias, indicadores y rúbrica (MOR-136).
#
# Es para lo ÚNICO que existen las competencias. Daniel: *«las competencias
# terminan siendo solo para mostrarlas en la boleta junto con los indicadores y
# la rúbrica»*.
class BoletaPorCompetenciasTest < ActiveSupport::TestCase
  setup do
    @esc = escenario_academico(nivel: :primaria, alumnos: 2)
    @lapso = @esc.lapso(1)
  end

  # ⚠️ La promesa que hace toda la funcionalidad: cambiar la rúbrica cambia lo
  # que la boleta DICE, y no lo que el alumno SACÓ.
  test "la nota se guarda en número y se lee en nivel" do
    con_el_colegio(@esc.colegio) do
      @esc.colegio.restablecer_la_rubrica!
      actividad = actividad(@esc, lapso: @lapso, peso: 100)
      nota(actividad, @esc.alumno, 17)

      datos = ReportCardData.para(enrollment: @esc.inscripcion, evaluation_moment: @lapso)
      fila = datos["materias"].find { |m| m["materia"] == @esc.materia.name }

      assert_equal 17, fila["nota"], "por dentro sigue siendo un 17"
      assert_equal "PA", fila["nivel_de_rubrica"], "la familia lee PA"
    end
  end

  # ⚠️ Un colegio SIN rúbrica saca la boleta como hoy. No tener rúbrica no
  # rompe nada — es el estado de todos los colegios hasta que la definan.
  test "sin rúbrica la boleta muestra el número, como siempre" do
    con_el_colegio(@esc.colegio) do
      actividad = actividad(@esc, lapso: @lapso, peso: 100)
      nota(actividad, @esc.alumno, 17)

      datos = ReportCardData.para(enrollment: @esc.inscripcion, evaluation_moment: @lapso)
      fila = datos["materias"].find { |m| m["materia"] == @esc.materia.name }

      assert_equal 17, fila["nota"]
      assert_nil fila["nivel_de_rubrica"]
      assert_nil datos["rubrica"]
    end
  end

  test "las competencias salen con sus indicadores y su nivel" do
    con_el_colegio(@esc.colegio) do
      @esc.colegio.restablecer_la_rubrica!
      # ⚠️ La competencia va PRIMERO y la evaluación dice que la mide: desde
      # `MOR-136` una evaluación de primaria mide una competencia y un
      # indicador, y engancharla después ya no alcanza.
      competencia = Competency.create!(section: @esc.seccion, subject: @esc.materia,
                                       evaluation_moment: @lapso,
                                       descripcion: "Resuelve problemas de adición")
      competencia.indicators.create!(descripcion: "Suma con reagrupación", orden: 0)

      actividad = actividad(@esc, lapso: @lapso, peso: 100, mide: competencia)
      nota(actividad, @esc.alumno, 19)

      datos = ReportCardData.para(enrollment: @esc.inscripcion, evaluation_moment: @lapso)
      plan = datos["materias"].find { |m| m["materia"] == @esc.materia.name }["competencias"]

      assert_equal 1, plan.size
      assert_equal "Resuelve problemas de adición", plan.first["texto"]
      assert_equal "PC", plan.first["nivel_de_rubrica"]
      # ⚠️ Cada indicador con SU nivel: el de la evaluación que lo midió.
      assert_equal [ { "texto" => "Suma con reagrupación", "nivel_de_rubrica" => "PC" } ],
                   plan.first["indicadores"]
    end
  end

  # ⚠️ El nivel de un indicador es una LECTURA, no una cuenta.
  #
  # Un indicador lo mide una sola evaluación (`MOR-136`, segunda mitad), así que
  # su nivel es el de esa nota. Dos indicadores de la misma competencia, medidos
  # por evaluaciones distintas, salen con niveles distintos — y eso es lo que la
  # boleta no podía decir antes: imprimía los dos bajo el nivel de la
  # competencia, que es el ponderado de las dos.
  test "cada indicador sale con el nivel de la evaluación que lo midió" do
    con_el_colegio(@esc.colegio) do
      @esc.colegio.restablecer_la_rubrica!
      competencia = Competency.create!(section: @esc.seccion, subject: @esc.materia,
                                       evaluation_moment: @lapso, descripcion: "Con dos")
      bien  = competencia.indicators.create!(descripcion: "Lo que salió bien", orden: 0)
      flojo = competencia.indicators.create!(descripcion: "Lo que salió flojo", orden: 1)

      examen = actividad(@esc, lapso: @lapso, peso: 50, descripcion: "Examen", mide: competencia)
      taller = actividad(@esc, lapso: @lapso, peso: 50, descripcion: "Taller", mide: competencia)
      nota(examen, @esc.alumno, 19)
      nota(taller, @esc.alumno, 11)

      datos = ReportCardData.para(enrollment: @esc.inscripcion, evaluation_moment: @lapso)
      plan = datos["materias"].find { |m| m["materia"] == @esc.materia.name }["competencias"]
      suya = plan.find { |c| c["texto"] == "Con dos" }

      # ⚠️ El escenario reparte un indicador por evaluación, en orden.
      niveles = suya["indicadores"].to_h { |i| [ i["texto"], i["nivel_de_rubrica"] ] }
      assert_equal "PC", niveles[bien.reload.descripcion]
      assert_equal "PD", niveles[flojo.reload.descripcion]

      # Y la competencia conserva el suyo: el ponderado de las dos (15 → PI).
      assert_equal "PI", suya["nivel_de_rubrica"]
    end
  end

  # ⚠️ Decisión de Daniel, 18 de septiembre: el indicador que nadie midió NO
  # sale. No tiene nivel que mostrar, y el renglón vacío alarga una boleta que
  # ya tiene ocho materias. El plan completo se ve en la pantalla del profesor.
  test "el indicador que ninguna evaluación midió no sale en la boleta" do
    con_el_colegio(@esc.colegio) do
      @esc.colegio.restablecer_la_rubrica!
      competencia = Competency.create!(section: @esc.seccion, subject: @esc.materia,
                                       evaluation_moment: @lapso, descripcion: "Una sola medida")
      competencia.indicators.create!(descripcion: "Este sí se midió", orden: 0)
      competencia.indicators.create!(descripcion: "Este no lo midió nadie", orden: 1)

      examen = actividad(@esc, lapso: @lapso, peso: 100, descripcion: "Examen", mide: competencia)
      nota(examen, @esc.alumno, 18)

      datos = ReportCardData.para(enrollment: @esc.inscripcion, evaluation_moment: @lapso)
      plan = datos["materias"].find { |m| m["materia"] == @esc.materia.name }["competencias"]
      suya = plan.find { |c| c["texto"] == "Una sola medida" }

      assert_equal [ "Este sí se midió" ], suya["indicadores"].map { |i| i["texto"] }
    end
  end

  # ⚠️ Un boletín EMITIDO no cambia, y los viejos guardaron los indicadores como
  # una lista de TEXTOS. Leerlos como hashes dejaría la boleta de diciembre con
  # los indicadores en blanco — y reescribir el `snapshot` es exactamente lo que
  # el `snapshot` existe para impedir.
  test "un boletín emitido antes de esto sigue mostrando sus indicadores" do
    viejo = { "texto" => "Del formato anterior",
              "indicadores" => [ "Suma con reagrupación", "Estima antes de calcular" ] }

    assert_equal [ { "texto" => "Suma con reagrupación", "nivel_de_rubrica" => nil },
                   { "texto" => "Estima antes de calcular", "nivel_de_rubrica" => nil } ],
                 PlanEvaluado.indicadores_de(viejo)
  end

  # ⚠️ Una competencia que ninguna evaluación etiquetó SÍ se imprime, sin nivel.
  # Es información del plan —«esto se trabajó»— y esconderla dejaría a la
  # familia sin saber qué se evaluó.
  test "una competencia sin evaluaciones sale sin nivel, no con el más bajo" do
    con_el_colegio(@esc.colegio) do
      @esc.colegio.restablecer_la_rubrica!
      # ⚠️ Hace falta UNA actividad para que la materia entre al boletín
      # (`Enrollment#materias_del_boletin`), y desde `MOR-136` esa actividad
      # mide la suya —el escenario se la arma—. La que se está probando es OTRA,
      # la que nadie etiquetó: por eso el plan trae dos y se busca por nombre.
      actividad(@esc, lapso: @lapso, peso: 100)
      Competency.create!(section: @esc.seccion, subject: @esc.materia,
                         evaluation_moment: @lapso, descripcion: "Nadie la evaluó todavía")

      datos = ReportCardData.para(enrollment: @esc.inscripcion, evaluation_moment: @lapso)
      plan = datos["materias"].find { |m| m["materia"] == @esc.materia.name }["competencias"]

      sin_evaluar = plan.find { |c| c["texto"] == "Nadie la evaluó todavía" }
      assert_nil sin_evaluar["nivel_de_rubrica"],
                 "sin evaluar NO es NP: el más bajo reprueba, y a este alumno no le tomaron nada"
    end
  end

  # ⚠️ El nivel de una competencia sale del promedio PONDERADO de las
  # actividades que la evalúan — la regla del Art. 111 aplicada a un
  # subconjunto, no una regla inventada.
  test "el nivel de la competencia pondera las evaluaciones que la miden" do
    con_el_colegio(@esc.colegio) do
      @esc.colegio.restablecer_la_rubrica!
      competencia = Competency.create!(section: @esc.seccion, subject: @esc.materia,
                                       evaluation_moment: @lapso, descripcion: "Con dos evaluaciones")
      # ⚠️ Un indicador POR EVALUACIÓN: no se repiten entre evaluaciones, así
      # que las dos de esta competencia miden cosas distintas de ella.
      pesada  = actividad(@esc, lapso: @lapso, peso: 70, descripcion: "Examen", mide: competencia)
      liviana = actividad(@esc, lapso: @lapso, peso: 30, descripcion: "Taller", mide: competencia)
      nota(pesada, @esc.alumno, 20)
      nota(liviana, @esc.alumno, 10)

      datos = ReportCardData.para(enrollment: @esc.inscripcion, evaluation_moment: @lapso)
      plan = datos["materias"].find { |m| m["materia"] == @esc.materia.name }["competencias"]

      # (20×70 + 10×30) / 100 = 17 → PA. Con promedio simple daría 15 → PI.
      assert_equal "PA", plan.first["nivel_de_rubrica"],
                   "el peso de cada evaluación tiene que entrar en la cuenta"
    end
  end

  # ⚠️ La rúbrica va CONGELADA en el snapshot: si el colegio la cambia en marzo,
  # el boletín de diciembre tiene que seguir diciendo lo que decía.
  test "la rúbrica entra al snapshot con su leyenda" do
    con_el_colegio(@esc.colegio) do
      @esc.colegio.restablecer_la_rubrica!
      datos = ReportCardData.para(enrollment: @esc.inscripcion, evaluation_moment: @lapso)

      assert_equal %w[PC PA PI PD NP], datos["rubrica"].map { |r| r["codigo"] }
      assert_equal "Proceso avanzado", datos["rubrica"].find { |r| r["codigo"] == "PA" }["nombre"],
                   "la leyenda va entera: la boleta impresa la explica"
    end
  end

  test "un boletín emitido no cambia aunque el colegio cambie la rúbrica" do
    boletin = con_el_colegio(@esc.colegio) do
      @esc.colegio.restablecer_la_rubrica!
      actividad = actividad(@esc, lapso: @lapso, peso: 100)
      nota(actividad, @esc.alumno, 17)

      ReportCard.create!(
        enrollment: @esc.inscripcion, evaluation_moment: @lapso,
        issued_by: User.create!(first_name: "Dir", last_name: "Prueba",
                                email: "dir.boleta@test.edu", password: "123123",
                                document: "V-70000111", document_type: :cedula_v),
        snapshot: ReportCardData.para(enrollment: @esc.inscripcion, evaluation_moment: @lapso)
      )
    end

    con_el_colegio(@esc.colegio) do
      Rubric.destroy_all
      Rubric.create!(code: "L", name: "Logrado", valor: 1)

      assert_equal "PA", boletin.reload.snapshot["materias"].first["nivel_de_rubrica"],
                   "el papel que la familia tiene en la mano no puede cambiar de palabra"
    end
  end

  # ⚠️ El ANUAL no lleva plan: cruza tres lapsos, y las competencias son de uno.
  test "el boletín anual no trae competencias" do
    con_el_colegio(@esc.colegio) do
      @esc.colegio.restablecer_la_rubrica!
      actividad(@esc, lapso: @lapso, peso: 100)
      Competency.create!(section: @esc.seccion, subject: @esc.materia,
                         evaluation_moment: @lapso, descripcion: "Del primer lapso")

      datos = ReportCardData.para(enrollment: @esc.inscripcion)
      assert_nil datos["materias"].first["competencias"],
                 "el anual cruza tres lapsos: un plan de uno solo no lo describe"
    end
  end

  # El PDF tiene que poder dibujarse con todo esto adentro.
  test "el PDF se genera con competencias y rúbrica" do
    boletin = con_el_colegio(@esc.colegio) do
      @esc.colegio.restablecer_la_rubrica!
      competencia = Competency.create!(section: @esc.seccion, subject: @esc.materia,
                                       evaluation_moment: @lapso, descripcion: "Resuelve problemas")
      competencia.indicators.create!(descripcion: "Suma con reagrupación", orden: 0)
      actividad = actividad(@esc, lapso: @lapso, peso: 100, mide: competencia)
      nota(actividad, @esc.alumno, 19)

      ReportCard.create!(
        enrollment: @esc.inscripcion, evaluation_moment: @lapso,
        issued_by: User.create!(first_name: "Dir", last_name: "Pdf",
                                email: "dir.pdf@test.edu", password: "123123",
                                document: "V-70000222", document_type: :cedula_v),
        snapshot: ReportCardData.para(enrollment: @esc.inscripcion, evaluation_moment: @lapso)
      )
    end

    pdf = ReportCardPdf.new([ boletin ]).render
    assert pdf.bytesize > 1000, "el PDF salió vacío"
    assert pdf.start_with?("%PDF"), "no es un PDF"
  end
end
