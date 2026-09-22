require "test_helper"

# Los indicadores, uno por uno y DENTRO de su evaluación.
#
# ⚠️ Desde el 21 de septiembre el alta exige la evaluación que lo mide. Daniel:
# *«al crear un nuevo indicador debe estar asociado a su respectiva evaluación;
# ahorita al agregarlo queda suelto, asociado únicamente al componente»*.
class IndicadoresTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)
    @contexto = { asignacion: "#{@a.seccion.id}:#{@a.escenario.materia.id}", lapso: @lapso.id }
    @competencia, @evaluacion = con_el_colegio(@a.colegio) do
      c = competencia_con(1, "Resuelve problemas", lapso: @lapso)
      # ⚠️ La evaluación necesita un indicador para nacer, así que la
      # competencia trae uno y el test agrega los suyos encima.
      [ c, actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen", mide: c) ]
    end
    sign_in @a.profesor
  end

  def agregar(texto, a: @evaluacion, de: @competencia)
    post competency_indicators_path(de, **@contexto, evaluacion: a&.id),
         params: { indicator: { descripcion: texto } },
         headers: { "Turbo-Frame" => "plan" }
  end

  # Los que agregó el test, sin el que trajo la competencia para poder crear la
  # evaluación.
  def indicadores
    con_el_colegio(@a.colegio) do
      @competencia.indicators.en_orden.map(&:descripcion).grep_v(/\AIndicador \d/)
    end
  end

  test "se agregan en orden, midiendo su evaluación" do
    agregar "Suma con reagrupación"
    agregar "Resta con préstamo"

    assert_equal [ "Suma con reagrupación", "Resta con préstamo" ], indicadores
    con_el_colegio(@a.colegio) do
      assert @competencia.indicators.reload.all?(&:medido?),
             "ninguno puede quedar suelto: uno sin evaluación no sale en la boleta"
    end
  end

  # ⚠️ El agujero que reportó Daniel: sin la evaluación, el indicador quedaba
  # colgado solo de la competencia — invisible en la pantalla y ausente de la
  # boleta, que solo imprime los medidos.
  test "sin evaluación no se crea, y lo dice" do
    assert_no_difference -> { cantidad(Indicator) } do
      agregar "Suelto", a: nil
    end

    assert_response :unprocessable_entity
    assert_select ".plan-competencia-error", /Falta la evaluación/
  end

  # ⚠️ Y la evaluación tiene que medir ESTA competencia: la de otra no está en
  # la lista, así que el alta se rechaza sin tener que comprobar nada a mano.
  test "no se cuela la evaluación de otra competencia" do
    suya = con_el_colegio(@a.colegio) do
      c = competencia_con(1, "Interpreta gráficos", lapso: @lapso)
      actividad(@a.escenario, lapso: @lapso, peso: 30, descripcion: "Taller", mide: c)
    end

    assert_no_difference -> { cantidad(Indicator) } do
      agregar "De la otra", a: suya, de: @competencia
    end

    assert_response :unprocessable_entity
    assert_select ".plan-competencia-error", /Falta la evaluación/,
                  "la de otra competencia no está en la lista: es como no mandar ninguna"
  end

  # ⚠️ Repetir uno reventaba con `ActiveRecord::RecordNotUnique` —la pantalla
  # roja de Rails— porque el índice único estaba en la base y la validación no.
  # Daniel: *«está bien, pero no debería explotar sino decirme que está
  # duplicado»*.
  test "repetir un indicador se dice, no explota" do
    agregar "Suma con reagrupación"

    assert_nothing_raised { agregar "Suma con reagrupación" }

    assert_response :unprocessable_entity
    assert_select ".plan-competencia-error", /ya está en esta competencia/
    assert_equal [ "Suma con reagrupación" ], indicadores, "no se guardó el segundo"
  end

  # ⚠️ La unicidad va sobre la CANÓNICA: «Suma con reagrupación» y «suma con
  # reagrupacion» son el mismo indicador escrito dos veces, y el índice de la
  # base también los cuenta como uno — sin esto, la validación pasaría y la
  # excepción de PostgreSQL volvería por la puerta de al lado.
  test "el duplicado se detecta sin acentos y sin mayúsculas" do
    agregar "Suma con reagrupación"

    assert_nothing_raised { agregar "suma con reagrupacion" }

    assert_equal 1, indicadores.size
  end

  test "el mismo indicador SÍ puede estar en otra competencia" do
    otra, suya = con_el_colegio(@a.colegio) do
      c = competencia_con(0, "Interpreta gráficos", lapso: @lapso)
      [ c, actividad(@a.escenario, lapso: @lapso, peso: 30, descripcion: "Taller", mide: c) ]
    end
    agregar "Suma con reagrupación"

    agregar "Suma con reagrupación", a: suya, de: otra

    assert_includes con_el_colegio(@a.colegio) { otra.indicators.reload.map(&:descripcion) },
                    "Suma con reagrupación"
  end

  test "vacío no crea nada, y lo dice" do
    agregar ""

    assert_response :unprocessable_entity
    assert_empty indicadores
  end

  test "un indicador de otro colegio no se toca" do
    _, b = dos_colegios_completos(nivel: :primaria)
    sign_in b.profesor

    post competency_indicators_path(@competencia, **@contexto, evaluacion: @evaluacion.id),
         params: { indicator: { descripcion: "Colado" } }

    assert_response :not_found
  end
end
