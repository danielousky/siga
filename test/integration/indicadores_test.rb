require "test_helper"

# Los indicadores, uno por uno (QA del 9 de septiembre).
class IndicadoresTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)
    @contexto = { asignacion: "#{@a.seccion.id}:#{@a.escenario.materia.id}", lapso: @lapso.id }
    @competencia = con_el_colegio(@a.colegio) { competencia_con(0, "Resuelve problemas", lapso: @lapso) }
    sign_in @a.profesor
  end

  def agregar(texto)
    post competency_indicators_path(@competencia, **@contexto),
         params: { indicator: { descripcion: texto } },
         headers: { "Turbo-Frame" => "plan" }
  end

  def indicadores = con_el_colegio(@a.colegio) { @competencia.indicators.en_orden.map(&:descripcion) }

  test "se agregan en orden" do
    agregar "Suma con reagrupación"
    agregar "Resta con préstamo"

    assert_equal [ "Suma con reagrupación", "Resta con préstamo" ], indicadores
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
    otra = con_el_colegio(@a.colegio) { competencia_con(0, "Interpreta gráficos", lapso: @lapso) }
    agregar "Suma con reagrupación"

    post competency_indicators_path(otra, **@contexto),
         params: { indicator: { descripcion: "Suma con reagrupación" } },
         headers: { "Turbo-Frame" => "plan" }

    assert_equal 1, con_el_colegio(@a.colegio) { otra.indicators.count }
  end

  test "vacío no crea nada, y lo dice" do
    agregar ""

    assert_response :unprocessable_entity
    assert_empty indicadores
  end

  test "un indicador de otro colegio no se toca" do
    ajena = con_el_colegio(@a.colegio) { competencia_con(0, "Del colegio A", lapso: @lapso) }
    _, b = dos_colegios_completos(nivel: :primaria)
    sign_in b.profesor

    post competency_indicators_path(ajena, **@contexto),
         params: { indicator: { descripcion: "Colado" } }

    assert_response :not_found
  end
end
