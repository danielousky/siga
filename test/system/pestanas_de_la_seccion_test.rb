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

  # ⚠️ Asistencia e Informes son las dos del GUÍA, y aparecen juntas: quien pasa
  # lista de esos alumnos es quien los ve enteros, y por eso es quien escribe el
  # informe descriptivo. Un profesor que solo dicta un área no ve ninguna de las
  # dos.
  test "el orden es el del ciclo, y las del guía solo aparecen para el guía" do
    visit section_path(@a.seccion, area: @area.id)

    assert_equal [ "Calificar", "Plan de Evaluación", "Alumnos" ],
                 all(".pestana").map(&:text)

    con_el_colegio(@a.colegio) { @a.seccion.update!(leader_teacher: @a.registro_de_profesor) }
    visit section_path(@a.seccion, area: @area.id)

    assert_equal [ "Asistencia", "Calificar", "Plan de Evaluación", "Informes", "Alumnos" ],
                 all(".pestana").map(&:text)
  end

  # ⚠️ Cada pestaña es un ENLACE con su URL: la secretaria manda «mira esto» por
  # WhatsApp y el botón de atrás tiene que volver a la anterior.
  test "cambiar de pestaña cambia la URL" do
    visit section_path(@a.seccion, area: @area.id)
    # ⚠️ El clic se REINTENTA hasta llegar: Turbo se traga el que cae mientras
    # hidrata y Selenium reporta éxito igual. Ver `tocar_para_ir_a`.
    tocar_para_ir_a(alumnos_section_path(@a.seccion)) { click_on "Alumnos" }

    assert_current_path alumnos_section_path(@a.seccion, area: @area.id)
    assert_selector ".pestana.activa", text: "Alumnos"

    page.go_back
    assert_selector ".pestana.activa", text: "Calificar"
  end

  # El área viaja en todas las pestañas: es lo que el árbol del menú trajo, y
  # perderla al cambiar de vista obligaría a elegirla de nuevo.
  test "el área se conserva al moverse entre pestañas" do
    visit section_path(@a.seccion, area: @area.id)

    all(".pestana").each { |p| assert_includes p[:href], "area=#{@area.id}" }
  end

  # ⚠️ NINGUNA pestaña saca al profesor de la sección.
  #
  # Daniel: *«no me gustan ni Asistencia ni Planificación como URL, se
  # descontextualiza todo… no es solo "fingir" sino realmente estar en la
  # sección»*. Las cuatro son acciones de `SectionsController`.
  test "las cuatro pestañas se quedan dentro de la sección" do
    con_el_colegio(@a.colegio) { @a.seccion.update!(leader_teacher: @a.registro_de_profesor) }
    visit section_path(@a.seccion, area: @area.id)

    all(".pestana").each do |pestana|
      assert_includes pestana[:href], "/secciones/#{@a.seccion.id}"
    end
  end

  # Y al entrar en ellas, el encabezado y la fila siguen ahí.
  test "planificar y asistencia conservan el encabezado de la sección" do
    con_el_colegio(@a.colegio) { @a.seccion.update!(leader_teacher: @a.registro_de_profesor) }
    visit section_path(@a.seccion, area: @area.id)

    [ [ "Plan de Evaluación", :planificar_section_path ], [ "Asistencia", :asistencia_section_path ] ].each do |nombre, ruta|
      # ⚠️ Se ESPERA a estar en la sección antes de tocar la pestaña.
      #
      # `click_on` espera a que el enlace exista, pero en la segunda vuelta el
      # que existe puede ser el de la página ANTERIOR: Capybara lo toca, Turbo
      # reemplaza el DOM debajo, y la navegación se pierde. El síntoma era
      # `expected "/secciones/4328" to equal "/secciones/4328/planificar"` —
      # la URL nunca cambió porque nadie llegó a pulsar nada.
      en_la_seccion
      # ⚠️ La URL PRIMERO, y el clic se REINTENTA hasta llegar: Turbo se traga
      # el clic que cae mientras hidrata, y Selenium reporta éxito igual. Ver
      # `tocar_para_ir_a`.
      tocar_para_ir_a(send(ruta, @a.seccion)) { click_on nombre }
      assert_selector ".pestana.activa", text: nombre
      assert_selector ".cabecera-de-lista-titulo", text: /#{@a.seccion.grade.name}/
      assert_selector ".detail-label", text: "PROFESOR GUÍA"
    end
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

  # ⚠️ Entrando por «Soy guía de» la URL NO trae área —la asistencia es de la
  # sección entera— y las cuatro pestañas tienen que funcionar igual.
  #
  # Daniel: *«cuando intenté entrar en el enlace de planificación me devuelve y
  # me sale el error: Elige primero un área»*. La libreta deducía la primera y
  # «Planificar» no: dos deducciones paralelas para la misma pregunta.
  test "sin área en la URL, planificar abre igual" do
    con_el_colegio(@a.colegio) { @a.seccion.update!(leader_teacher: @a.registro_de_profesor) }
    visit section_path(@a.seccion)
    en_la_seccion(area: nil)

    tocar_para_ir_a(planificar_section_path(@a.seccion)) { click_on "Plan de Evaluación" }
    assert_selector ".pestana.activa", text: "Plan de Evaluación"
    assert_no_text "Elige primero un área"
  end

  private

  # La sección, asentada: estamos en su URL y su fila de pestañas ya está
  # dibujada. Es la precondición de cualquier `click_on` de este archivo.
  # ⚠️ Con los DOS ayudantes de `ApplicationSystemTestCase`, que es lo que a este
  # archivo le faltaba: `tocando` absorbe el clic que llega mientras el
  # documento cambia, y `esperando_la_pagina` evita que la línea siguiente
  # pregunte por un DOM a medio instalar. Son las dos mitades del mismo
  # problema, y con una sola el error se mueve de sitio en vez de irse.
  def en_la_seccion(area: @area.id)
    visit section_path(@a.seccion, area: area) unless current_path == section_path(@a.seccion)
    esperando_la_pagina
    assert_current_path section_path(@a.seccion), ignore_query: true
    assert_selector ".pestana", minimum: 3
  end
end
