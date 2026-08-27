require "test_helper"

# El plan gratuito: cargar es libre, operar el colegio no (MOR-156).
#
# ## La decisión, y de quién es
#
# El límite NO es por número de registros ni por tiempo. Es por FUNCIÓN.
#
# Por registros rompe la importación a mitad de camino: con matrícula promedio
# de 360 alumnos y tope en 200, la fila 201 falla y el colegio queda con media
# matrícula, un reporte lleno de rojo y la sensación de que el sistema se rompió
# —justo cuando debía sentirse poderoso—.
#
# Por tiempo empieza a correr en septiembre, que es cuando nadie en un colegio
# tiene un minuto, y se vence sin que hayan cargado nada.
class PlanGratisTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    @suscripcion = Current.sin_aislamiento do
      Subscription.create!(school: @a.colegio, plan: :gratis, status: :activa,
                           precio_mensual: 0, vigente_desde: Date.current,
                           vigente_hasta: 1.year.from_now.to_date)
    end
    sign_in @a.director
  end

  # ── lo que queda libre ────────────────────────────────────────────────────

  # ⚠️ Cargar es libre, y no es generosidad: un colegio que no puede terminar de
  # cargar su matrícula nunca llega al momento en que el boletín le importa. Ahí
  # no hay conversión, hay un colegio a medio cargar con un problema de datos.
  test "con el plan gratis se cargan alumnos, profesores y materias" do
    assert_difference -> { Current.sin_aislamiento { Subject.count } }, 1 do
      post subjects_path, params: { subject: { name: "Francés", code: "FRA",
                                               department_id: @a.materia.department_id } }
    end

    assert_response :redirect
    assert_not_equal 402, response.status
  end

  test "el importador de planillas sigue abierto" do
    get importaciones_path

    assert_response :success
  end

  # ── lo que se ACTIVA con el plan ──────────────────────────────────────────

  test "no se pueden cargar notas" do
    patch evaluation_activity_nota_path(@a.actividad, @a.escenario.alumno),
          params: { score: 15 }, as: :json

    assert_response :payment_required
  end

  test "no se puede pasar lista" do
    post seccion_asistencia_path(@a.seccion), params: { dia: Date.current.to_s }, as: :json

    assert_response :payment_required
  end

  test "no se emiten boletines ni constancias" do
    post constancias_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }
    assert_response :redirect

    post report_cards_path, params: { section_id: @a.seccion.id,
                                      evaluation_moment_id: @a.lapso(1).id }
    assert_response :redirect
  end

  # ── pero las pantallas SE VEN ─────────────────────────────────────────────

  # Una pantalla escondida no vende nada; una que se ve y no se toca, sí. El
  # director entra a la planilla, ve su sección y sus alumnos, y entiende qué
  # está comprando.
  test "las pantallas se siguen viendo, con su aviso" do
    %w[/boletines /constancias /asistencia].each do |ruta|
      get ruta
      follow_redirect! while response.redirect?

      assert_response :success, "#{ruta} se escondió: una pantalla que no se ve no vende nada"
    end
  end

  # ── y un colegio SIN fila de suscripción tiene todo ───────────────────────

  # ⚠️ `gratis` es una decisión escrita, no la ausencia de una. Un colegio sin
  # suscripción es el piloto o el primer mes, y bloquearlo sería romperle el
  # producto justo a quien lo está evaluando.
  test "un colegio sin suscripción no está en plan gratis" do
    Current.sin_aislamiento { @suscripcion.destroy! }

    post seccion_asistencia_path(@a.seccion), params: { dia: Date.current.to_s }, as: :json

    assert_response :success
  end

  # ── y la deuda es otra cosa, con otra regla ───────────────────────────────

  # Un colegio que TENÍA plan y debe dinero no pierde la constancia: la deuda es
  # del colegio y el perjuicio no puede ser del alumno (MOR-108). Confundir los
  # dos estados le quita a una familia el papel del pasaporte.
  test "un colegio endeudado con plan de pago sí emite" do
    Current.sin_aislamiento { @suscripcion.update!(plan: :basico, status: :vencida) }

    post constancias_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end
end
