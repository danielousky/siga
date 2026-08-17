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
end
