require "application_system_test_case"

# La competencia y sus indicadores, editables donde se leen (9 de septiembre).
#
# Daniel: *«elevar el modelo que aplicamos a evaluaciones a competencias e
# indicadores»*. Misma regla: Enter guarda, Escape descarta, salir guarda — y
# solo si cambió.
#
# ⚠️ Los indicadores van UNO POR UNO. El formulario completo los sigue
# recibiendo juntos —separados por líneas, para escribir el plan de cero o
# pegar los que uno ya tiene— pero eso REEMPLAZA los tres: corregir una tilde
# en el tercero volvía a escribir los otros dos.
class CompetenciaEnLineaSystemTest < ApplicationSystemTestCase
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)
    @competencia = con_el_colegio(@a.colegio) do
      c = competencia_con(0, "Resuelve problemas de adición", lapso: @lapso)
      c.indicators.create!(descripcion: "Suma con reagrupación", orden: 0)
      c.indicators.create!(descripcion: "Resta con préstamo", orden: 1)
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
  test "escribir en el campo vacío agrega un indicador" do
    assert_equal 2, indicadores.size

    nuevo.set("Estima antes de calcular")
    nuevo.send_keys(:enter)

    assert_selector ".plan-competencia--guardada", wait: 5
    assert_equal 3, all(".plan-indicador:not(.plan-indicador--nuevo)").size
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
end
