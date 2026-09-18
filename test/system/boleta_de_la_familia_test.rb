require "application_system_test_case"

# Lo que ve el representante del plan del lapso (MOR-136, segunda mitad).
#
# ## Qué se prueba acá y no en un test de integración
#
# Que el nivel de cada indicador se LEA en su renglón. El dato lo arma
# `PlanEvaluado` y eso ya está probado; lo que un test de integración no ve es
# si el nivel queda pegado al texto, si la línea de puntos lo empuja fuera de la
# tarjeta, o si el `order: 3` del CSS lo manda al lugar equivocado.
#
#     • Resuelve problemas de adición                    PA
#         – Suma con reagrupación  · · · · · · · · · ·   PC
#         – Resuelve en dos pasos  · · · · · · · · · ·   PD
class BoletaDeLaFamiliaSystemTest < ApplicationSystemTestCase
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)

    @competencia = con_el_colegio(@a.colegio) do
      @a.colegio.restablecer_la_rubrica!
      c = competencia_con(2, "Resuelve problemas de adición", lapso: @lapso)

      # Dos evaluaciones de la MISMA competencia con notas muy distintas: es lo
      # que la boleta no podía decir antes — imprimía los dos indicadores bajo
      # el nivel de la competencia, que es el ponderado de las dos.
      examen = actividad(@a.escenario, lapso: @lapso, peso: 50, descripcion: "Examen", mide: c)
      taller = actividad(@a.escenario, lapso: @lapso, peso: 50, descripcion: "Taller", mide: c)
      nota(examen, @a.escenario.alumno, 19)
      nota(taller, @a.escenario.alumno, 10)
      c
    end

    # El representante del alumno del escenario.
    @representante = con_el_colegio(@a.colegio) do
      usuario = User.create!(first_name: "Marta", last_name: "Prueba",
                             email: "marta.portal@familia.test", password: "123123")
      registro = Representative.create!(user: usuario, school: @a.colegio)
      StudentRepresentative.create!(student: @a.escenario.alumno, representative: registro,
                                    parentesco: :madre, principal: true)
      usuario
    end
  end

  test "cada indicador se lee con su propio nivel, distinto del de la competencia" do
    entrar_como @representante
    visit hijo_representante_path(@a.escenario.alumno, lapso: @lapso.id)

    assert_text "Resuelve problemas de adición"

    niveles = all(".portal-indicador").to_h { |i| [ i.text.split("\n").first, i.find(".portal-indicador-nivel").text ] }

    # 19 → PC y 10 → PD: dos indicadores de la misma competencia, dos niveles.
    assert_equal %w[PC PD].sort, niveles.values.sort,
                 "cada indicador tiene que llevar el nivel de la evaluación que lo midió"

    # Y la competencia conserva el suyo: el ponderado de las dos (15 → PI).
    assert_selector ".portal-competencia-nivel", text: "PI"
  end
end
