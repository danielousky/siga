require "test_helper"

# Las CUATRO planillas que se guardan campo por campo, y el contrato que ahora
# comparten: notas, reparaciones, informes descriptivos y Educación Inicial.
#
#     escribir  ──►  salir del campo  ──►  Turbo Stream  ──►  ✓ y el contador
#
# Eran tres transportes —dos JSON escritos a mano con su `fetch`, y un frame que
# se redibujaba entero— para la MISMA interacción, y el mismo profesor las cruza
# en la misma tarde.
class PlanillasQueSeGuardanSolasTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(alumnos: 3)
    con_el_colegio(@esc.colegio) do
      @garcia = profesor_de(@esc.materia, @esc.seccion, "garcia")
      @examen = actividad(@esc, lapso: @esc.lapso(1), peso: 100, descripcion: "Examen")
    end
    sign_in @garcia
  end

  # ── ⚠️ El `id` repetido: la trampa que costó una hora ─────────────────────
  #
  # `number_field_tag :score` le pone `id="score"` a los TREINTA campos. Además
  # de ser HTML inválido, Turbo vuelve a enfocar por `id` después de pintar un
  # stream —para no perder el foco si el elemento enfocado fue reemplazado— y
  # `getElementById` devuelve SIEMPRE el primero de la página.
  #
  # El síntoma no se parece a la causa: Enter saltaba al alumno siguiente y el
  # foco volvía solo al PRIMERO de la lista. Nada falla, nada se registra.
  test "ningún id se repite dentro de una planilla" do
    get evaluation_activity_notas_path(@examen)

    ids = css_select("[data-controller~=planilla] [id]").map { |e| e["id"] }
    repetidos = ids.tally.select { |_, veces| veces > 1 }.keys

    assert_empty repetidos,
                 # Turbo re-enfoca por id tras el stream y agarra siempre el primero.
                 "ids repetidos: #{repetidos.join(', ')}"
  end

  # ── La respuesta ──────────────────────────────────────────────────────────

  # ⚠️ Nunca la lista entera. Reemplazar las treinta filas en cada tecla se
  # lleva el foco del campo siguiente, que es lo que hace usable la pantalla.
  test "la respuesta toca la marca y el contador, y nada más" do
    patch evaluation_activity_nota_path(@examen, @esc.alumno(1).id),
          params: { score: "18" }, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream", 2
    assert_select "turbo-stream[action=replace][target=?]", "estado_#{@esc.alumno(1).id}"
    assert_select "turbo-stream[action=replace][target=?]", "progreso_de_la_planilla"
    # Ni un campo: la lista no se redibuja.
    assert_select "turbo-stream template input", count: 0
  end

  # ⚠️ El motivo va en la MARCA de esa fila, no en un aviso arriba: en una
  # planilla de treinta, «no se pudo guardar» sin decir a quién obliga a
  # revisarlos uno por uno.
  test "el rechazo dice por qué, en la fila que falló" do
    patch evaluation_activity_nota_path(@examen, @esc.alumno(1).id),
          params: { score: "25" }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[target=?]", "estado_#{@esc.alumno(1).id}" do
      assert_select "template .planilla-estado[data-estado=?]", "rechazado"
    end
  end

  # ── Las cuatro dicen lo mismo ─────────────────────────────────────────────

  # ⚠️ La marca la pinta el SERVIDOR, que es quien sabe la respuesta. Antes eran
  # tres formas de decirlo: un símbolo en notas, una palabra en informes y un
  # destello verde en Inicial.
  test "las cuatro planillas usan la misma marca" do
    get evaluation_activity_notas_path(@examen)
    assert_select ".planilla-estado", 3

    # ⚠️ La de informes la abre la DIRECCIÓN o el guía, no cualquier profesor.
    sign_in director_del_colegio
    get section_informes_path(@esc.seccion, lapso: @esc.lapso(1).id)

    assert_response :success
    assert_select ".planilla-estado", 3
  end

  # Y el mismo guardado incremental, sin botón: son hasta noventa campos por
  # lapso, y un «Guardar» al final pierde una hora de trabajo (MOR-95).
  test "ninguna planilla tiene botón de guardar" do
    get evaluation_activity_notas_path(@examen)

    assert_select "[data-controller~=planilla] input[type=submit]", count: 0
    assert_select "[data-controller~=planilla] button[type=submit]", count: 0
  end

  private

  def director_del_colegio
    con_el_colegio(@esc.colegio) do
      usuario = User.create!(first_name: "Dire", last_name: "Ctora",
                             email: "dire.#{@esc.colegio.id}@planillas.test", password: "123123",
                             document: "V-#{@esc.colegio.id}42")
      Admin.create!(user: usuario, school: @esc.colegio, role: :director)
      usuario
    end
  end

  def profesor_de(materia, seccion, apellido)
    usuario = User.create!(first_name: "Prof", last_name: apellido.capitalize,
                           email: "#{apellido}.#{seccion.id}@planillas.test", password: "123123",
                           document: "V-#{apellido.bytes.sum}#{seccion.id}")
    docente = Teacher.create!(user: usuario, school: @esc.colegio)
    TeacherSection.create!(teacher: docente, section: seccion, subject: materia)
    usuario
  end
end
