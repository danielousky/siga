require "test_helper"

# El año escolar venezolano se deduce de un número (MOR-163).
#
# ## Por qué
#
# Va de mediados de septiembre a finales de julio. **Todos.** Daniel: «eso es
# así cada año, no hace falta preguntar; ni en los peores años algo diferente».
#
# El formulario pedía tres campos —nombre, fecha de inicio, fecha de fin— y
# aceptaba «Año escolar 2026-2027» con las fechas en blanco: un año sin
# duración. Ahora se elige el año que empieza y sale todo.
class AnioEscolarTest < ActiveSupport::TestCase
  # ⚠️ Un colegio VACÍO: `escenario_academico` ya trae un año con sus lapsos, y
  # borrarlo choca contra la clave foránea de `evaluation_moments`. Acá lo que se
  # prueba es el arranque desde cero, que es el caso real.
  setup do
    @colegio = School.create!(name: "Colegio del Calendario",
                              dea_code: "CAL-#{Process.pid}", location: "Caracas")
  end

  test "de un número salen el nombre y las dos fechas" do
    con_el_colegio(@colegio) do
      periodo = AcademicPeriod.para_el_anio(2026)

      assert_equal "2026-2027", periodo.name
      assert_equal Date.new(2026, 9, 15), periodo.start_date
      assert_equal Date.new(2027, 7, 31), periodo.end_date
      assert periodo.valid?
    end
  end

  # «Si ya tengo el del 2025, puedo tranquilamente deducir el siguiente, que
  # es… exacto, 2026» — Daniel.
  test "el próximo año sale del último que tiene el colegio" do
    con_el_colegio(@colegio) do
      AcademicPeriod.para_el_anio(2025).save!

      assert_equal 2026, AcademicPeriod.proximo_anio
    end
  end

  # Un colegio sin ningún año escolar: el que se está cursando hoy. De enero a
  # julio todavía corre el que empezó el septiembre anterior.
  test "sin años cargados propone el que se está cursando" do
    con_el_colegio(@colegio) do
      assert_equal 2026, AcademicPeriod.proximo_anio(Date.new(2026, 10, 5))
      assert_equal 2025, AcademicPeriod.proximo_anio(Date.new(2026, 3, 5)),
                   "en marzo todavía se cursa el año que empezó en septiembre"
    end
  end

  # ⚠️ El importador tenía su PROPIA copia de estas fechas. Dos lugares que
  # arman un año escolar son dos calendarios que se despegan.
  test "el nombre de una planilla se reconoce venga como venga" do
    assert_equal 2023, AcademicPeriod.anio_de("2023-2024")
    assert_equal 2023, AcademicPeriod.anio_de("Año escolar 2023-2024")
    assert_nil AcademicPeriod.anio_de("basura")
    assert_nil AcademicPeriod.anio_de("3er Año"), "un grado no es un año escolar"
  end

  test "los años que se ofrecen alcanzan el historial y el que viene" do
    anios = AcademicPeriod.anios_elegibles(Date.new(2026, 8, 31))

    assert_equal 2027, anios.first, "el primero es el que se va a planificar"
    assert_includes anios, 2014, "tiene que alcanzar el historial que un colegio importe"
    assert_equal anios, anios.sort.reverse, "del más nuevo al más viejo"
  end
end
