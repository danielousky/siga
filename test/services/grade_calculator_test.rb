require "test_helper"

# El número que sale de acá va en un boletín, decide si un alumno repite el año
# y termina en un documento con validez ante el MPPE. Cada test cita el artículo
# del Reglamento General de la LOE que lo justifica, para que el día que alguien
# discuta un promedio se pueda ir a la norma y no a la opinión.
#
# Ver MOR-93.
class GradeCalculatorTest < ActiveSupport::TestCase
  # ══════════════════════════════════════════════════════════════════════════
  # Artículo 108 · el redondeo
  # ══════════════════════════════════════════════════════════════════════════

  test "Art. 108: las fracciones de 0,50 o más suben al entero siguiente" do
    assert_equal 9,  GradeCalculator.redondear(BigDecimal("9.49"))
    assert_equal 10, GradeCalculator.redondear(BigDecimal("9.50")), "9,50 tiene que subir: es repetir o aprobar"
    assert_equal 10, GradeCalculator.redondear(BigDecimal("9.51"))
    assert_equal 11, GradeCalculator.redondear(BigDecimal("10.50")), "no es redondeo bancario: 10,5 → 11, no 10"
    assert_equal 20, GradeCalculator.redondear(BigDecimal("19.50"))
  end

  test "el redondeo no inventa una nota donde no hay ninguna" do
    assert_nil GradeCalculator.redondear(nil)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La calificación del lapso
  # ══════════════════════════════════════════════════════════════════════════

  test "promedio ponderado del lapso según el peso de cada actividad" do
    esc = escenario_academico

    con_el_colegio(esc.colegio) do
      examen = actividad(esc, lapso: esc.lapso(1), peso: 60, descripcion: "Examen")
      taller = actividad(esc, lapso: esc.lapso(1), peso: 40, descripcion: "Taller")

      nota(examen, esc.alumno, 18)
      nota(taller, esc.alumno, 12)

      mg = GradeCalculator.calculate_moment_grade(
        enrollment: esc.inscripcion, subject: esc.materia, evaluation_moment: esc.lapso(1)
      )

      # 18×60 + 12×40 = 1560 ; 1560/100 = 15,6 → 16
      assert_equal 16, mg.final_moment_score
    end
  end

  test "el lapso también se redondea: 14,60 no se guarda, se guarda 15" do
    esc = escenario_academico

    con_el_colegio(esc.colegio) do
      a = actividad(esc, lapso: esc.lapso(1), peso: 50, descripcion: "A")
      b = actividad(esc, lapso: esc.lapso(1), peso: 50, descripcion: "B")
      nota(a, esc.alumno, 14)
      nota(b, esc.alumno, 15)

      mg = GradeCalculator.calculate_moment_grade(
        enrollment: esc.inscripcion, subject: esc.materia, evaluation_moment: esc.lapso(1)
      )

      # 14,5 → 15 por el Art. 108
      assert_equal 15, mg.final_moment_score
    end
  end

  test "el promedio se hace sobre el peso cargado, no sobre 100" do
    esc = escenario_academico

    con_el_colegio(esc.colegio) do
      # El profesor definió actividades por el 70 %: falta el 30 % del lapso.
      a = actividad(esc, lapso: esc.lapso(1), peso: 40, descripcion: "A")
      b = actividad(esc, lapso: esc.lapso(1), peso: 30, descripcion: "B")
      nota(a, esc.alumno, 20)
      nota(b, esc.alumno, 20)

      mg = GradeCalculator.calculate_moment_grade(
        enrollment: esc.inscripcion, subject: esc.materia, evaluation_moment: esc.lapso(1)
      )

      # Dividir por 100 daría 14: el alumno perdería 6 puntos por evaluaciones
      # que todavía no existen.
      assert_equal 20, mg.final_moment_score
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Artículo 111 · la calificación definitiva del año
  # ══════════════════════════════════════════════════════════════════════════

  test "Art. 111: el anual es el PROMEDIO de los lapsos, sin ponderar" do
    # Los pesos están puestos a propósito bien desparejos: si el cálculo los
    # mirara, el resultado sería otro.
    esc = escenario_academico(pesos: [30, 30, 40])

    con_el_colegio(esc.colegio) do
      calificar_lapsos(esc, [12, 15, 18])

      fgb = GradeCalculator.calculate_final_grade(enrollment: esc.inscripcion, subject: esc.materia)

      # (12 + 15 + 18) / 3 = 15
      # Ponderando 30/30/40 daría (360 + 450 + 720)/100 = 15,3 → 15 también acá,
      # pero el test de abajo separa los dos caminos.
      assert_equal 15, fgb.annual_average
      assert_equal 15, fgb.final_score
    end
  end

  test "el peso del lapso NO entra en el anual: 8·8·20 da 12, no 14" do
    esc = escenario_academico(pesos: [20, 20, 60])

    con_el_colegio(esc.colegio) do
      calificar_lapsos(esc, [8, 8, 20])

      fgb = GradeCalculator.calculate_final_grade(enrollment: esc.inscripcion, subject: esc.materia)

      # Promedio simple: (8 + 8 + 20)/3 = 12
      # Ponderado 20/20/60:  (160 + 160 + 1200)/100 = 15,2 → 15
      assert_equal 12, fgb.annual_average, "el anual no puede depender de evaluation_moments.weight"
    end
  end

  test "Art. 111: el anual se calcula sobre los ENTEROS de cada lapso, no sobre los decimales" do
    esc = escenario_academico(pesos: [1, 1, 1])   # promedio simple, como el 111

    con_el_colegio(esc.colegio) do
      # Dos actividades 50/50 por lapso, con 10 y 9: cada lapso da 9,5 en crudo.
      3.times do |i|
        a = actividad(esc, lapso: esc.lapso(i + 1), peso: 50, descripcion: "A#{i}")
        b = actividad(esc, lapso: esc.lapso(i + 1), peso: 50, descripcion: "B#{i}")
        nota(a, esc.alumno, 10)
        nota(b, esc.alumno, 9)

        mg = GradeCalculator.calculate_moment_grade(
          enrollment: esc.inscripcion, subject: esc.materia, evaluation_moment: esc.lapso(i + 1)
        )
        assert_equal 10, mg.final_moment_score, "el lapso de 9,5 tiene que quedar guardado como 10"
      end

      fgb = GradeCalculator.calculate_final_grade(enrollment: esc.inscripcion, subject: esc.materia)

      # La cadena del Reglamento: primero el entero de cada lapso (Art. 108),
      # después el promedio de esos enteros (Art. 111). Guardando los 9,5 en
      # crudo el anual también sería 9,5, y redondeando UNA sola vez al final el
      # alumno quedaría igual — pero la nota que se le informó en cada lapso
      # habría sido 9,5, que no es una calificación que la norma admita.
      assert_equal 10, fgb.annual_average, "con 9,5 en los tres lapsos el alumno aprueba"
    end
  end

  test "un solo lapso cerrado no se promedia como si el año estuviera completo" do
    esc = escenario_academico(pesos: [30, 30, 40])

    con_el_colegio(esc.colegio) do
      calificar_lapso(esc, esc.lapso(1), 18)

      fgb = GradeCalculator.calculate_final_grade(enrollment: esc.inscripcion, subject: esc.materia)

      # 18, no 18×0,30 = 5,4. En noviembre el "anual" es el del único lapso que
      # existe; los otros dos no valen cero, no existen.
      assert_equal 18, fgb.annual_average
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Artículo 112 · la reparación
  # ══════════════════════════════════════════════════════════════════════════

  test "la reparación levanta la nota definitiva, y el anual queda registrado" do
    esc = escenario_academico(pesos: [30, 30, 40])

    con_el_colegio(esc.colegio) do
      calificar_lapsos(esc, [8, 8, 8])
      GradeCalculator.calculate_final_grade(enrollment: esc.inscripcion, subject: esc.materia)

      fgb = FinalGradeBook.find_by(enrollment: esc.inscripcion, subject: esc.materia)
      fgb.update!(remedial_exam_score: 14)

      GradeCalculator.calculate_final_grade(enrollment: esc.inscripcion, subject: esc.materia)
      fgb.reload

      assert_equal 8,  fgb.annual_average, "el anual no se pisa: queda la traza de que estaba aplazado"
      assert_equal 14, fgb.final_score
    end
  end

  test "una reparación reprobada no baja lo que el alumno ya tenía" do
    esc = escenario_academico(pesos: [30, 30, 40])

    con_el_colegio(esc.colegio) do
      calificar_lapsos(esc, [9, 9, 9])
      GradeCalculator.calculate_final_grade(enrollment: esc.inscripcion, subject: esc.materia)

      fgb = FinalGradeBook.find_by(enrollment: esc.inscripcion, subject: esc.materia)
      fgb.update!(remedial_exam_score: 5)

      GradeCalculator.calculate_final_grade(enrollment: esc.inscripcion, subject: esc.materia)

      assert_equal 9, fgb.reload.final_score
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Los casos borde — la tabla del issue. Ninguno debe explotar.
  # ══════════════════════════════════════════════════════════════════════════

  test "borde · sin actividades cargadas: no hay nota, y no hay división por cero" do
    esc = escenario_academico

    con_el_colegio(esc.colegio) do
      assert_nothing_raised do
        assert_nil GradeCalculator.calculate_moment_grade(
          enrollment: esc.inscripcion, subject: esc.materia, evaluation_moment: esc.lapso(1)
        )
      end
      assert_equal 0, MomentGrade.count
    end
  end

  test "borde · actividades sin notas: el alumno sale SIN nota, no con cero" do
    esc = escenario_academico

    con_el_colegio(esc.colegio) do
      actividad(esc, lapso: esc.lapso(1), peso: 100, descripcion: "Examen sin corregir")

      mg = GradeCalculator.calculate_moment_grade(
        enrollment: esc.inscripcion, subject: esc.materia, evaluation_moment: esc.lapso(1)
      )

      # Si esto devolviera 0, a mitad de lapso estaría reprobada la sección entera.
      assert_nil mg
      assert_equal 0, MomentGrade.count
    end
  end

  test "borde · una actividad sin nota no arrastra al promedio de las que sí tienen" do
    esc = escenario_academico

    con_el_colegio(esc.colegio) do
      corregida = actividad(esc, lapso: esc.lapso(1), peso: 50, descripcion: "Corregida")
      actividad(esc, lapso: esc.lapso(1), peso: 50, descripcion: "Sin corregir")
      nota(corregida, esc.alumno, 16)

      mg = GradeCalculator.calculate_moment_grade(
        enrollment: esc.inscripcion, subject: esc.materia, evaluation_moment: esc.lapso(1)
      )

      # 16, no 8. La actividad sin corregir sale del promedio con su peso.
      assert_equal 16, mg.final_moment_score
    end
  end

  test "borde · peso total cero: no explota y no escribe nota" do
    esc = escenario_academico

    con_el_colegio(esc.colegio) do
      # `weight_percentage` no admite 0 por validación, así que el peso total
      # solo puede ser cero si ninguna actividad tiene nota — que es este caso.
      actividad(esc, lapso: esc.lapso(1), peso: 100, descripcion: "Sin notas")

      assert_nothing_raised do
        assert_nil GradeCalculator.calculate_moment_grade(
          enrollment: esc.inscripcion, subject: esc.materia, evaluation_moment: esc.lapso(1)
        )
      end
    end
  end

  test "Art. 108 · la escala arranca en 1: el modelo rechaza el 0 y el 21" do
    esc = escenario_academico

    con_el_colegio(esc.colegio) do
      act = actividad(esc, lapso: esc.lapso(1), peso: 100)

      assert_raises(ActiveRecord::RecordInvalid) { nota(act, esc.alumno, 21) }
      assert_raises(ActiveRecord::RecordInvalid) { nota(act, esc.alumno, 0) }
      assert_raises(ActiveRecord::RecordInvalid) { nota(act, esc.alumno, -1) }

      assert nota(act, esc.alumno, 1).persisted?, "01 sí es una calificación válida"
    end
  end

  test "Art. 108 · la base rechaza el 0 aunque se salten las validaciones" do
    esc = escenario_academico

    con_el_colegio(esc.colegio) do
      act = actividad(esc, lapso: esc.lapso(1), peso: 100)
      registro = nota(act, esc.alumno, 15)

      # `update_column` no pasa por ActiveRecord. Es el camino por el que va a
      # entrar el importador de matrícula de MOR-126.
      #
      # Cada intento va en su propio savepoint: un CHECK violado aborta la
      # transacción entera, y sin aislarlo se lleva puesto todo lo que venga
      # después — incluido el `ensure` que devuelve el contexto de colegio.
      [0, 25].each do |fuera_de_escala|
        assert_raises(ActiveRecord::StatementInvalid, "la base tiene que rechazar #{fuera_de_escala}") do
          ActiveRecord::Base.transaction(requires_new: true) do
            registro.update_column(:score, fuera_de_escala)
          end
        end
      end

      assert_equal 15, registro.reload.score
    end
  end

  test "borde · el peso de las actividades de un lapso no puede pasar de 100" do
    esc = escenario_academico

    con_el_colegio(esc.colegio) do
      actividad(esc, lapso: esc.lapso(1), peso: 70, descripcion: "A")

      error = assert_raises(ActiveRecord::RecordInvalid) do
        actividad(esc, lapso: esc.lapso(1), peso: 40, descripcion: "B")
      end
      assert_match(/no puede exceder 100/, error.message)
    end
  end

  test "borde · sin lapsos definidos no hay anual, y no explota" do
    esc = escenario_academico(pesos: [])

    con_el_colegio(esc.colegio) do
      assert_nothing_raised do
        assert_nil GradeCalculator.calculate_final_grade(enrollment: esc.inscripcion, subject: esc.materia)
      end
      assert_equal 0, FinalGradeBook.count
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Aislamiento — el cálculo no puede mirar a otro colegio
  # ══════════════════════════════════════════════════════════════════════════

  test "el anual solo promedia los lapsos del período del alumno" do
    esc = escenario_academico(pesos: [50, 50])

    con_el_colegio(esc.colegio) do
      # Otro año del MISMO colegio, con su propia estructura de lapsos.
      otro = AcademicPeriod.create!(
        school: esc.colegio, name: "2026-2027", start_date: Date.new(2026, 9, 1), end_date: Date.new(2027, 7, 31)
      )
      semestre_ajeno = EvaluationMoment.create!(academic_period: otro, name: "Semestre 1")

      calificar_lapsos(esc, [10, 20])

      # Una calificación colgada del lapso del OTRO año. Sin el filtro por
      # período entraría al promedio: es la fila que hace que el test muerda.
      MomentGrade.create!(
        enrollment: esc.inscripcion, subject: esc.materia,
        evaluation_moment: semestre_ajeno, final_moment_score: 3
      )

      fgb = GradeCalculator.calculate_final_grade(enrollment: esc.inscripcion, subject: esc.materia)

      # (10 + 20)/2 = 15 con los dos lapsos de SU período.
      # Contando el ajeno: (10 + 20 + 3)/3 = 11.
      assert_equal 15, fgb.annual_average
    end
  end

  test "calcular todo para una sección recorre a sus alumnos y a nadie más" do
    esc = escenario_academico(pesos: [100], alumnos: 3)

    con_el_colegio(esc.colegio) do
      act = actividad(esc, lapso: esc.lapso(1), peso: 100, descripcion: "Examen")
      [20, 15, 10].each_with_index { |puntaje, i| nota(act, esc.alumno(i + 1), puntaje) }

      GradeCalculator.calculate_all_for_section(esc.seccion)

      assert_equal 3, MomentGrade.count
      assert_equal 3, FinalGradeBook.count
      assert_equal [10, 15, 20], FinalGradeBook.pluck(:final_score).map(&:to_i).sort
    end
  end

  private

  # Le pone al alumno la misma nota en todas las actividades de un lapso.
  def calificar_lapso(esc, lapso, puntaje, alumno: nil)
    act = actividad(esc, lapso: lapso, peso: 100, descripcion: "Evaluación #{lapso.name}")
    nota(act, alumno || esc.alumno, puntaje)
    GradeCalculator.calculate_moment_grade(
      enrollment: esc.inscripcion, subject: esc.materia, evaluation_moment: lapso
    )
  end

  def calificar_lapsos(esc, puntajes)
    puntajes.each_with_index { |puntaje, i| calificar_lapso(esc, esc.lapso(i + 1), puntaje) }
  end
end
