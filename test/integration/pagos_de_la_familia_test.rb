require "test_helper"

# Las dos puertas: la familia reporta, la oficina valida — y lo que una familia
# en mora NO puede ver (spec: `docs/specs/pagos-de-la-familia.md`).
class PagosDeLaFamiliaTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(nombre: "Colegio de Pagos")
    @colegio = @esc.colegio

    con_el_colegio(@colegio) do
      @rep_usuario = usuario("rep", @colegio.id)
      @representante = Representative.create!(user: @rep_usuario, school: @colegio)
      StudentRepresentative.create!(student: @esc.alumno, representative: @representante)

      @dir_usuario = usuario("dir", @colegio.id)
      Admin.create!(user: @dir_usuario, school: @colegio, role: :finanzas)

      @concepto = Fee.create!(academic_period: @esc.periodo, nombre: "Septiembre",
                              monto: 45, vence_el: Date.current - 30)
      Charge.emitir_para(@esc.inscripcion)
    end
  end

  # ── la tarjeta de pago ────────────────────────────────────────────────────

  test "el representante ve su tarjeta con lo pagado y lo que falta" do
    sign_in @rep_usuario
    get pagos_path

    assert_response :success
    assert_select ".tarjeta-de-pago"
    assert_select ".pastilla-de-cobro", text: "Vencido"
  end

  # ⚠️ La tarjeta es lo ÚNICO que no se bloquea por deuda: es la pantalla que
  # explica la deuda y permite salir de ella.
  test "la tarjeta se ve AUNQUE haya deuda" do
    sign_in @rep_usuario
    get pagos_path

    assert_response :success
    assert_select ".al-dia", 0
  end

  # ── el bloqueo ────────────────────────────────────────────────────────────

  # ⚠️ Daniel: *«ellos deben siempre poder ingresar a la sesión»*. Se entra, no
  # se expulsa: la respuesta es 402 con el aviso, no un redirect al login.
  test "en mora se entra igual, pero no se ven las notas ni la asistencia" do
    sign_in @rep_usuario
    get hijo_representante_path(@esc.alumno)

    assert_response :payment_required
    assert_select ".al-dia"
    assert_select ".al-dia", /ponerse al día/
    assert_select "a[href=?]", pagos_path, minimum: 1, message: "tiene que haber salida"
  end

  test "el aviso dice QUÉ mes se debe, no solo que hay deuda" do
    sign_in @rep_usuario
    get hijo_representante_path(@esc.alumno)

    assert_select ".al-dia-detalle", /Septiembre/
  end

  test "al día, las notas se ven" do
    con_el_colegio(@colegio) { Charge.update_all(pagado_el: Time.current) }
    sign_in @rep_usuario

    get hijo_representante_path(@esc.alumno)

    assert_response :success
    assert_select ".al-dia", 0
  end

  # ⚠️ El bloqueo alcanza a la FAMILIA, no al colegio: la dirección y el
  # profesor ven las notas de un alumno en mora igual. Esconderles el dato
  # convierte una gestión de cobranza en un problema pedagógico.
  test "la dirección ve las notas de un alumno en mora" do
    # ⚠️ Con el DIRECTOR, no con finanzas: quien cobra no administra alumnos —es
    # la otra mitad de la misma regla, y el test lo dejó claro al fallar.
    director = con_el_colegio(@colegio) do
      u = usuario("dire", @colegio.id)
      Admin.create!(user: u, school: @colegio, role: :director)
      u
    end
    sign_in director
    get student_path(@esc.alumno)

    assert_response :success
    assert_select ".al-dia", 0
  end

  # ── reportar ──────────────────────────────────────────────────────────────

  test "el representante reporta un pago y queda en revisión" do
    sign_in @rep_usuario
    cobro = con_el_colegio(@colegio) { Charge.first }

    assert_difference "con_el_colegio(@colegio) { PaymentReport.count }", 1 do
      post pagos_path, params: {
        inscripcion: @esc.inscripcion.id,
        cobros: [ cobro.id ],
        payment_report: { referencia: "0012-3456", banco: "0102", monto: 45,
                          pagado_el: Date.current, depositante_nombre: "María Pérez" }
      }
    end

    assert_redirected_to pagos_path
    con_el_colegio(@colegio) do
      assert PaymentReport.last.esperando_revision?
      assert_equal PaymentReport.last.id, cobro.reload.payment_report_id
      assert_not cobro.pagado?, "reportar no paga"
    end
  end

  # ⚠️ Sin cuotas marcadas, el reporte no dice qué paga y la oficina no tiene
  # con qué compararlo.
  test "no se reporta sin marcar qué cuota se paga" do
    sign_in @rep_usuario

    assert_no_difference "con_el_colegio(@colegio) { PaymentReport.count }" do
      post pagos_path, params: {
        inscripcion: @esc.inscripcion.id,
        payment_report: { referencia: "0012-3456", banco: "0102", monto: 45,
                          pagado_el: Date.current, depositante_nombre: "María Pérez" }
      }
    end

    assert_response :unprocessable_entity
  end

  # ⚠️ Cambiar el id en la URL no puede dejar reportar contra la inscripción de
  # otro alumno — ni mirar su estado de cuenta.
  test "no se reporta por un alumno ajeno" do
    otro = escenario_academico(nombre: "Otro Colegio")
    sign_in @rep_usuario

    get new_pago_path(inscripcion: otro.inscripcion.id)

    # Cae en SU inscripción, no en la ajena.
    assert_response :success
    assert_select "input[name='payment_report[enrollment_id]'][value=?]", @esc.inscripcion.id.to_s
  end

  # ── validar ───────────────────────────────────────────────────────────────

  test "finanzas valida y la familia vuelve a ver todo" do
    reporte = reportar!
    sign_in @dir_usuario

    patch validar_finanza_path(reporte)

    assert_redirected_to finanzas_path
    con_el_colegio(@colegio) { assert Charge.first.reload.pagado? }

    sign_in @rep_usuario
    get hijo_representante_path(@esc.alumno)
    assert_response :success
  end

  test "finanzas rechaza con su motivo y la familia lo ve" do
    reporte = reportar!
    sign_in @dir_usuario

    patch rechazar_finanza_path(reporte), params: { motivo: "no aparece en el banco" }

    sign_in @rep_usuario
    get pagos_path
    assert_select ".dato-secundario", /no aparece en el banco/
  end

  # ⚠️ Un rechazo sin explicación deja a la familia reportando lo mismo otra vez.
  test "no se rechaza sin decir por qué" do
    reporte = reportar!
    sign_in @dir_usuario

    patch rechazar_finanza_path(reporte), params: { motivo: "  " }

    assert_redirected_to finanza_path(reporte)
    con_el_colegio(@colegio) { assert reporte.reload.esperando_revision? }
  end

  # ⚠️ El dinero es otra gaveta: la coordinadora administra alumnos y NO valida
  # pagos.
  test "una coordinadora no entra a finanzas" do
    otro = con_el_colegio(@colegio) do
      u = usuario("coord", @colegio.id)
      Admin.create!(user: u, school: @colegio, role: :coordinador)
      u
    end
    sign_in otro

    get finanzas_path

    assert_response :redirect
  end

  test "un representante no entra a finanzas" do
    sign_in @rep_usuario
    get finanzas_path

    assert_response :redirect
  end

  private

  def reportar!
    con_el_colegio(@colegio) do
      reporte = PaymentReport.create!(representative: @representante, enrollment: @esc.inscripcion,
                                      referencia: "REF12345", banco: "0102", monto: 45,
                                      pagado_el: Date.current, depositante_nombre: "María Pérez")
      Charge.where(enrollment_id: @esc.inscripcion.id).update_all(payment_report_id: reporte.id)
      reporte
    end
  end
end
