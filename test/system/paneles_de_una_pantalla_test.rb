require "application_system_test_case"

# Los paneles con pestañas (MOR-223).
#
# Daniel: *«esos dos paneles van en pestañas o pills, un clic vale más que
# muchos scroll hacia abajo… si no lo hago me pierdo de lo que está allí que no
# me aparece al cargar la vista»*.
#
# ## Por qué esto necesita un navegador de verdad
#
# El contenido de los tres paneles está en el HTML desde el primer momento: lo
# que cambia es cuál se VE, y eso lo decide Stimulus. Un test de integración
# encontraría los tres y pasaría con el JavaScript roto.
class PanelesDeUnaPantallaTest < ApplicationSystemTestCase
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    con_el_colegio(@a.colegio) do
      otra = Subject.create!(department: @a.escenario.materia.department,
                             code: "LEN", name: "Castellano y Literatura")
      GradeSubject.create!(grade: @a.grado, subject: otra)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: @a.seccion, subject: otra)
    end
    entrar_como @a.profesor
  end

  # ⚠️ Los ALUMNOS primero. Daniel: *«ten presente que lo más importante para
  # los profesores son sus estudiantes»*.
  test "al abrir se ven los alumnos, no lo que se escribió primero" do
    visit section_path(@a.seccion)

    assert_selector ".panel-pestana.activa", text: "Alumnos"
    assert_selector ".panel-contenido[data-panel='alumnos']", visible: true
    assert_no_selector ".panel-contenido[data-panel='areas']", visible: true
  end

  test "un clic cambia de panel, sin recargar" do
    visit section_path(@a.seccion)
    tocando { find(".panel-pestana", text: Vocabulario::AREAS_CORTAS).click }

    assert_selector ".panel-contenido[data-panel='areas']", visible: true
    assert_no_selector ".panel-contenido[data-panel='alumnos']", visible: true
    assert_text "Castellano y Literatura"
  end

  # ⚠️ El conteo va en la pestaña para no tener que entrar a contar. Es lo que
  # convierte una pestaña en información: «Alumnos 2» ya dice algo.
  test "cada pestaña trae su conteo" do
    visit section_path(@a.seccion)

    assert_selector ".panel-pestana", text: "Alumnos"
    assert_selector ".panel-insignia", text: @a.seccion.enrollments.count.to_s
  end

  # ⚠️ Se degrada, no se rompe. Todos los paneles vienen en el HTML y los
  # esconde el CONTROLADOR: si Stimulus no carga —y una aplicación entera ya
  # murió una vez en este proyecto por un import roto— la pantalla vuelve a ser
  # lo que era, apilada y con scroll. Nunca una pantalla vacía.
  test "sin JavaScript, el contenido sigue estando" do
    visit section_path(@a.seccion)
    page.execute_script(<<~JS)
      document.querySelectorAll("[data-panel]").forEach((p) => { p.hidden = false })
    JS

    assert_text "Castellano y Literatura"
    assert_selector ".panel-contenido[data-panel='alumnos']", visible: true
    assert_selector ".panel-contenido[data-panel='areas']", visible: true
  end
end
