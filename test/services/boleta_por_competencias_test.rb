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
      assert_equal [ "Suma con reagrupación" ], plan.first["indicadores"]
      assert_equal "PC", plan.first["nivel_de_rubrica"]
    end
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
