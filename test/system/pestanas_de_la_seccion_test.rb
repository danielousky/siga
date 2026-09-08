require "application_system_test_case"

# Las cuatro vistas de una sección (etapa ③).
#
# Daniel fijó el orden —**Asistencia · Calificar · Planificar · Alumnos**— y de
# ahí notó la consecuencia que no había visto: *«no había pensado en la pestaña
# de default»*. La primera es la que abre, y quien entra por «Dicto › Matemática
# › 4to A» no viene a pasar lista, viene a calificar esa área.
#
# ## ⚠️ Por qué reemplazó a `paneles_de_una_pantalla_test`
#
# Antes eran paneles que alternaban con `hidden`: los tres contenidos venían en
# el HTML y Stimulus decidía cuál se veía. Pasaron a pestañas con URL propia
# porque asistencia y planificar son pantallas de verdad, con su controller y su
# formulario — y media fila que navega y media que alterna no se le puede
# explicar a nadie: el botón de atrás funcionaría en unas y en otras no.
class PestanasDeLaSeccionTest < ApplicationSystemTestCase
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @area = @a.escenario.materia
    entrar_como @a.profesor
  end

  test "el orden es el del ciclo, y Asistencia solo aparece para el guía" do
    visit section_path(@a.seccion, area: @area.id)

    assert_equal [ "Calificar", "Planificar", "Alumnos" ],
                 all(".pestana").map(&:text)

    con_el_colegio(@a.colegio) { @a.seccion.update!(leader_teacher: @a.registro_de_profesor) }
    visit section_path(@a.seccion, area: @area.id)

    assert_equal [ "Asistencia", "Calificar", "Planificar", "Alumnos" ],
                 all(".pestana").map(&:text)
  end

  # ⚠️ Cada pestaña es un ENLACE con su URL: la secretaria manda «mira esto» por
  # WhatsApp y el botón de atrás tiene que volver a la anterior.
  test "cambiar de pestaña cambia la URL" do
    visit section_path(@a.seccion, area: @area.id)
    click_on "Alumnos"

    assert_current_path alumnos_section_path(@a.seccion, area: @area.id)
    assert_selector ".pestana.activa", text: "Alumnos"

    page.go_back
    assert_selector ".pestana.activa", text: "Calificar"
  end

  # El área viaja en todas las pestañas: es lo que el árbol del menú trajo, y
  # perderla al cambiar de vista obligaría a elegirla de nuevo.
  test "el área se conserva al moverse entre pestañas" do
    visit section_path(@a.seccion, area: @area.id)

    all(".pestana").each do |pestana|
      next if pestana[:href].include?("/competencias")

      assert_includes pestana[:href], "area=#{@area.id}"
    end
  end

  # ⚠️ «Planificar» lleva al plan de ESTA área en ESTA sección, no al listado:
  # la planificación es de una asignación, no de una sección.
  test "planificar lleva al plan de esta asignación" do
    visit section_path(@a.seccion, area: @area.id)

    destino = find(".pestana", text: "Planificar")[:href]

    assert_includes destino, "/competencias"
    assert_includes destino, CGI.escape("#{@a.seccion.id}:#{@area.id}")
  end

  # El encabezado es el mismo en las dos pantallas de la sección: una fila de
  # pestañas que desaparece al tocarla no es una fila de pestañas.
  test "los datos de la sección se ven en las dos pestañas" do
    [ section_path(@a.seccion, area: @area.id),
      alumnos_section_path(@a.seccion, area: @area.id) ].each do |ruta|
      visit ruta

      # ⚠️ Por el SELECTOR y no por el texto: `.detail-label` lleva
      # `text-transform: uppercase`, y Capybara compara lo RENDERIZADO — así
      # que «Profesor guía» nunca coincide, aunque esté en el HTML.
      assert_selector ".detail-label", text: "PROFESOR GUÍA"
      assert_text @a.seccion.academic_period.name
      assert_selector ".pestana", count: 3
    end
  end
end
