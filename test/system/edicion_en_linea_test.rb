require "application_system_test_case"

# Editar la evaluación donde se lee (QA del 9 de septiembre).
#
# Daniel: *«para editar dicha evaluación lo haremos desde allí mismo, al hacer
# clic en el elemento que deseo editar, como lo hace Linear»*. Y el lápiz se
# retiró, porque era él lo que confundía: *«pensé que para editar, a juro había
# que hacerlo por esa vía»*.
#
# ⚠️ Todo esto vive en Stimulus y en un turbo_stream, así que se prueba en un
# navegador de verdad: un test de integración ve el HTML inicial —correcto— y
# no ve nada de lo que pasa al escribir, que es lo que se pidió.
class EdicionEnLineaSystemTest < ApplicationSystemTestCase
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)
    @taller = con_el_colegio(@a.colegio) do
      actividad(@a.escenario, lapso: @lapso, peso: 30, descripcion: "Taller en clase")
    end
    entrar_como @a.profesor
    visit planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
  end

  def nombre = find(".plan-evaluacion-nombre-campo")
  def peso   = find(".plan-evaluacion-peso-campo")
  def recargado = con_el_colegio(@a.colegio) { @taller.reload }

  test "el lápiz ya no está: la fila se edita sola" do
    assert_no_selector ".plan-evaluacion [aria-label='Editar la evaluación']"
    assert_selector ".plan-evaluacion-nombre-campo"
    assert_selector ".plan-evaluacion-peso-campo"
  end

  test "cambiar el nombre y salir del campo lo guarda" do
    nombre.set("Taller de mapas")
    find(".plan-ponderacion-titulo").click

    assert_selector ".plan-evaluacion--guardada", wait: 5
    assert_equal "Taller de mapas", recargado.description
  end

  test "Enter guarda sin tener que salir con el ratón" do
    nombre.set("Prueba corta")
    nombre.send_keys(:enter)

    assert_selector ".plan-evaluacion--guardada", wait: 5
    assert_equal "Prueba corta", recargado.description
  end

  # ⚠️ Escape descarta. Sin esto, arrepentirse obliga a acordarse de lo que
  # decía antes y volver a escribirlo.
  test "Escape deja el valor que había" do
    nombre.set("Un dedazo")
    nombre.send_keys(:escape)

    assert_equal "Taller en clase", nombre.value
    assert_equal "Taller en clase", recargado.description
  end

  # Entrar, mirar y salir no es editar: sin esta comprobación, tabular por la
  # fila deja tres guardados y tres líneas en la auditoría de una evaluación
  # que nadie tocó.
  test "salir sin haber cambiado nada no guarda" do
    nombre.click
    find(".plan-ponderacion-titulo").click

    assert_no_selector ".plan-evaluacion--guardada"
  end

  # Vaciar el nombre es un dedazo, no una orden de borrar: eso tiene su botón.
  test "vaciar el nombre lo restaura" do
    nombre.set("")
    find(".plan-ponderacion-titulo").click

    assert_equal "Taller en clase", nombre.value
    assert_equal "Taller en clase", recargado.description
  end

  # ── El porcentaje ────────────────────────────────────────────────────────
  test "el peso se ve entero, sube de uno en uno y guarda al salir" do
    assert_equal "30", peso.value, "«30.0» fue lo que hizo dudar de que fuera editable"
    assert_equal "1", peso[:step]
    assert_equal "1", peso[:min]

    peso.set("45")
    find(".plan-ponderacion-titulo").click

    assert_selector ".plan-evaluacion--guardada", wait: 5
    assert_equal 45, recargado.weight_percentage.to_i
  end

  # ── El calendario ────────────────────────────────────────────────────────
  test "el calendario solo ofrece los meses del año escolar, y sin año" do
    find(".plan-evaluacion-fecha-abrir").click

    meses = all(".plan-calendario-mes").map(&:text)
    assert_equal %w[SEP OCT NOV DIC ENE FEB MAR ABR MAY JUN JUL], meses
    # El año no aparece por ningún lado: ni 2025, ni 2026.
    assert_no_selector ".plan-calendario", text: /20\d\d/
  end

  # ⚠️ Los días de fuera se ven APAGADOS, no se esconden: a un septiembre sin
  # sus primeros catorce días se le lee un agujero, no un año que no empezaba.
  test "los días fuera del año escolar están apagados, no escondidos" do
    find(".plan-evaluacion-fecha-abrir").click
    # El año de prueba arranca el 15 de septiembre: del 1 al 14 no existe.
    find(".plan-calendario-mes", text: "SEP").click

    assert_selector ".plan-calendario-dia--fuera", text: "1"
    assert find(".plan-calendario-dia--fuera", text: "1", match: :first).disabled?
  end

  test "elegir un día lo guarda y cierra el calendario" do
    find(".plan-evaluacion-fecha-abrir").click
    find(".plan-calendario-mes", text: "NOV").click
    find(".plan-calendario-dia", text: "12", match: :first).click

    assert_selector ".plan-evaluacion--guardada", wait: 5
    assert_equal 11, recargado.date_scheduled.month
    assert_equal 12, recargado.date_scheduled.day
  end

  # ⚠️ No hay «Quitar la fecha»: el modelo la exige, y el botón habría fallado
  # siempre. Es el mismo error que el aviso de borrar que prometía llevarse las
  # notas — ofrecer lo que el modelo va a rechazar es peor que no ofrecerlo.
  test "no se ofrece quitar la fecha, porque el modelo la exige" do
    find(".plan-evaluacion-fecha-abrir").click

    assert_no_text "Quitar la fecha"
  end

  # ⚠️ El atajo «Hoy» solo aparece si hoy CAE DENTRO del año escolar. En agosto
  # —entre dos años— un botón «Hoy» que no se puede pulsar es peor que no
  # tenerlo: promete un atajo y da un día que el calendario rechaza.
  test "el atajo de hoy se esconde cuando hoy cae fuera del año escolar" do
    find(".plan-evaluacion-fecha-abrir").click

    # El año de prueba va del 15/9/2025 al 31/7/2026, y hoy no está ahí.
    assert_no_selector ".plan-calendario-atajo", text: /Hoy/
  end

  # ⚠️ Se mueve el AÑO ESCOLAR, no el reloj: `travel_to` no alcanza al navegador
  # —el calendario pregunta la fecha con `new Date()` del lado del cliente— así
  # que un test que viaje en el tiempo en Ruby prueba otra cosa.
  test "dentro del año escolar, el atajo lleva al día de hoy" do
    con_el_colegio(@a.colegio) do
      @a.seccion.academic_period.update!(start_date: Date.current - 2.months,
                                         end_date: Date.current + 6.months)
    end
    visit planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
    find(".plan-evaluacion-fecha-abrir").click

    mes = I18n.l(Date.current, format: "%b").downcase.delete(".")
    assert_selector ".plan-calendario-atajo", text: "Hoy · #{Date.current.day} #{mes}"
    find(".plan-calendario-atajo", text: "Hoy").click

    assert_selector ".plan-evaluacion--guardada", wait: 5
    assert_equal Date.current, recargado.date_scheduled
  end

  # ── Lo que se vio en pantalla el 9 de septiembre ──────────────────────────
  #
  # ⚠️ Sin `flex-wrap`, los chips de «qué mide» piden `flex: 1 0 100%`, ese
  # 100 % no puede bajar de renglón, se queda en la misma línea y COMPRIME al
  # nombre —que lleva `min-width: 0`— hasta dejarlo en diez píxeles. El campo no
  # se veía vacío: se veía roto.
  test "el nombre conserva un ancho legible al lado de sus chips" do
    otra = con_el_colegio(@a.colegio) { competencia_con(1, "Interpreta gráficos", lapso: @lapso) }
    con_el_colegio(@a.colegio) { @taller.competencies = [ otra ] }
    visit planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)

    assert_operator nombre.evaluate_script("this.offsetWidth"), :>, 120,
                    "el campo del nombre quedó aplastado por los chips"
  end

  # ⚠️ La fila que vuelve por turbo_stream tiene que saber bajo QUÉ competencia
  # está dibujada. Sin eso su chip repite la de arriba —«mide ⟨esta⟩ ⟨la otra⟩»
  # en vez de «también mide ⟨la otra⟩»— y una fila recién guardada dice distinto
  # que sus vecinas.
  test "al guardar, el chip sigue nombrando la OTRA competencia" do
    otra = con_el_colegio(@a.colegio) { competencia_con(1, "Interpreta gráficos", lapso: @lapso) }
    propia = con_el_colegio(@a.colegio) { competencia_con(1, "Resuelve problemas", lapso: @lapso) }
    con_el_colegio(@a.colegio) { @taller.competencies = [ propia, otra ] }
    visit planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)

    # ⚠️ Por el TÍTULO de la competencia, no por el texto de la tarjeta: el chip
    # de la otra también nombra «Resuelve problemas», así que buscar por texto
    # encuentra las dos.
    def bloque_de(titulo)
      all(".plan-competencia").find { |c| c.find(".plan-competencia-descripcion-campo").value == titulo }
    end

    bloque_de("Resuelve problemas").find(".plan-evaluacion-nombre-campo").set("Taller corregido")
    find(".plan-ponderacion-titulo").click

    assert_selector ".plan-evaluacion--guardada", wait: 5
    assert_equal "también mide",
                 bloque_de("Resuelve problemas").find(".plan-evaluacion-chips-etiqueta").text
  end
end
