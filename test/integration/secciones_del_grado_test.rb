require "test_helper"

# Las secciones en la ficha del GRADO: las del año que se está mirando, y
# agregar una sin salir de ahí.
#
# Daniel, en la muestra el 13 de octubre de 2026, tachando la sección de
# 2025-2026 en la ficha de un grado: *«solo van las secciones del período
# seleccionado»* y *«permitir agregar una nueva sección donde sólo preguntas
# el identificador de la sección y la lista de profes para asociarle el profe
# guía»*.
class SeccionesDelGradoTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos
    @viejo = ano_escolar_viejo(@a.escenario, nombre: "2023-2024", seccion: "Z")
    sign_in @a.director
  end

  test "salen solo las secciones del año de la sesión" do
    get grade_path(@a.grado)

    assert_select ".ficha-seccion-nombre", text: "A"
    assert_select ".ficha-seccion-nombre", text: "Z", count: 0
    assert_select ".ficha-situacion", text: /1 sección\s+en 2025-2026/

    post cambiar_anio_escolar_path, params: { id: @viejo.id }
    get grade_path(@a.grado)

    assert_select ".ficha-seccion-nombre", text: "Z"
    assert_select ".ficha-seccion-nombre", text: "A", count: 0
  end

  test "con «Todos los años» salen todas, cada una con su año" do
    post cambiar_anio_escolar_path, params: { id: LlevaElAnioEscolar::TODOS }

    get grade_path(@a.grado)

    assert_select ".ficha-seccion", text: /A.*2025-2026/m
    assert_select ".ficha-seccion", text: /Z.*2023-2024/m
  end

  # ── Agregar una sección desde el grado ─────────────────────────────────────

  test "se agrega con el identificador y el guía, en el año de la sesión" do
    get grade_path(@a.grado)
    # Propone la letra que sigue a la «A» de este año, no a la «Z» del viejo.
    assert_select "form[action='#{grade_sections_path(@a.grado)}'] input[name='section[name]'][value='B']"
    assert_select "form[action='#{grade_sections_path(@a.grado)}'] select[name='section[leader_teacher_id]'] option",
                  text: @a.profesor.apellidos_y_nombres

    assert_difference -> { con_el_colegio(@a.colegio) { Section.count } }, 1 do
      post grade_sections_path(@a.grado), params: { section: { name: "b", leader_teacher_id: @a.registro_de_profesor.id } }
    end

    assert_redirected_to grade_path(@a.grado)
    nueva = con_el_colegio(@a.colegio) { Section.order(:id).last }
    assert_equal [ "B", @a.grado.id, @a.periodo.id, @a.registro_de_profesor.id ],
                 [ nueva.name, nueva.grade_id, nueva.academic_period_id, nueva.leader_teacher_id ]
    assert_equal Section::CUPO_PROPUESTO, nueva.capacity, "el cupo no se preguntó: sale propuesto"
  end

  test "el guía es opcional" do
    post grade_sections_path(@a.grado), params: { section: { name: "C", leader_teacher_id: "" } }

    assert_redirected_to grade_path(@a.grado)
    assert_nil con_el_colegio(@a.colegio) { Section.find_by!(name: "C").leader_teacher_id }
  end

  # Sin año elegido no hay nada que deducir, y preguntarlo sería el tercer
  # campo que Daniel no pidió.
  test "mirando «Todos los años», dice que elija uno en vez de preguntar" do
    post cambiar_anio_escolar_path, params: { id: LlevaElAnioEscolar::TODOS }

    get grade_path(@a.grado)

    assert_select "form[action='#{grade_sections_path(@a.grado)}']", count: 0
    assert_match(/elija arriba el año escolar/, response.body)
  end

  test "un identificador repetido vuelve al grado diciendo por qué" do
    assert_no_difference -> { con_el_colegio(@a.colegio) { Section.count } } do
      post grade_sections_path(@a.grado), params: { section: { name: "a" } }
    end

    assert_redirected_to grade_path(@a.grado)
    assert_match(/No se agregó la sección/, flash[:alert])
  end

  # El grado sale de la URL, y el `default_scope` es el que lo busca: el de
  # otro colegio no existe para este.
  test "no se le agrega una sección al grado de otro colegio" do
    _a, b = dos_colegios_completos

    assert_no_difference -> { Current.sin_aislamiento { Section.unscoped.count } } do
      post grade_sections_path(b.grado), params: { section: { name: "Q" } }
    end
  end

  # ⚠️ El cupo nace propuesto también en el formulario completo. Antes vivía
  # escondido en «Guía, cupo y aula · opcional» y era obligatorio: crear una
  # sección sin abrir ese panel devolvía «Capacidad no puede estar en blanco»
  # de un campo que no se veía.
  test "el formulario completo crea una sección sin tocar el cupo" do
    assert_difference -> { con_el_colegio(@a.colegio) { Section.count } }, 1 do
      post sections_path, params: { section: { name: "D", grade_id: @a.grado.id } }
    end

    assert_equal Section::CUPO_PROPUESTO, con_el_colegio(@a.colegio) { Section.find_by!(name: "D").capacity }
  end
end
