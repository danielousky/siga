require "test_helper"

# "Situación del estudiante con respecto al promedio de la sección" (MOR-135).
#
# Es la pieza que Daniel señaló del boletín de la U.E. Centro Educativo APUCV, y
# contesta la pregunta que una familia hace de verdad: no *"¿cuánto sacó?"* sino
# *"¿cómo le fue comparado con sus compañeros?"*.
class SituacionEnLaSeccionTest < ActiveSupport::TestCase
  setup do
    @esc = escenario_academico(alumnos: 4)
  end

  def comparar(notas_por_alumno)
    con_el_colegio(@esc.colegio) do
      actividad = actividad(@esc, lapso: @esc.lapso(1), peso: 100)
      notas_por_alumno.each_with_index do |puntaje, i|
        next if puntaje.nil?

        nota(actividad, @esc.alumno(i + 1), puntaje)
      end
      ReportCardData.para(enrollment: @esc.inscripcion(1), evaluation_moment: @esc.lapso(1))
                    .to_h["comparacion"]
    end
  end

  test "ubica al alumno en la banda que le toca según su distancia al promedio" do
    # El alumno 1 saca 18; los otros tres, 10. Promedio de la sección: 12.
    # Diferencia: +6 → más de cuatro puntos por encima → la banda más alta.
    c = comparar([ 18, 10, 10, 10 ])

    fila = c["materias"].first
    assert_equal 18, fila["nota"]
    assert_equal 12.0, fila["seccion"]
    assert_equal "Muy alto", c["niveles"][fila["nivel"]]
  end

  test "un alumno en el promedio exacto cae en la banda que arranca en cero" do
    # Todos sacan 14: el alumno está exactamente en el promedio.
    c = comparar([ 14, 14, 14, 14 ])

    assert_equal "Medio alto", c["niveles"][c["materias"].first["nivel"]]
  end

  # Estar por debajo del promedio de la clase no es reprobar: se puede estar
  # debajo con 17. Por eso la banda es informativa y no lleva color semántico.
  test "un alumno aprobado puede quedar por debajo del promedio" do
    c = comparar([ 17, 20, 20, 20 ])

    fila = c["materias"].first
    assert_equal 17, fila["nota"]
    assert_includes [ "Medio bajo", "Bajo" ], c["niveles"][fila["nivel"]]
  end

  # Con un solo alumno con nota, el "promedio de la sección" sería él mismo
  # comparándose consigo mismo: un dato que no significa nada impreso en un
  # papel oficial.
  test "no compara cuando hay una sola nota en la materia" do
    assert_nil comparar([ 15, nil, nil, nil ])
  end

  # El boletín anual compara contra los tres lapsos del propio alumno, no
  # contra la clase: son dos preguntas distintas y mezclarlas confunde.
  test "el boletín anual no lleva comparación con la sección" do
    con_el_colegio(@esc.colegio) do
      actividad = actividad(@esc, lapso: @esc.lapso(1), peso: 100)
      [ 18, 10, 10, 10 ].each_with_index { |p, i| nota(actividad, @esc.alumno(i + 1), p) }

      anual = ReportCardData.para(enrollment: @esc.inscripcion(1)).to_h
      assert_nil anual["comparacion"]
    end
  end

  # El promedio de una sección cambia cada vez que un profesor carga una nota.
  # Si el PDF lo calculara al imprimir, reemitir en marzo el boletín de
  # diciembre lo compararía contra una clase distinta — justo lo que `MOR-98`
  # vino a evitar.
  test "la comparación queda congelada en el snapshot" do
    con_el_colegio(@esc.colegio) do
      actividad = actividad(@esc, lapso: @esc.lapso(1), peso: 100)
      [ 18, 10, 10, 10 ].each_with_index { |p, i| nota(actividad, @esc.alumno(i + 1), p) }

      boletin = ReportCard.create!(
        enrollment: @esc.inscripcion(1), evaluation_moment: @esc.lapso(1),
        issued_by: User.create!(name: "Dir", last_name: "Test", email: "dir@sec.test", password: "123123"),
        snapshot: ReportCardData.para(enrollment: @esc.inscripcion(1), evaluation_moment: @esc.lapso(1))
      )
      congelado = boletin.snapshot.dig("comparacion", "materias", 0, "seccion")

      # La clase mejora después de emitido.
      @esc.alumnos.drop(1).each do |alumno|
        ActivityGrade.find_by(evaluation_activity: actividad, student: alumno).update!(score: 20)
      end

      assert_equal congelado, boletin.reload.snapshot.dig("comparacion", "materias", 0, "seccion"),
        "el boletín tiene que seguir diciendo lo que decía el día que se emitió"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Inasistencias del lapso, y puesto en la sección
  # ══════════════════════════════════════════════════════════════════════════

  # Un lapso ES un rango de fechas. Sin ellas, el boletín del segundo lapso
  # arrastraría las faltas del primero sin que nada avise.
  test "las inasistencias se cuentan dentro del lapso, no del año" do
    con_el_colegio(@esc.colegio) do
      primero = @esc.lapso(1)
      primero.update!(starts_on: Date.new(2025, 9, 15), ends_on: Date.new(2025, 12, 20))

      Attendance.create!(enrollment: @esc.inscripcion(1), date: Date.new(2025, 10, 1), status: :ausente)
      Attendance.create!(enrollment: @esc.inscripcion(1), date: Date.new(2025, 11, 5), status: :tarde)
      # Fuera del lapso: no debe contarse.
      Attendance.create!(enrollment: @esc.inscripcion(1), date: Date.new(2026, 2, 3), status: :ausente)

      a = ReportCardData.para(enrollment: @esc.inscripcion(1), evaluation_moment: primero).to_h["asistencia"]

      assert_equal 2, a["dias"]
      assert_equal 1, a["ausentes"]
      assert_equal 1, a["tardes"]
      assert a["del_lapso"], "con fechas propias, el boletín tiene que decir que contó el lapso"
    end
  end

  # Los lapsos ya sembrados no tienen fechas, y obligarlas rompería el alta.
  # Donde falten se cuenta el año escolar — y el papel lo dice, porque un número
  # de inasistencias sin su período no se puede interpretar.
  test "sin fechas de lapso cuenta el año escolar y lo declara" do
    con_el_colegio(@esc.colegio) do
      primero = @esc.lapso(1)
      assert_not primero.fechas_propias?

      Attendance.create!(enrollment: @esc.inscripcion(1), date: @esc.periodo.start_date + 30, status: :ausente)

      a = ReportCardData.para(enrollment: @esc.inscripcion(1), evaluation_moment: primero).to_h["asistencia"]

      assert_equal 1, a["ausentes"]
      assert_not a["del_lapso"]
    end
  end

  # Dos alumnos con el mismo promedio están LOS DOS en el mismo puesto: darle
  # el 3 a uno y el 4 al otro por el orden alfabético inventa una diferencia
  # que no existe, y se imprime en un papel que la familia guarda.
  test "el empate comparte puesto y queda declarado" do
    c = nil
    con_el_colegio(@esc.colegio) do
      actividad = actividad(@esc, lapso: @esc.lapso(1), peso: 100)
      [ 15, 15, 10, 10 ].each_with_index { |p, i| nota(actividad, @esc.alumno(i + 1), p) }
      c = ReportCardData.para(enrollment: @esc.inscripcion(1), evaluation_moment: @esc.lapso(1)).to_h["puesto"]
    end

    assert_equal 1, c["puesto"], "dos con 15 están los dos primeros"
    assert_equal 4, c["de"]
    assert c["empatado"]
  end

  test "quien no tiene nota no cuenta para el puesto" do
    c = nil
    con_el_colegio(@esc.colegio) do
      actividad = actividad(@esc, lapso: @esc.lapso(1), peso: 100)
      # Solo dos alumnos con nota: el resto está sin evaluar, no último.
      nota(actividad, @esc.alumno(1), 12)
      nota(actividad, @esc.alumno(2), 18)
      c = ReportCardData.para(enrollment: @esc.inscripcion(1), evaluation_moment: @esc.lapso(1)).to_h["puesto"]
    end

    assert_equal 2, c["puesto"]
    assert_equal 2, c["de"]
  end
end
