require "test_helper"

# Las dos puertas: la familia reporta, la oficina valida — y lo que una familia
# en mora NO puede ver (spec: `docs/specs/pagos-de-la-familia.md`).
class PagosDeLaFamiliaTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(nombre: "Colegio de Pagos", alumnos: 2)
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

  # ⚠️ Daniel: *«el listado de los pagos debe ser en el orden: más reciente a
  # menos reciente»*. En trece cuotas, el mes en curso es lo que la familia
  # viene a mirar, y con el orden del calendario queda al final.
  test "las cuotas se listan de la más reciente a la más vieja" do
    con_el_colegio(@colegio) do
      Fee.create!(academic_period: @esc.periodo, nombre: "Octubre", monto: 45,
                  vence_el: Date.current - 5)
      Charge.emitir_para(@esc.inscripcion)
    end
    sign_in @rep_usuario

    get pagos_path

    cuotas = css_select(".tarjeta-de-pago tbody td:first-child").map(&:text)
    assert_equal [ "Octubre", "Septiembre" ], cuotas.first(2)
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

  # ⚠️ La lista de representados NO se bloquea —hay que poder ver a los hijos—
  # pero SÍ dice cuál está atrasado. Callarlo manda a la madre a chocar contra
  # el aviso, y con dos hijos ni siquiera sabe por cuál de los dos era.
  test "la lista de representados marca al que está en mora" do
    # ⚠️ Con DOS hijos: con uno solo la lista no se dibuja —se entra directo a
    # su pantalla, que es un paso menos para el caso común— así que el caso que
    # hay que probar es justamente el de la madre que tiene dos.
    con_el_colegio(@colegio) do
      otro = @esc.alumnos.last
      StudentRepresentative.create!(student: otro, representative: @representante)
      Charge.emitir_para(@esc.inscripciones.last)
    end
    sign_in @rep_usuario

    get representante_path

    assert_response :success
    assert_select ".portal-tarjeta-hijo .pastilla-de-cobro", /Falta ponerse al día/
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

  # ⚠️ Daniel: *«si tiene que revisar 400 vouchers en un día… si lo comparas
  # contra el banco y ves que todo está ok, no necesitas revisar»*. La bandeja
  # valida sin abrir la ficha.
  test "se valida desde la bandeja, sin abrir el reporte" do
    reportar!
    sign_in @dir_usuario

    get finanzas_path
    assert_select "form[action=?] input[type=submit], form[action=?] button",
                  validar_finanza_path(PaymentReport.last), validar_finanza_path(PaymentReport.last)
  end

  # ⚠️ Lo que hace RESPONSABLE al botón rápido: si la oficina validó de más, se
  # deshace. Sin esto, validar sin abrir sería una decisión sin vuelta atrás.
  test "revertir una validación devuelve la deuda tal como estaba" do
    reporte = reportar!
    sign_in @dir_usuario
    patch validar_finanza_path(reporte)
    con_el_colegio(@colegio) { assert Charge.first.reload.pagado? }

    patch rechazar_finanza_path(reporte), params: { motivo: "me equivoqué de fila" }

    con_el_colegio(@colegio) do
      cobro = Charge.first.reload
      assert_nil cobro.pagado_el, "un cobro revertido no puede quedar pagado"
      assert_nil cobro.payment_report_id
      assert EstadoDeCuenta.de(@esc.inscripcion).en_mora?, "vuelve a deber"
    end
  end

  # ⚠️ Un rechazo sin explicación deja a la familia reportando lo mismo otra vez.
  test "no se rechaza sin decir por qué" do
    reporte = reportar!
    sign_in @dir_usuario

    patch rechazar_finanza_path(reporte), params: { motivo: "  " }

    assert_redirected_to finanza_path(reporte)
    con_el_colegio(@colegio) { assert reporte.reload.esperando_revision? }
  end

  # ⚠️ Un grupo «Finanzas» que se ve y rebota enseña que los enlaces de este
  # sistema a veces no funcionan. El menú se hace la MISMA pregunta que el
  # controller.
  test "el menú de quien cobra lleva a finanzas; el de quien no, no lo muestra" do
    sign_in @dir_usuario
    get dashboards_administrador_path
    assert_select "a[href=?]", finanzas_path, minimum: 1

    coordinadora = con_el_colegio(@colegio) do
      u = usuario("coord2", @colegio.id)
      Admin.create!(user: u, school: @colegio, role: :coordinador)
      u
    end
    sign_in coordinadora
    get dashboards_administrador_path
    assert_select "a[href=?]", finanzas_path, 0
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
