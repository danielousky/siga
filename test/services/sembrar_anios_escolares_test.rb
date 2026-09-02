require "test_helper"

# Los años escolares de un colegio nuevo, deducidos de la fecha (MOR-208).
#
# Daniel: *«podemos crear el año escolar porque sabemos el día de hoy… y puedo
# incluso crear los anteriores, por lo menos los cuatro»*.
class SembrarAniosEscolaresTest < ActiveSupport::TestCase
  setup do
    @colegio = Current.sin_aislamiento do
      School.create!(name: "U.E. Años", dea_code: "PDANIO#{Process.pid}",
                     entidad_federal: "Lara", municipio: "Iribarren")
    end
  end

  def sembrar(hoy, **opciones)
    con_el_colegio(@colegio) { SembrarAniosEscolares.para(@colegio, hoy: hoy, **opciones) }
  end

  def nombres = con_el_colegio(@colegio) { AcademicPeriod.order(:start_date).pluck(:name) }

  # ⚠️ EL caso que importa, y la trampa que ya apareció tres veces en este
  # proyecto: en agosto el año más nuevo es el que TODAVÍA NO EMPEZÓ. Un colegio
  # que se registra el 10 de agosto está cursando 2025-2026, no 2026-2027.
  test "en agosto el año que encabeza es el que se está cursando" do
    sembrar(Date.new(2026, 8, 10))

    assert_equal "2025-2026", nombres.last,
                 "en agosto todavía no empezó el año que arranca en septiembre"
    assert_not_includes nombres, "2026-2027"
  end

  test "desde septiembre encabeza el año que acaba de empezar" do
    sembrar(Date.new(2026, 9, 20))

    assert_equal "2026-2027", nombres.last
  end

  test "de enero a julio se está cursando el que arrancó en septiembre" do
    sembrar(Date.new(2026, 3, 5))

    assert_equal "2025-2026", nombres.last
  end

  # Cuatro hacia atrás: alcanza para el historial de un bachiller que se está por
  # graduar, y no llena la lista de años vacíos.
  test "siembra cinco años: el que corre y los cuatro anteriores" do
    resultado = sembrar(Date.new(2026, 9, 20))

    assert_equal 5, resultado.creados.size
    assert_equal %w[2022-2023 2023-2024 2024-2025 2025-2026 2026-2027], nombres
  end

  test "cada año nace con sus tres lapsos" do
    resultado = sembrar(Date.new(2026, 9, 20))

    assert_equal 15, resultado.lapsos
    con_el_colegio(@colegio) do
      AcademicPeriod.all.each do |periodo|
        assert_equal 3, periodo.evaluation_moments.count, "#{periodo.name} sin sus lapsos"
      end
    end
  end

  # ⚠️ Las fechas son una AYUDA, no una ley. Daniel: «es un estimado, no una
  # regla inquebrantable que si no la tenemos se cae el mundo».
  test "las fechas salen del modelo, que ya sabe el calendario venezolano" do
    sembrar(Date.new(2026, 9, 20))

    con_el_colegio(@colegio) do
      periodo = AcademicPeriod.find_by(name: "2026-2027")
      assert_equal Date.new(2026, 9, 15), periodo.start_date
      assert_equal Date.new(2027, 7, 31), periodo.end_date
    end
  end

  test "es idempotente" do
    sembrar(Date.new(2026, 9, 20))

    segunda = sembrar(Date.new(2026, 9, 20))

    assert_empty segunda.creados
    assert_equal 0, segunda.lapsos, "ni duplica los lapsos de un año que ya los tiene"
    assert_equal 5, nombres.size
  end

  # ⚠️ Se busca por el AÑO DE INICIO y no por el nombre: un colegio que escribió
  # «2024 - 2025» a mano tiene el mismo año con otro texto, y crear el segundo le
  # dejaría dos años escolares que son el mismo.
  test "no duplica un año que ya existe con otro nombre" do
    con_el_colegio(@colegio) do
      AcademicPeriod.create!(school: @colegio, name: "Año escolar 2024 - 2025",
                             start_date: Date.new(2024, 9, 15), end_date: Date.new(2025, 7, 31))
    end

    sembrar(Date.new(2026, 9, 20))

    # ⚠️ Se cuenta por el AÑO DE INICIO, no por el texto: «2023-2024» también
    # contiene «2024», y contar strings daba un falso positivo.
    inicios = con_el_colegio(@colegio) { AcademicPeriod.pluck(:start_date).map(&:year) }
    assert_equal 1, inicios.count(2024), "«2024 - 2025» y «2024-2025» son el mismo año escolar"
    assert_equal inicios.size, inicios.uniq.size, "no puede haber dos años que empiecen el mismo año"
  end

  # Un colegio que ya tiene su historia no recibe cinco años más.
  test "respeta los años que el colegio ya tenía" do
    sembrar(Date.new(2026, 9, 20))
    antes = con_el_colegio(@colegio) { AcademicPeriod.order(:start_date).pluck(:name, :start_date) }

    sembrar(Date.new(2027, 9, 20))

    assert_equal antes, con_el_colegio(@colegio) {
      AcademicPeriod.where(start_date: ..Date.new(2026, 12, 31)).order(:start_date).pluck(:name, :start_date)
    }
    assert_includes nombres, "2027-2028", "pero sí agrega el nuevo"
  end

  test "se puede pedir otra profundidad" do
    resultado = sembrar(Date.new(2026, 9, 20), hacia_atras: 1)

    assert_equal %w[2025-2026 2026-2027], nombres
    assert_equal 2, resultado.creados.size
  end
end
