require "test_helper"

# El horario en papel (spec `horarios`, decisión 27): la hoja de una sección y
# la de un profesor, LEÍDAS —no pesadas—. Ver `LeePdf`: un PDF que pesa más de
# mil bytes también puede salir sin la mitad de lo que tenía que decir.
#
# ⚠️ `sign_in` lo consume la PRIMERA petición, y una que termina en 404 no
# guarda la sesión: lo que da 404 va al final de cada test.
class HorarioEnPdfTest < ActionDispatch::IntegrationTest
  include LeePdf

  # Un lunes de clases del año de los escenarios: un año terminado no se arma.
  setup { travel_to Time.zone.local(2026, 3, 2, 10, 0) }

  setup do
    @a, = dos_colegios_completos
    @seccion = @a.seccion
    @mat = @a.materia
    @garcia = @a.registro_de_profesor
  end

  def en_a(&) = con_el_colegio(@a.colegio, &)
  def apellido = en_a { ChoquesDeHorario.apellido_de(@garcia) }

  # El lunes de 7:10 a 8:30: un bloque de 80 minutos, dos clases.
  def armar_un_bloque(colegio = @a)
    sign_in colegio.director
    post armar_horarios_path(seccion: colegio.seccion.id)
    hora = con_el_colegio(colegio.colegio) { colegio.seccion.reload.bell_schedule.horas_de_clase.first }
    post section_lessons_path(colegio.seccion), params: { subject_id: colegio.materia.id, dia: 1, time_slot_id: hora.id }
  end

  def publicar = patch(publicar_horarios_path(seccion: @seccion.id))
  def texto_del_pdf = paginas_de(response.body).join(" ")

  test "la hoja de una sección: una hoja acostada con el colegio, el año, el turno y cada clase" do
    armar_un_bloque
    publicar

    get horario_section_path(@seccion, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/\Ainline; filename="horario-1er-ano-a-2025-2026.pdf"/, response.headers["Content-Disposition"])
    assert_equal 1, paginas_de(response.body).size, "una hoja"
    assert_match %r{/MediaBox \[0 0 792(\.0)? 612(\.0)?\]}, response.body, "carta, acostada"

    texto = texto_del_pdf
    [ @a.colegio.name.upcase, "HORARIO DE CLASES", "2025-2026", "1er Año A",
      "Turno de la mañana, de 7:10 a. m. a 1:00 p. m.", "RECESO · 9:50 – 10:20",
      "Publicado el 2 de marzo de 2026", "ÁREAS Y PROFESORES" ].each do |dice|
      assert_includes texto, dice
    end

    # El bloque de 80 minutos va unido: el área se escribe UNA vez en la rejilla.
    casillas = textos_de(response.body).select { |t| t.negrita && t.texto == "Matemática" }
    assert_equal 1, casillas.size, "Matemática, de 7:10 a 8:30, es una sola casilla"
    assert_includes texto, apellido
    assert_includes texto, "Matemática · #{en_a { @garcia.user.apellidos_y_nombres }} · 2 de 4 h"
    assert_not_includes texto, "BORRADOR"
  end

  # Una hoja pegada en la pared tiene que distinguirse de la definitiva.
  test "en borrador lo dice arriba y atravesado" do
    armar_un_bloque

    get horario_section_path(@seccion, format: :pdf)

    texto = texto_del_pdf
    assert_includes texto, "BORRADOR · sus profesores y sus familias todavía no lo ven"
    assert textos_de(response.body).any? { |t| t.texto == "BORRADOR" && t.size >= 60 }, "la marca atravesada"
  end

  test "la hoja de un profesor: en cada casilla, la sección y el área" do
    armar_un_bloque

    get horarios_path(ver: "profesores", profesor: @garcia.id, format: :pdf)

    assert_response :success
    texto = texto_del_pdf
    nombre = en_a { @garcia.user.apellidos_y_nombres }
    assert_match(/filename="horario-#{nombre.parameterize}-2025-2026.pdf"/, response.headers["Content-Disposition"])
    [ nombre, "2 horas a la semana", "SECCIONES Y ÁREAS", "1er Año A · Matemática · 2 h",
      "1er Año A sigue en borrador: esas clases todavía pueden cambiar." ].each do |dice|
      assert_includes texto, dice
    end
  end

  test "los botones abren la hoja en otra pestaña, en las dos puertas y en la del profesor" do
    armar_un_bloque

    get horarios_path(seccion: @seccion.id)
    assert_select "a[href=?][target=_blank]", horario_section_path(@seccion, format: :pdf), text: /Horario en PDF/

    get horario_section_path(@seccion)
    assert_select "a[href=?][target=_blank]", horario_section_path(@seccion, format: :pdf), text: /Horario en PDF/

    get horarios_path(ver: "profesores", profesor: @garcia.id)
    assert_select "a[href=?][target=_blank]", horarios_path(ver: "profesores", profesor: @garcia.id, format: :pdf)
  end

  # Decisión 3: armar es gratis; lo que sale, con la suscripción.
  test "en gratis la hoja pide la suscripción" do
    gratis = colegio_completo("Gratis", suscripcion: :gratis)
    armar_un_bloque(gratis)

    get horario_section_path(gratis.seccion, format: :pdf)

    assert_response :payment_required
  end

  # MOR-108: la deuda deja al colegio en solo lectura, no sin sus papeles.
  test "con la suscripción vencida, la hoja sale" do
    armar_un_bloque
    Current.sin_aislamiento do
      suscripcion_de(@a.colegio).update!(status: :vencida, vigente_hasta: Date.current - 60, dias_de_gracia: 15)
    end

    get horario_section_path(@seccion, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  # Decisión 13: el borrador lo ve quien administra.
  test "el profesor saca la de su sección solo si está publicada" do
    armar_un_bloque
    publicar

    sign_in @a.profesor
    get horario_section_path(@seccion, format: :pdf)
    assert_response :success

    en_a { @seccion.reload.update!(timetable_published_at: nil) }
    get horario_section_path(@seccion, format: :pdf)
    assert_response :not_found
  end
end
