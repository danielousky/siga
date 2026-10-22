require "test_helper"

# Académico ▸ Horarios, por HTTP (spec `horarios`, tanda 2): la puerta, armar,
# el porqué de una casilla, la carga, el timbre, publicar, las miradas y quién
# entra.
#
# ⚠️ `sign_in` lo consume la PRIMERA petición, y una que termina en 404 no
# guarda la sesión: la siguiente correría como el usuario anterior. Por eso, en
# cada test, lo que da 404 va al final.
class HorariosTest < ActionDispatch::IntegrationTest
  # ⚠️ Un lunes de clases del año de los escenarios (2025-2026). Sin esto, desde
  # agosto de 2026 ese año ya terminó, y un año terminado no se arma
  # (decisión 16): todos los tests leerían «ya terminó».
  setup { travel_to Time.zone.local(2026, 3, 2, 10, 0) }

  setup do
    @a, @b = dos_colegios_completos
    @seccion = @a.seccion
    @mat = @a.materia
    @garcia = @a.registro_de_profesor
  end

  def en_a(&) = con_el_colegio(@a.colegio, &)
  def turno = en_a { @seccion.reload.bell_schedule }
  def hora(numero) = en_a { turno.horas_de_clase[numero - 1] }
  def clases(seccion = @seccion) = en_a { Lesson.where(section: seccion).order(:day, :starts_min).pluck(:day, :starts_min) }
  def apellido = en_a { ChoquesDeHorario.apellido_de(@garcia) }

  def armar
    sign_in @a.director
    post armar_horarios_path(seccion: @seccion.id)
  end

  def ubicar(seccion, dia:, hora:, materia: @mat)
    post section_lessons_path(seccion), params: { subject_id: materia.id, dia: dia, time_slot_id: self.hora(hora).id }
    follow_redirect!
  end

  def mensaje = css_select(".horario-mensaje p").first&.text.to_s.squish

  # ── La puerta ────────────────────────────────────────────────────────────

  test "abre en la semana de la sección, con el timbre de la foto aunque no haya turno, y sin guardar nada" do
    sign_in @a.director
    get horarios_path

    assert_response :success
    assert_select "h2.horario-titulo", text: /1er Año A/
    assert_select ".horario-hora-tiempo", text: "7:10 – 7:50"
    assert_select ".horario-fila-receso td", text: "Receso"
    en_a { assert_equal 0, BellSchedule.count, "mirar no escribe" }
  end

  test "«Armar» estrena el turno de la foto y se lo pone a la sección" do
    armar

    assert_redirected_to horarios_path(seccion: @seccion.id, armar: 1, area: @mat.id)
    en_a do
      assert_equal "Turno de la mañana", turno.name
      assert_equal 9, turno.time_slots.count
    end
  end

  # ── Armar ────────────────────────────────────────────────────────────────

  test "tocar una casilla libre ubica un bloque de dos horas, y el mensaje lo cuenta y brinca" do
    armar
    ubicar(@seccion, dia: 1, hora: 1)

    assert_equal [ [ 1, 430 ], [ 1, 470 ] ], clases
    assert_equal "Listo: Matemática el lunes de 7:10 a 8:30. Van 2 de 4.", mensaje
    assert_select ".horario-mensaje.horario-mensaje--ok.horario-mensaje--brinca"
  end

  test "quitar devuelve el bloque entero a «por ubicar»" do
    armar
    ubicar(@seccion, dia: 1, hora: 1)
    delete section_lesson_path(@seccion, en_a { Lesson.where(section: @seccion).first })
    follow_redirect!

    assert_empty clases
    assert_equal "Se quitó Matemática del lunes (7:10 – 8:30). Vuelve a «Por ubicar»: 0 de 4.", mensaje
  end

  test "donde el profesor ya dicta, la casilla sale rayada; tocarla dice por qué, y el armador no la ubica" do
    otra = en_a do
      Section.create!(grade: @a.grado, academic_period: @a.periodo, name: "B", capacity: 30).tap do |b|
        TeacherSection.create!(teacher: @garcia, section: b, subject: @mat)
      end
    end
    armar
    ubicar(@seccion, dia: 1, hora: 1)

    get horarios_path(seccion: otra.id, armar: 1, area: @mat.id)
    assert_select ".horario-rejilla .horario-bloqueada", 2
    get horarios_path(seccion: otra.id, armar: 1, area: @mat.id, porque: "1-0")
    assert_equal "Lunes a las 7:10 no se puede: #{apellido} está en 1er Año A dando Matemática.", mensaje
    assert_select ".horario-mensaje.horario-mensaje--aviso.horario-mensaje--brinca"
    assert_select ".horario-rejilla .horario-bloqueada.marcada", 1

    ubicar(otra, dia: 1, hora: 1)
    assert_empty clases(otra)
    assert_match "#{apellido} está en 1er Año A dando Matemática", mensaje
  end

  test "la carga sube y baja para el grado entero, y no baja de lo ya ubicado" do
    armar
    pensum = en_a { GradeSubject.find_by(grade: @a.grado, subject: @mat) }
    patch carga_horarios_path(seccion: @seccion.id, grade_subject_id: pensum.id, delta: 1)
    follow_redirect!
    assert_equal 5, en_a { pensum.reload.weekly_hours }, "la propuesta del plan (4) se vuelve del colegio al tocarla"
    assert_equal "Matemática: 5 horas a la semana en 1er Año A.", mensaje

    ubicar(@seccion, dia: 2, hora: 1)
    # 5 → 4 → 3 → 2, y la cuarta ya no: hay dos horas ubicadas.
    4.times { patch carga_horarios_path(seccion: @seccion.id, grade_subject_id: pensum.id, delta: -1) }
    follow_redirect!
    assert_equal 2, en_a { pensum.reload.weekly_hours }
    assert_equal "No baja de 2: 1er Año A ya tiene 2 horas de Matemática ubicadas. Quite una primero.", mensaje
  end

  test "corregir una hora del timbre mueve sus clases y lo dice; si se pisa, no se guarda" do
    armar
    ubicar(@seccion, dia: 1, hora: 1)
    primera = hora(1)

    patch bell_schedule_time_slot_path(turno, primera), params: { time_slot: { desde: "07:05", hasta: "07:50" }, seccion: @seccion.id }
    follow_redirect!
    assert_equal [ 1, 425 ], clases.first
    assert_equal "La 1ra hora ahora va de 7:05 a 7:50. Cambió en 1 sección del turno de la mañana.", mensaje

    patch bell_schedule_time_slot_path(turno, primera), params: { time_slot: { desde: "07:05", hasta: "08:00" }, seccion: @seccion.id }
    follow_redirect!
    assert_equal "Se pisa con la 2da hora (7:50 – 8:30)", mensaje
    assert_equal 470, en_a { primera.reload.ends_min }
  end

  test "publicar pregunta antes, con lo que falta, y lo cuenta" do
    armar
    get horarios_path(seccion: @seccion.id)
    assert_select "form[data-turbo-confirm*='¿Publicar el horario de 1er Año A?'][data-turbo-confirm*='Faltan 4 horas por ubicar']"

    patch publicar_horarios_path(seccion: @seccion.id)
    follow_redirect!
    assert en_a { @seccion.reload.timetable_published_at.present? }
    assert_equal "1er Año A quedó publicado. Ya lo ven sus profesores, sus alumnos y las familias.", mensaje
  end

  # ── Las miradas: la misma tabla ──────────────────────────────────────────

  test "por profesor, por área, todas un mismo día y por alumno dicen la misma clase" do
    armar
    ubicar(@seccion, dia: 3, hora: 3)

    get horarios_path(ver: "profesores", profesor: @garcia.id)
    assert_select ".horario-rejilla .horario-clase b", text: "1er Año A"
    get horarios_path(ver: "areas", area: @mat.id)
    assert_select ".horario-rejilla .horario-varias", text: /1er A/
    get horarios_path(vista: "dia", dia: 3)
    assert_select ".horario-matriz .horario-matriz-clase b", text: "Matemática"
    get horarios_path(ver: "profesores", vista: "dia", dia: 3)
    assert_select ".horario-matriz .horario-matriz-clase b", text: "1er A"

    alumno = @a.alumno
    get horarios_path(ver: "alumnos", q: alumno.user.first_name)
    assert_select ".horario-resultado", text: /1er Año A/
    get horarios_path(ver: "alumnos", alumno: alumno.id)
    assert_select ".horario-rejilla .horario-clase b", text: "Matemática"
  end

  # Decisión 16: un año que terminó queda en solo lectura.
  test "en un año que terminó, el horario se ve y ya no se arma" do
    viejo = ano_escolar_viejo(@a.escenario)
    seccion_vieja = en_a { Section.find_by!(academic_period: viejo, name: "A") }
    sign_in @a.director

    post section_lessons_path(seccion_vieja), params: { subject_id: @mat.id, dia: 1, time_slot_id: 0 }
    assert_equal "#{viejo.name} ya terminó: su horario se ve, y ya no se arma.", flash[:horario]["texto"]
    assert_equal 0, en_a { Lesson.count }
  end

  # ── Quién entra ──────────────────────────────────────────────────────────

  test "el profesor no entra a armar" do
    sign_in @a.profesor
    get horarios_path
    assert_response :redirect

    post armar_horarios_path(seccion: @seccion.id)
    en_a { assert_equal 0, BellSchedule.count }
  end

  test "en gratis se arma: es cargar" do
    gratis = colegio_completo("Gratis", suscripcion: nil)
    sign_in gratis.director
    post armar_horarios_path(seccion: gratis.seccion.id)
    horas = con_el_colegio(gratis.colegio) { gratis.seccion.reload.bell_schedule.horas_de_clase }
    post section_lessons_path(gratis.seccion), params: { subject_id: gratis.materia.id, dia: 2, time_slot_id: horas.first.id }

    assert_equal 2, con_el_colegio(gratis.colegio) { Lesson.where(section: gratis.seccion).count }
  end

  test "otro colegio no toca nada: ni ubica ni quita en una sección ajena" do
    armar
    ubicar(@seccion, dia: 1, hora: 1)
    clase = en_a { Lesson.where(section: @seccion).first }

    sign_in @b.director
    get horarios_path
    assert_select "h2.horario-titulo", text: /1er Año A/ # la SUYA: también se llama así
    assert_select ".horario-clase", 0

    delete section_lesson_path(@seccion, clase)
    assert_response :not_found
    assert_equal 2, clases.size
  end
end
