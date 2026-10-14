require "test_helper"

# Académico ▸ Horarios ▸ Turnos (spec `horarios`, tanda 1).
class TurnosDelColegioTest < ActionDispatch::IntegrationTest
  # El horario del cuaderno que mandó Daniel. La entrada va como la manda un
  # campo de hora: «07:10».
  FOTO = { entrada: "07:10", minutos_por_hora: "40", horas_al_dia: "8", receso_minutos: "30", receso_tras: "4" }.freeze

  setup do
    @a, @b = dos_colegios_completos
    sign_in @a.director
  end

  def registrar(nombre = "Media · mañana", **cambios)
    post bell_schedules_path, params: { bell_schedule: { name: nombre }, timbre: FOTO.merge(cambios) }
  end

  def turno_de_a = con_el_colegio(@a.escenario.colegio) { BellSchedule.last }

  test "con cuatro números se registra el turno, con las nueve horas de la foto" do
    registrar
    turno = turno_de_a

    assert_redirected_to bell_schedule_path(turno)
    follow_redirect!
    assert_response :success
    assert_select "table.horas-del-turno tbody tr", 9
    assert_select "td", text: "Receso"
    assert_select "td", text: "8va hora"
    assert_match "8 horas al día · de 7:10 a. m. a 1:00 p. m.", response.body
  end

  test "es del año escolar de trabajo" do
    registrar

    assert_equal @a.escenario.periodo, con_el_colegio(@a.escenario.colegio) { turno_de_a.academic_period }
  end

  # La vista previa la pide el formulario por GET, solo para su marco: sale de
  # la misma cuenta que después se guarda.
  test "la vista previa muestra el timbre que saldría, sin guardar nada" do
    assert_no_difference -> { con_el_colegio(@a.escenario.colegio) { BellSchedule.count } } do
      get new_bell_schedule_path, params: { timbre: FOTO }, headers: { "Turbo-Frame" => "asi-queda" }
    end

    assert_response :success
    assert_select "turbo-frame#asi-queda" do
      assert_select "li", text: /12:20 – 1:00/
      assert_select "li.asi-queda-receso", text: "Receso 9:50 – 10:20"
    end
  end

  test "sin nombre y con un timbre imposible, no guarda y dice las dos cosas" do
    assert_no_difference -> { con_el_colegio(@a.escenario.colegio) { BellSchedule.count } } do
      registrar("", horas_al_dia: "0")
    end

    assert_response :unprocessable_entity
    assert_match "Un turno tiene entre 1 y 14 horas al día.", response.body
    assert_match "Nombre no puede estar en blanco", response.body
  end

  test "corregir una hora que pisa a la siguiente no se guarda, y dice con cuál" do
    registrar
    turno = turno_de_a
    primera = con_el_colegio(@a.escenario.colegio) { turno.time_slots.first }

    patch bell_schedule_time_slot_path(turno, primera), params: { time_slot: { desde: "07:10", hasta: "08:00" } }

    assert_redirected_to bell_schedule_path(turno)
    assert_equal "Se pisa con la 2da hora (7:50 – 8:30)", flash[:alert]
    assert_equal 470, con_el_colegio(@a.escenario.colegio) { primera.reload.ends_min }
  end

  test "una hora se corrige en su fila, y se agrega o se quita otra" do
    registrar
    turno = turno_de_a
    ultima = con_el_colegio(@a.escenario.colegio) { turno.time_slots.last }

    patch bell_schedule_time_slot_path(turno, ultima), params: { time_slot: { desde: "12:20", hasta: "12:50" } }
    assert_equal "Hora corregida.", flash[:notice]

    post bell_schedule_time_slots_path(turno), params: { time_slot: { kind: "clase", desde: "13:00", hasta: "13:40" } }
    assert_equal "Hora agregada.", flash[:notice]
    assert_equal 10, con_el_colegio(@a.escenario.colegio) { turno.time_slots.count }

    delete bell_schedule_time_slot_path(turno, ultima)
    assert_equal 9, con_el_colegio(@a.escenario.colegio) { turno.time_slots.count }
  end

  test "las secciones se marcan en la ficha del turno, y se desmarcan" do
    registrar
    turno = turno_de_a
    seccion = @a.escenario.seccion

    patch bell_schedule_path(turno), params: { bell_schedule: { section_ids: [ "", seccion.id.to_s ] } }
    assert_equal turno.id, con_el_colegio(@a.escenario.colegio) { seccion.reload.bell_schedule_id }

    patch bell_schedule_path(turno), params: { bell_schedule: { section_ids: [ "" ] } }
    assert_nil con_el_colegio(@a.escenario.colegio) { seccion.reload.bell_schedule_id }
  end

  # ⚠️ Un id de otro colegio en el formulario no entra: el `default_scope` lo
  # deja fuera antes de que nada se escriba.
  test "una sección de otro colegio no se cuela por el formulario" do
    registrar
    de_b = @b.escenario.seccion

    patch bell_schedule_path(turno_de_a), params: { bell_schedule: { section_ids: [ de_b.id.to_s ] } }

    assert_nil con_el_colegio(@b.escenario.colegio) { de_b.reload.bell_schedule_id }
  end

  test "un turno con secciones no se borra; sin ellas, sí" do
    registrar
    turno = turno_de_a
    patch bell_schedule_path(turno), params: { bell_schedule: { section_ids: [ @a.escenario.seccion.id.to_s ] } }

    delete bell_schedule_path(turno)
    assert_redirected_to bell_schedule_path(turno)
    assert_match "secciones", flash[:alert]

    patch bell_schedule_path(turno), params: { bell_schedule: { section_ids: [ "" ] } }
    delete bell_schedule_path(turno)
    assert_redirected_to bell_schedules_path
    assert_equal 0, con_el_colegio(@a.escenario.colegio) { BellSchedule.count }
  end

  test "la sección elige su turno en su ficha" do
    registrar
    turno = turno_de_a
    seccion = @a.escenario.seccion

    get edit_section_path(seccion)
    assert_select "select[name='section[bell_schedule_id]'] option", text: "Media · mañana"

    patch section_path(seccion), params: { section: { bell_schedule_id: turno.id } }
    assert_equal turno.id, con_el_colegio(@a.escenario.colegio) { seccion.reload.bell_schedule_id }
  end

  # ⚠️ El listado va ANTES del 404, y no es estética. `sign_in` lo consume la
  # primera petición que viene después, y si esa petición termina en 404 el
  # cambio de sesión no se guarda: la siguiente sigue entrando como el director
  # de A, y A ve lo suyo. Parecía una fuga entre colegios y era el test.
  test "otro colegio no ve ni toca el turno" do
    registrar
    turno = turno_de_a
    sign_in @b.director

    get bell_schedules_path
    assert_response :success
    assert_select "a[href='#{bell_schedule_path(turno)}']", 0

    get bell_schedule_path(turno)
    assert_response :not_found

    patch bell_schedule_path(turno), params: { bell_schedule: { name: "Cambiado por B" } }
    assert_response :not_found
    assert_equal "Media · mañana", con_el_colegio(@a.escenario.colegio) { turno.reload.name }
  end

  test "el profesor no entra a los turnos" do
    sign_in @a.profesor

    get bell_schedules_path
    assert_response :redirect
  end

  # Decisión 3 del spec: armar el horario es CARGAR.
  test "un colegio en gratis registra su turno" do
    gratis = colegio_completo("Colegio Gratis", suscripcion: :gratis)
    sign_in gratis.director

    post bell_schedules_path, params: { bell_schedule: { name: "Media · mañana" }, timbre: FOTO }

    assert_response :redirect
    assert_equal 1, con_el_colegio(gratis.escenario.colegio) { BellSchedule.count }
  end

  test "el menú lleva a Horarios" do
    get bell_schedules_path

    assert_select "a[href='#{bell_schedules_path}']", text: /Horarios/
  end
end
