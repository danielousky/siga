require "test_helper"

# La pestaña «Horario» de la sección (spec `horarios`, decisión 29). Daniel, el
# 23 de octubre de 2026: *«la pestaña horario va a la sección»*.
#
# Es la MISMA pantalla que Académico ▸ Horarios, y lo que se toca en ella
# vuelve a ella: si volviera a «Horarios», el director saldría de la sección en
# la que estaba trabajando, y Turbo escribiría en el marco la otra puerta, con
# su selector de secciones adentro. Ninguna de las dos cosas falla: se ven.
#
# ⚠️ `sign_in` lo consume la PRIMERA petición, y una que termina en 404 no
# guarda la sesión: lo que da 404 va al final de cada test.
class LaPestanaHorarioTest < ActionDispatch::IntegrationTest
  # Un lunes de clases del año de los escenarios: un año terminado no se arma.
  setup { travel_to Time.zone.local(2026, 3, 2, 10, 0) }

  setup do
    @a, @b = dos_colegios_completos
    @seccion = @a.seccion
    @mat = @a.materia
  end

  def en_a(&) = con_el_colegio(@a.colegio, &)
  def hora(numero) = en_a { @seccion.reload.bell_schedule.horas_de_clase[numero - 1] }
  def mensaje = css_select(".horario-mensaje p").first&.text.to_s.squish
  def pestana = horario_section_path(@seccion)

  def armar_desde_la_pestana
    sign_in @a.director
    post armar_horarios_path(seccion: @seccion.id, desde: "seccion")
  end

  def ubicar_desde_la_pestana(dia:, hora:)
    post section_lessons_path(@seccion), params: { subject_id: @mat.id, dia: dia, time_slot_id: self.hora(hora).id,
                                                   desde: "seccion" }
  end

  test "es la última pestaña de la sección, y dibuja la misma semana con su marco" do
    sign_in @a.director
    get pestana

    assert_response :success
    assert_equal "Horario", css_select(".pestana").map { |p| p.text.squish }.last
    assert_select ".pestana.activa", text: "Horario"
    assert_select "turbo-frame#horario .horario-titulo", text: /Horario/
    assert_select "turbo-frame#horario .horario-hora-tiempo", text: "7:10 – 7:50"
    # La sección ya la dice la pestaña: sin el selector de la otra puerta.
    assert_select ".horario-selector", 0
    # Y es la semana de TODAS sus áreas: el título no nombra una.
    assert_select ".cabecera-de-lista-titulo", text: /\A\s*1er Año · Sección A\s*\z/
  end

  test "armar desde la pestaña vuelve a la pestaña: ubicar, quitar, la carga y el timbre" do
    armar_desde_la_pestana
    assert_redirected_to horario_section_path(@seccion, armar: 1, area: @mat.id)

    ubicar_desde_la_pestana(dia: 1, hora: 1)
    assert_redirected_to horario_section_path(@seccion, armar: 1, area: @mat.id)
    follow_redirect!
    assert_equal "Listo: Matemática el lunes de 7:10 a 8:30. Van 2 de 4.", mensaje

    # Lo que hay en el marco lleva de vuelta aquí, no a «Horarios».
    assert_select "form.horario-libre-form input[name=desde][value=seccion]"
    assert_select "form.horario-quitar-form[action*='desde=seccion']"
    assert_select "a.horario-ficha[href^='#{pestana}']"
    assert_select "turbo-frame#horario a[href^='#{horarios_path}']", 0

    clase = en_a { Lesson.where(section: @seccion).first }
    delete section_lesson_path(@seccion, clase, desde: "seccion")
    assert_redirected_to horario_section_path(@seccion, armar: 1, area: @mat.id)

    grado = en_a { GradeSubject.find_by!(grade: @a.grado, subject: @mat) }
    patch carga_horarios_path(seccion: @seccion.id, grade_subject_id: grado.id, delta: 1, desde: "seccion")
    assert_redirected_to horario_section_path(@seccion, armar: 1, area: @mat.id)

    primera = hora(1)
    patch bell_schedule_time_slot_path(primera.bell_schedule_id, primera),
          params: { time_slot: { desde: "07:05", hasta: "07:50" }, seccion: @seccion.id, area: @mat.id, desde: "seccion" }
    assert_redirected_to horario_section_path(@seccion, armar: 1, area: @mat.id)
  end

  test "publicar desde la pestaña vuelve a la pestaña, y lo cuenta" do
    armar_desde_la_pestana
    ubicar_desde_la_pestana(dia: 1, hora: 1)

    patch publicar_horarios_path(seccion: @seccion.id, desde: "seccion")

    assert_redirected_to pestana
    follow_redirect!
    assert_match "1er Año A quedó publicado", mensaje
    assert_select ".horario-titulo .estado", text: "Publicado"
  end

  # Decisión 13: el profesor ve lo publicado. Y no arma (decisión 18).
  test "el profesor que dicta en la sección la ve publicada, y sin botones" do
    armar_desde_la_pestana
    ubicar_desde_la_pestana(dia: 1, hora: 1)

    sign_in @a.profesor
    get pestana
    assert_response :success
    assert_select ".empty-state", text: /Todavía sin publicar/
    assert_select ".horario-clase", 0

    sign_in @a.director
    patch publicar_horarios_path(seccion: @seccion.id, desde: "seccion")

    sign_in @a.profesor
    get pestana
    assert_select ".horario-rejilla .horario-clase", 1 # el bloque de 80 minutos, unido
    assert_select "form[action^='#{armar_horarios_path}']", 0
    assert_select "form[action^='#{publicar_horarios_path}']", 0
    assert_select "a[href=?][target=_blank]", horario_section_path(@seccion, format: :pdf)
  end

  # Decisión 14: Inicial no tiene horario, ni en la sección ni en la ficha.
  test "Inicial no tiene pestaña de horario" do
    jardin = escenario_academico(nombre: "Jardín", nivel: :preescolar)
    directora = con_el_colegio(jardin.colegio) do
      usuario("dir", jardin.colegio.id).tap { |u| Admin.create!(user: u, school: jardin.colegio, role: :director) }
    end
    sign_in directora

    get alumnos_section_path(jardin.seccion)
    assert_not_includes css_select(".pestana").map { |p| p.text.squish }, "Horario"

    get student_path(jardin.alumno)
    assert_select "a[href=?]", horario_section_path(jardin.seccion), 0

    get horario_section_path(jardin.seccion)
    assert_redirected_to alumnos_section_path(jardin.seccion)
  end

  test "la ficha del alumno lleva al horario de su sección" do
    sign_in @a.director
    get student_path(@a.alumno)

    assert_select "a[href=?]", pestana, text: /Horario/
  end

  test "otro colegio no la ve" do
    sign_in @b.director
    get pestana

    assert_response :not_found
  end
end
