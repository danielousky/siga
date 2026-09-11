require "test_helper"

# Educación Inicial no califica: DESCRIBE.
#
# Daniel, 10 de septiembre de 2026: *«los niños en Inicial no sacan ni A, ni B,
# ni C, ni PC, ni AP, ni 5, ni 20, entonces la calificación es descriptiva, y al
# final el profe indica que aprobó, que prácticamente, con asistir al colegio»*.
#
#     PRIMARIA / MEDIA          INICIAL
#     ────────────────          ───────
#     Planificar · Calificar    Calificar
#     evaluaciones con peso     — no hay nada que ponderar
#     un número del 1 al 20     un párrafo por área
#
# ⚠️ Lo que este test cuida no es la pantalla: es que las TRES capas digan lo
# mismo. La columna `final_moment_score` era `NOT NULL`, así que una valoración
# descriptiva no cabía en la base; el modelo exigía número; y la pestaña
# «Planificar» le pedía a la maestra una ponderación que no existe.
class ValoracionesDeInicialTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(nombre: "Jardín", alumnos: 2, nivel: :preescolar)
    con_el_colegio(@esc.colegio) do
      @docente = User.create!(first_name: "Maestra", last_name: "Inicial",
                             email: "maestra.#{@esc.colegio.id}@jardin.test", password: "123123",
                             document: "V-#{@esc.colegio.id}77", document_type: :cedula_v)
      @registro = Teacher.create!(user: @docente, school: @esc.colegio)
      TeacherSection.create!(teacher: @registro, section: @esc.seccion, subject: @esc.materia)
    end
    @lapso = @esc.lapso(1)
    sign_in @docente
  end

  def calificar = get section_path(@esc.seccion, lapso: @lapso.id)

  def valorar(texto, inscripcion: @esc.inscripcion, area: @esc.materia)
    patch section_valoracion_path(@esc.seccion),
          params: { enrollment_id: inscripcion.id, subject_id: area.id,
                    lapso: @lapso.id, descripcion: texto },
          headers: { "Turbo-Frame" => "valoraciones" }
  end

  # ── La pantalla ───────────────────────────────────────────────────────────

  test "la sección de Inicial no ofrece Planificar" do
    calificar

    assert_response :success
    assert_select "a", { text: "Planificar", count: 0 },
                  # en Inicial no hay evaluaciones con peso que armar
                  "la pestaña le pediría una ponderación que no existe"
    assert_select "a", text: "Calificar"
  end

  # ⚠️ La URL se puede escribir a mano o quedar en un marcador.
  test "planificar redirige a calificar" do
    get planificar_section_path(@esc.seccion)

    assert_redirected_to section_path(@esc.seccion, area: @esc.materia.id)
  end

  test "calificar muestra un campo de texto por niño y por área" do
    calificar

    assert_select ".valoracion-alumno", 2
    # Dos niños × un área del pensum: dos casillas, todas con su textarea.
    assert_select "textarea.valoracion-texto", 2
    assert_select ".valoraciones-cuenta", /0 de 2/
    # Y NADA de la planilla numérica.
    assert_select "input[type=number]", count: 0
  end

  # ── Guardar ───────────────────────────────────────────────────────────────

  test "guardar una valoración la escribe y la cuenta" do
    assert_difference "MomentGrade.count", 1 do
      valorar "Se integró al grupo con facilidad y comparte sus juegos."
    end

    assert_response :success
    assert_select ".valoraciones-cuenta", /1 de 2/
    assert_select ".valoracion-area--guardada"

    nota = MomentGrade.last
    assert_equal "Se integró al grupo con facilidad y comparte sus juegos.", nota.descripcion
    assert_nil nota.final_moment_score, "en Inicial no hay número que guardar"
  end

  # ⚠️ Vaciar el campo BORRA la fila: «sin valoración» no es un texto en blanco,
  # igual que «sin nota» no es un cero. Una fila vacía saldría en la boleta como
  # un renglón mudo y contaría como escrita en «¿por dónde iba?».
  test "vaciar el campo borra la valoración" do
    valorar "Un texto que después se borra."

    assert_difference "MomentGrade.count", -1 do
      valorar ""
    end

    assert_select ".valoraciones-cuenta", /0 de 2/
  end

  test "volver a guardar corrige la misma fila, no crea otra" do
    valorar "Primera versión."

    assert_no_difference "MomentGrade.count" do
      valorar "Versión corregida."
    end

    assert_equal "Versión corregida.", MomentGrade.last.descripcion
  end

  # ⚠️ La respuesta vuelve DENTRO del frame que preguntó, o Turbo escribe
  # «Content missing» encima de la pantalla entera.
  test "la respuesta trae el frame de las valoraciones" do
    valorar "Comparte y espera su turno."

    assert_select "turbo-frame#valoraciones"
  end

  # ── Quién escribe ─────────────────────────────────────────────────────────

  test "un profesor de otra sección no puede valorar" do
    otro = escenario_academico(nombre: "Otro jardín", nivel: :preescolar)
    ajeno = con_el_colegio(otro.colegio) do
      usuario = User.create!(first_name: "Ajena", last_name: "Maestra",
                             email: "ajena.#{otro.colegio.id}@jardin.test", password: "123123",
                             document: "V-#{otro.colegio.id}88", document_type: :cedula_v)
      Teacher.create!(user: usuario, school: otro.colegio)
      usuario
    end

    sign_in ajeno
    assert_no_difference "MomentGrade.count" do
      valorar "No debería poder."
    end
  end
end
