require "application_system_test_case"

# La competencia y sus indicadores, editables donde se leen (9 de septiembre).
#
# Daniel: *«elevar el modelo que aplicamos a evaluaciones a competencias e
# indicadores»*. Misma regla: Enter guarda, Escape descarta, salir guarda — y
# solo si cambió.
#
# ⚠️ Los indicadores van UNO POR UNO, y DENTRO de la evaluación que los mide
# (21 de septiembre). El textarea del formulario completo —uno por línea— se
# retiró: lo que naciera ahí quedaría sin evaluación, o sea sin salir en la
# boleta y sin aparecer en el plan.
class CompetenciaEnLineaSystemTest < ApplicationSystemTestCase
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)
    @competencia = con_el_colegio(@a.colegio) do
      c = competencia_con(0, "Resuelve problemas de adición", lapso: @lapso)
      # ⚠️ Los indicadores cuelgan de la EVALUACIÓN, no de la competencia: sin
      # ella quedan sueltos y la pantalla los dibuja en el bloque de huérfanos,
      # que es de solo lectura — no habría campo que editar.
      examen = actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen", mide: c)
      # ⚠️ El escenario le pone UNO para poder crearla —una evaluación de
      # primaria nace midiendo algo— y acá se cambia por los dos del test, que
      # es lo que hace exactos los conteos de abajo.
      examen.indicators.destroy_all
      examen.indicators.create!(competency: c, descripcion: "Suma con reagrupación", orden: 0)
      examen.indicators.create!(competency: c, descripcion: "Resta con préstamo", orden: 1)
      c
    end
    entrar_como @a.profesor
    visit planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
  end

  def descripcion = find(".plan-competencia-descripcion-campo")
  def indicadores = all(".plan-indicador:not(.plan-indicador--nuevo) .plan-indicador-texto")
  def nuevo       = find(".plan-indicador--nuevo .plan-indicador-texto")
  def recargada   = con_el_colegio(@a.colegio) { @competencia.reload }

  test "el lápiz ya no está: la competencia se edita sola" do
    assert_no_selector ".plan-competencia [aria-label='Editar la competencia']"
    assert_selector ".plan-competencia-descripcion-campo"
  end

  test "cambiar la descripción y salir la guarda" do
    descripcion.set("Resuelve problemas de proporcionalidad")
    find(".plan-ponderacion-titulo").click

    assert_selector ".plan-competencia--guardada", wait: 5
    assert_equal "Resuelve problemas de proporcionalidad", recargada.descripcion
  end

  # ⚠️ El `destroy_all` de los indicadores era INCONDICIONAL, así que una
  # petición con la descripción sola —la que manda la edición en línea— le
  # habría borrado los dos indicadores sin decir nada.
  test "editar la descripción NO se lleva los indicadores por delante" do
    descripcion.set("Otro texto")
    find(".plan-ponderacion-titulo").click

    assert_selector ".plan-competencia--guardada", wait: 5
    assert_equal 2, con_el_colegio(@a.colegio) { recargada.indicators.count }
  end

  test "Escape deja la descripción que había" do
    descripcion.set("Un dedazo")
    descripcion.send_keys(:escape)

    assert_equal "Resuelve problemas de adición", descripcion.value
    assert_equal "Resuelve problemas de adición", recargada.descripcion
  end

  # ── Los indicadores ──────────────────────────────────────────────────────
  test "cada indicador se corrige por su cuenta" do
    indicadores.first.set("Suma con reagrupación de decenas")
    find(".plan-ponderacion-titulo").click

    assert_selector ".plan-competencia--guardada", wait: 5
    con_el_colegio(@a.colegio) do
      assert_equal [ "Suma con reagrupación de decenas", "Resta con préstamo" ],
                   recargada.indicators.en_orden.map(&:descripcion),
                   "el segundo no se toca al corregir el primero"
    end
  end

  # ⚠️ El campo del final va vacío y escribir en él crea el siguiente: es cómo
  # se escribe una lista, y ahorra el botón «agregar» que habría que buscar.
  #
  # ⚠️ Los indicadores se cuentan con `assert_selector … count:`, que ESPERA, y
  # no con `all(…).size`, que mira una sola vez. El que acaba de nacer entra con
  # una animación que arranca en `opacity: 0` (`plan-aparece`), y para Capybara
  # un elemento transparente no está: contando en ese primer cuadro hay DOS.
  #
  #     llega la respuesta ──► 3 filas en la página, la nueva en opacity: 0
  #     all(…).size        ──► 2      si mira en ese cuadro
  #     180 ms después     ──► 3
  #
  # En una máquina rápida no se llega a ver. En GitHub falló dos corridas de
  # cinco con el mismo código, siempre acá: «esperaba 3, vio 2».
  test "escribir en el campo vacío agrega un indicador" do
    assert_selector ".plan-indicador:not(.plan-indicador--nuevo)", count: 2

    nuevo.set("Estima antes de calcular")
    nuevo.send_keys(:enter)

    assert_selector ".plan-competencia--guardada", wait: 5
    assert_selector ".plan-indicador:not(.plan-indicador--nuevo)", count: 3
    con_el_colegio(@a.colegio) do
      assert_equal "Estima antes de calcular", recargada.indicators.en_orden.last.descripcion
    end
  end

  # ⚠️ El campo nuevo nace VACÍO en cada render: si conservara el texto que se
  # acaba de escribir, la respuesta traería el indicador arriba y el texto
  # abajo — y el siguiente Enter lo crearía dos veces.
  test "después de agregar, el campo vacío vuelve a estar vacío" do
    nuevo.set("Estima antes de calcular")
    nuevo.send_keys(:enter)

    assert_selector ".plan-competencia--guardada", wait: 5
    assert_equal "", find(".plan-indicador--nuevo .plan-indicador-texto").value
  end

  # ⚠️ Hay que APUNTAR la línea primero: la × vive en `opacity: 0` hasta el
  # hover —tres indicadores son tres controles compitiendo con su propio texto—
  # y Selenium no hace clic en lo que no ve. Es lo mismo que hace un humano.
  test "la × quita un indicador" do
    fila = all(".plan-indicador:not(.plan-indicador--nuevo)").first
    # ⚠️ Traer la fila a la vista ANTES de apuntarla. Si queda fuera de
    # pantalla, Selenium hace scroll al BUSCAR la × —no al apuntar— y el
    # puntero se queda donde estaba: el `:hover` se pierde, la × vuelve a
    # `opacity: 0` y deja de ser visible a mitad de la búsqueda.
    execute_script("arguments[0].scrollIntoView({ block: 'center' })", fila)
    fila.hover
    fila.find(".plan-indicador-quitar").click

    assert_selector ".plan-competencia--guardada", wait: 5
    con_el_colegio(@a.colegio) do
      assert_equal [ "Resta con préstamo" ], recargada.indicators.en_orden.map(&:descripcion)
    end
  end

  test "vaciar un indicador lo restaura, no lo borra" do
    indicadores.first.set("")
    find(".plan-ponderacion-titulo").click

    assert_equal 2, con_el_colegio(@a.colegio) { recargada.indicators.count },
                 "borrar tiene su × propia, con su tooltip"
  end

  # ⚠️ Daniel: «las competencias e indicadores usualmente son textos largos,
  # párrafos», así que los dos campos son `<textarea>` y crecen con lo escrito.
  # En un `text_field` un párrafo se lee por una ventanita, desplazándolo con el
  # cursor.
  test "un indicador largo se ve entero, no por una ventanita" do
    largo = "Identifica la recta real y ubica en ella los números naturales, los " \
            "enteros y los racionales, reconociendo el orden entre ellos"
    indicadores.first.set(largo)
    find(".plan-ponderacion-titulo").click

    assert_selector ".plan-competencia--guardada", wait: 5
    campo = all(".plan-indicador-texto").first
    assert_equal "textarea", campo.tag_name
    assert_operator campo.evaluate_script("this.offsetHeight"), :>=,
                    campo.evaluate_script("this.scrollHeight"),
                    "el campo se quedó de una línea y recorta el párrafo"
  end

  # Enter sigue guardando: un indicador es una frase, y el salto de línea
  # partiría en dos lo que la boleta imprime como uno.
  test "Enter guarda el indicador en vez de saltar de línea" do
    indicadores.first.set("Suma con reagrupación de decenas")
    indicadores.first.send_keys(:enter)

    assert_selector ".plan-competencia--guardada", wait: 5
    con_el_colegio(@a.colegio) do
      assert_equal "Suma con reagrupación de decenas",
                   recargada.indicators.en_orden.first.descripcion
    end
  end
end
