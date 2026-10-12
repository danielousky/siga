require "test_helper"

# Lo gratis: cargar es libre, operar el colegio no (MOR-156, y desde el 12 de
# octubre de 2026 el spec `docs/specs/del-registro-al-cobro.md`, decisión 3).
#
# ## La decisión, y de quién es
#
# El límite NO es por número de registros ni por tiempo. Es por FUNCIÓN.
# Daniel: *«dejar libre la entrada pero limitar el procesamiento (calificar o
# asistencia) y la salida»*.
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
    @a, _b = dos_colegios_completos(suscripcion: :gratis)
    @suscripcion = suscripcion_de(@a.colegio)
    sign_in @a.director
  end

  # ── la entrada: libre ─────────────────────────────────────────────────────

  # ⚠️ Cargar es libre, y no es generosidad: un colegio que no puede terminar de
  # cargar su matrícula nunca llega al momento en que el boletín le importa. Ahí
  # no hay conversión, hay un colegio a medio cargar con un problema de datos.
  test "en gratis se cargan alumnos, profesores y áreas" do
    assert_difference -> { Current.sin_aislamiento { Subject.count } }, 1 do
      post subjects_path, params: { subject: { name: "Francés", code: "FRA",
                                               department_id: @a.materia.department_id } }
    end

    assert_response :redirect
    assert_not_equal 402, response.status
  end

  test "el importador sigue abierto, y su plantilla baja" do
    get importaciones_path
    assert_response :success

    # Es un archivo, y los archivos son SALIDA… salvo este: es lo que el colegio
    # llena para cargar.
    get plantilla_importaciones_path(format: :xlsx)
    assert_response :success
  end

  # ── el procesamiento: con la suscripción ──────────────────────────────────

  test "no se pueden cargar notas" do
    patch evaluation_activity_nota_path(@a.actividad, @a.escenario.alumno),
          params: { score: 15 }, as: :json

    assert_response :payment_required
  end

  test "no se puede pasar lista" do
    post seccion_asistencia_path(@a.seccion), params: { dia: Date.current.to_s }, as: :json

    assert_response :payment_required
  end

  # ⚠️ Los ocho huecos. La lista de lo que pide la suscripción se escribió el 27
  # de agosto de 2026, y todo lo construido después quedó afuera sin que nada
  # avisara: con un preescolar se operaba completo sin pagar. Hoy cada
  # controlador está en una lista (`frontera_de_lo_gratis_test`), y estos son los
  # que se habían escapado.
  test "tampoco se cierra el lapso, que emite los boletines y les escribe a las familias" do
    patch cerrar_lapso_path, params: { seccion: @a.seccion.id, lapso: @a.lapso(1).id }

    assert_response :redirect
    assert_match(/se activan con la suscripción/, flash[:alert])
  end

  test "ni la reparación, ni la valoración de Inicial, ni el informe descriptivo" do
    patch nota_de_reparacion_path(seccion_id: @a.seccion.id, materia_id: @a.materia.id,
                                  student_id: @a.alumno.id), params: { score: 12 }, as: :json
    assert_response :payment_required

    patch section_valoracion_path(@a.seccion), params: { descripcion: "Avanza" }, as: :json
    assert_response :payment_required

    patch section_informe_path(@a.seccion, @a.inscripcion), params: { texto: "Bien" }, as: :json
    assert_response :payment_required
  end

  test "ni la cobranza a las familias, ni los correos" do
    post academic_period_cobros_path(@a.periodo), params: { concepto: "Inscripción" }
    assert_response :redirect
    assert_match(/se activan con la suscripción/, flash[:alert])

    post mensaje_al_representative_path(1), params: { asunto: "Hola", cuerpo: "Hola" }
    assert_response :redirect
    assert_match(/se activan con la suscripción/, flash[:alert])
  end

  test "las pantallas de la cobranza se siguen viendo" do
    get finanzas_path

    assert_response :success
  end

  # ── la salida: con la suscripción ─────────────────────────────────────────

  test "no se emiten boletines ni constancias" do
    post constancias_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }
    assert_response :redirect

    post report_cards_path, params: { section_id: @a.seccion.id,
                                      evaluation_moment_id: @a.lapso(1).id }
    assert_response :redirect
  end

  # ⚠️ Los certificados tienen DOS puertas, y las dos tienen que estar cerradas:
  # la ficha (un GET de documentos oficiales) y la pestaña de «Documentos».
  test "tampoco certificados, por ninguna de las dos puertas" do
    post certificados_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }
    assert_response :redirect
    assert_match(/se activan con la suscripción/, flash[:alert])

    # La ficha pide un PDF, y a un PDF no se le contesta con un redirect a una
    # pantalla: sale el 402 a secas.
    get certificacion_de_calificaciones_path(student_id: @a.alumno, format: :pdf)
    assert_response :payment_required
  end

  test "ni las listas en Excel: un archivo ya es salida" do
    get sections_path(format: :xlsx)

    assert_response :payment_required
  end

  test "ni la descarga del boletín" do
    get boletin_path(@a.boletin)

    assert_response :payment_required
  end

  # ⚠️ Un portal NO se contesta con un redirect: el destino por defecto de un
  # alumno o de una familia ES su portal, y mandarlos ahí los dejaría dando
  # vueltas. Ven una página que dice qué pasa — sin precios, que no son suyos.
  test "el portal del alumno muestra que todavía no está activo" do
    sign_in @a.estudiante
    get dashboards_estudiante_path

    assert_response :payment_required
    assert_select ".al-dia", text: /todavía no activó/ do |carta|
      assert_no_match(/\$/, carta.text, "a un alumno no se le habla de precios")
    end
  end

  # ── el muro dice el precio a quien lo paga ────────────────────────────────

  # El colegio de prueba tiene dos alumnos: paga el mínimo.
  test "a la dirección, el muro le dice cuánto cuesta" do
    post constancias_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }

    monto = ApplicationController.helpers.numero_en_dolares(Subscription.cotizar(2).monto)
    assert_includes flash[:alert], "#{monto} al mes"
    assert_includes flash[:alert], "el mínimo"
    # El precio es final: lo que se lee es lo que se paga (decisión 28).
    assert_no_match(/IVA/, flash[:alert])
  end

  test "al profesor no: no es él quien paga" do
    sign_in @a.profesor
    patch evaluation_activity_nota_path(@a.actividad, @a.escenario.alumno),
          params: { score: 15 }, as: :json

    assert_response :payment_required
    assert_no_match(/\$/, response.parsed_body["mensaje"])
    assert_match(/lleva la dirección/, response.parsed_body["mensaje"])
  end

  # ── pero las pantallas SE VEN ─────────────────────────────────────────────

  # Una pantalla escondida no vende nada; una que se ve y no se toca, sí. El
  # director entra a la planilla, ve su sección y sus alumnos, y entiende qué
  # está comprando.
  test "las pantallas se siguen viendo, con su aviso" do
    [ report_cards_path, constancias_path, certificados_path, asistencias_path ].each do |ruta|
      get ruta
      follow_redirect! while response.redirect?

      assert_response :success, "#{ruta} se escondió: una pantalla que no se ve no vende nada"
    end

    assert_select ".aviso-suscripcion", text: /Sin suscripción activa/
  end

  # ── un colegio SIN fila cuenta como gratis ────────────────────────────────

  # ⚠️ Hasta el 12 de octubre de 2026 era lo contrario: sin fila era acceso
  # completo y sin fecha, y por esa puerta —el alta desde `/siga`— se entraba a
  # todo el producto gratis y para siempre (decisión 16 del spec).
  test "un colegio sin suscripción carga, pero no opera" do
    Current.sin_aislamiento { @suscripcion.destroy! }

    post seccion_asistencia_path(@a.seccion), params: { dia: Date.current.to_s }, as: :json
    assert_response :payment_required

    assert_difference -> { Current.sin_aislamiento { Subject.count } }, 1 do
      post subjects_path, params: { subject: { name: "Latín", code: "LAT",
                                               department_id: @a.materia.department_id } }
    end
  end

  # ── y la deuda es otra cosa, con otra regla ───────────────────────────────

  # Un colegio que TENÍA la suscripción y debe dinero no pierde la constancia:
  # la deuda es del colegio y el perjuicio no puede ser del alumno (MOR-108).
  # Confundir los dos estados le quita a una familia el papel del pasaporte.
  test "un colegio endeudado con su suscripción sí emite" do
    Current.sin_aislamiento { @suscripcion.update!(plan: :por_alumno, status: :vencida) }

    post constancias_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end
end
