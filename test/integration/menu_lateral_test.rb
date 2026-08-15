require "test_helper"

# El menú del administrador (MOR-135).
class MenuLateralTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  # Nueve pantallas quedaron inalcanzables desde un teléfono porque el grupo
  # "Configuración" es un `<details>`, y en el teléfono el menú es una tira que
  # se desliza en horizontal con `overflow-y: hidden`: lo que el `<details>`
  # despliega hacia abajo queda recortado.
  #
  # Por eso el grupo se renderiza DOS veces, y cada forma se apaga en el ancho
  # de la otra. Este test existe para que nadie borre una creyéndola duplicada.
  test "el grupo de configuración se renderiza en sus dos formas" do
    get students_path

    assert_select "details.sidebar-plegable.solo-escritorio", 1,
      "falta la forma plegada de escritorio"
    assert_select ".sidebar-section.solo-telefono", 1,
      "falta la forma plana del teléfono — sin ella, nueve pantallas no se " \
      "alcanzan desde un teléfono"
  end

  test "las dos formas llevan exactamente los mismos enlaces" do
    get students_path

    escritorio = css_select("details.solo-escritorio a").map { |a| a["href"] }
    telefono   = css_select(".solo-telefono a").map { |a| a["href"] }

    assert escritorio.any?, "el grupo de escritorio no trae enlaces"
    assert_equal escritorio, telefono,
      "las dos formas se separaron: salen del mismo parcial, no deberían poder"
  end

  # Un menú que esconde dónde estás parado es peor que uno largo.
  test "el grupo se abre solo cuando la pantalla actual está adentro" do
    get students_path
    assert_select "details.sidebar-plegable:not([open])", 1

    get grades_path
    assert_select "details.sidebar-plegable[open]", 1
  end

  # El corte del menú es por frecuencia de uso, no por modelo de datos.
  test "el día a día va primero y la configuración al final" do
    get students_path

    titulos = css_select(".sidebar-index .sidebar-section-title").map(&:text).map(&:strip)

    assert_equal "Día a día", titulos.first
    assert_includes titulos, "El colegio"
    assert_equal "Configuración", titulos.last
  end
end
