require "test_helper"

# Inscribir es UNA decisión: a quién.
#
#     ANTES                       AHORA
#     Alumno   [Seleccione… ▾]    Sección [1er Grado – A ▾]
#     Sección  [Seleccione… ▾]    🔍 escriba el apellido
#     Estado   (Regular)(Retir.)  ╭──╮ López Medina, Álvaro  [+ Inscribir]
#     Fecha    [11/09/2026]       ╰──╯ V20140000012 · sin inscripción
#
# ⚠️ El estado y la fecha NO se preguntan, y no es por ahorrar dos campos:
#
#   · una inscripción nace `regular` SIEMPRE. Retirar es otra acción, con otro
#     momento y otra pantalla (`MOR-182`).
#   · la fecha es un HECHO —cuándo se hizo el trámite—, no una decisión.
#     Preguntarla invita a cambiarla, y una inscripción con fecha inventada
#     descuadra la matrícula que se factura.
class InscribirEnUnToqueTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @suelto = con_el_colegio(@a.colegio) do
      usuario = User.create!(first_name: "SIN", last_name: "INSCRIBIR",
                             cedula_escolar: "V#{@a.colegio.id}90000001")
      Student.create!(user: usuario, school: @a.colegio, school_card: "SI-#{@a.colegio.id}")
    end
    sign_in @a.director
  end

  # ── La pantalla ───────────────────────────────────────────────────────────

  test "no pregunta ni el estado ni la fecha" do
    get new_enrollment_path

    assert_response :success
    assert_select "[name='enrollment[status]']", count: 0
    assert_select "[name='enrollment[enrollment_date]']", count: 0
  end

  # ⚠️ Los que se pueden inscribir van PRIMERO. En un colegio con la matrícula
  # cargada están inscritos los trescientos sesenta, y el que acaba de
  # registrarse quedaría al final por apellido: habría que bajar toda la lista
  # para llegar al único que se puede tocar.
  test "los que se pueden inscribir van primero" do
    get new_enrollment_path

    assert_equal @suelto.user.apellidos_y_nombres,
                 css_select(".inscribir-nombre").first.text.strip
  end

  # ── Inscribir ─────────────────────────────────────────────────────────────

  test "un toque inscribe, con la fecha de hoy y en regular" do
    assert_difference -> { con_el_colegio(@a.colegio) { Enrollment.count } }, 1 do
      post enrollments_path, params: { enrollment: { student_id: @suelto.id,
                                                     section_id: @a.seccion.id } }
    end

    inscripcion = con_el_colegio(@a.colegio) { Enrollment.find_by(student_id: @suelto.id) }
    assert_equal "regular", inscripcion.status
    assert_equal Date.current, inscripcion.enrollment_date
  end

  # ⚠️ Vuelve a la MISMA pantalla, no al listado. En septiembre se inscriben
  # veinte seguidos: mandar al listado obliga a volver a entrar veinte veces, y
  # a buscar otra vez la sección cada una.
  test "vuelve a la misma pantalla, con la sección puesta" do
    post enrollments_path, params: { enrollment: { student_id: @suelto.id,
                                                   section_id: @a.seccion.id } }

    assert_redirected_to new_enrollment_path(section_id: @a.seccion.id)
    follow_redirect!
    assert_select "input[name='enrollment[section_id]'][value=?]", @a.seccion.id.to_s
  end

  # ── ⚠️ Enter en el buscador no puede inscribir a nadie ────────────────────
  #
  # Un campo de texto dentro de un `<form>` dispara el «envío implícito» del
  # navegador al pulsar Enter, y acá el primer botón de la lista es «Inscribir»:
  # buscar un apellido y pulsar Enter —el gesto más natural del mundo—
  # inscribiría al primer alumno de la pantalla.
  test "el buscador no envía el formulario" do
    get new_enrollment_path

    buscador = css_select("#filtro_alumnos").first

    assert_includes buscador["data-action"], "keydown->filtro-local#sinEnviar"
    # Y no tiene `name`: lo que se escribe para buscar no es un dato que se manda.
    assert_nil buscador["name"]
  end
end
