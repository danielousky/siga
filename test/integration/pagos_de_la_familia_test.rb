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
    assert_select ".detail-label", text: "Vencido"
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

    cuotas = css_select("table.table-academic tbody td:first-child").map(&:text)
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

  # ⚠️ Daniel: *«yo tengo dos hijos… cuando hago un pago no hago un pago para
  # uno y un pago para el otro. Hago el pago de los dos. Eso es lo natural»*.
  test "un solo pago cubre cuotas de dos representados" do
    segunda = con_el_colegio(@colegio) do
      otra = @esc.inscripciones.last
      StudentRepresentative.create!(student: otra.student, representative: @representante)
      Charge.emitir_para(otra)
      Charge.where(enrollment_id: otra.id).first
    end
    primera = con_el_colegio(@colegio) { Charge.where(enrollment_id: @esc.inscripcion.id).first }
    sign_in @rep_usuario

    post pagos_path, params: {
      cobros: [ primera.id, segunda.id ],
      payment_report: { referencia: "0012-8888", banco: "0102", monto: 90,
                        pagado_el: Date.current, depositante_nombre: "María Pérez" }
    }

    assert_redirected_to pagos_path
    con_el_colegio(@colegio) do
      reporte = PaymentReport.last
      assert_equal 2, reporte.charges.count
      assert_equal 2, reporte.inscripciones.count, "el pago alcanza a los dos hijos"
      assert_includes reporte.por_quienes, " y ", "dice a quiénes cubre"
    end
  end

  # ⚠️ La deuda es UNA. Daniel: *«debe ser vista y reportada como tal, sin
  # importar los hijos que se tengan estudiando»*.
  test "la tarjeta suma la deuda de todos los hijos y ofrece UN botón" do
    con_el_colegio(@colegio) do
      otra = @esc.inscripciones.last
      StudentRepresentative.create!(student: otra.student, representative: @representante)
      Charge.emitir_para(otra)
    end
    sign_in @rep_usuario

    get pagos_path

    assert_select "a[href=?]", new_pago_path, 1, "un solo botón, general"
    assert_select ".pestanas .pestana", 2, "una pestaña por hijo"
    # 45 de cada uno: la deuda del colegio es 90, no dos de 45.
    assert_select ".detail-item", /90,00/
  end

  # ⚠️ Un año sin cuotas cargadas no es una tarjeta: es ruido. Daniel: «esa
  # información debería estar en un histórico».
  test "un año sin cuotas no se muestra" do
    vieja = con_el_colegio(@colegio) do
      periodo = AcademicPeriod.create!(name: "2023-2024", start_date: Date.new(2023, 9, 15),
                                       end_date: Date.new(2024, 7, 31))
      seccion = Section.create!(grade: @esc.grado, academic_period: periodo, name: "Z", capacity: 30)
      Enrollment.create!(student: @esc.alumno, section: seccion, enrollment_date: Date.new(2023, 9, 20))
    end
    sign_in @rep_usuario

    get pagos_path

    assert_select ".pestana", text: /#{vieja.section.academic_period.name}/, count: 0
    assert_no_match(/todavía no tiene cuotas/, response.body,
                    "un año sin cuotas cargadas no es una tarjeta, es ruido")
  end

  # ── la moneda ─────────────────────────────────────────────────────────────
  #
  # Daniel: *«hay un vacío legal en el país… lo más salomónico es ocultarle al
  # representante la unidad de pago»*. En la práctica el colegio lleva sus
  # cuentas en dólares y la familia transfiere en bolívares.

  # ⚠️ A la familia, el número desnudo: SIGA no afirma una moneda que hoy no
  # puede respaldar.
  test "al representante no se le muestra la unidad" do
    sign_in @rep_usuario

    get pagos_path

    assert_no_match(/\d,\d\d\s*\$/, response.body,
                    "la pantalla de la familia no lleva el símbolo del dólar")
  end

  # ⚠️ Adentro SÍ, porque quien cobra tiene que ver la unidad de cuenta para
  # poder avalar la equivalencia.
  test "finanzas ve lo que cubre en $ y lo transferido en Bs, sin compararlos" do
    reporte = reportar!
    sign_in @dir_usuario

    get finanza_path(reporte)

    assert_select ".equivalencia .detail-value", /\$/, "la unidad de cuenta del colegio"
    assert_select ".equivalencia .detail-value", /Bs/, "lo que dice el voucher"
    # Restar bolívares de dólares no significa nada: el aviso de «no cuadra» se
    # cayó a propósito.
    assert_no_match(/y el reporte dice/, response.body)
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
        payment_report: { referencia: "0012-3456", banco: "0102", monto: 45,
                          pagado_el: Date.current, depositante_nombre: "María Pérez" }
      }
    end

    assert_response :unprocessable_entity
  end

  # ⚠️ Cambiar el id en la URL no puede dejar reportar contra la inscripción de
  # otro alumno — ni mirar su estado de cuenta.
  # ⚠️ Un reporte ya no nombra una inscripción: lo que hay que impedir es que se
  # marque la CUOTA de otra familia mandando su id a mano.
  test "no se reporta una cuota de otra familia" do
    # El segundo alumno del escenario NO es representado de @representante, así
    # que sus cuotas son «de otra familia».
    ajena = con_el_colegio(@colegio) do
      otra = @esc.inscripciones.last
      Charge.emitir_para(otra)
      Charge.where(enrollment_id: otra.id).first
    end
    sign_in @rep_usuario

    assert_no_difference "con_el_colegio(@colegio) { PaymentReport.count }" do
      post pagos_path, params: {
        cobros: [ ajena.id ],
        payment_report: { referencia: "0012-7777", banco: "0102", monto: 45,
                          pagado_el: Date.current, depositante_nombre: "María Pérez" }
      }
    end

    assert_response :unprocessable_entity
  end

  # ── corregir, del lado de la familia ──────────────────────────────────────
  #
  # Daniel: *«el error humano es posible, entonces deben poder corregir»* — y lo
  # dijo de las DOS partes. La madre copia la referencia del SMS y baila dos
  # dígitos; sin esto no puede editar, no puede retirar y no puede volver a
  # reportar (la referencia es única), así que solo le queda esperar el rechazo.

  # ⚠️ Y al REPORTAR no viene ninguna marcada.
  #
  # `cobro.payment_report_id == @reporte.id` decía que sí para todas en un
  # reporte nuevo —los dos lados son `nil`, y `nil == nil` es verdadero— así que
  # el formulario abría con las trece cuotas marcadas y un descuido las reportaba
  # todas.
  test "reportar abre con las cuotas SIN marcar" do
    sign_in @rep_usuario

    get new_pago_path

    assert_select "input[name='cobros[]']", minimum: 1
    assert_select "input[name='cobros[]'][checked]", 0
  end

  # ⚠️ Sin esto, abrir «Corregir» muestra las cuotas EN BLANCO y guardar suelta
  # las que la familia sí había reportado. Lo vi en pantalla, no en un test: el
  # reemplazo que lo ponía no aplicó y no se quejó.
  test "corregir abre con las cuotas que ya había marcado" do
    reporte = reportar!
    sign_in @rep_usuario

    get edit_pago_path(reporte)

    marcadas = css_select("input[name='cobros[]'][checked]").map { |i| i["value"].to_i }
    assert_equal con_el_colegio(@colegio) { reporte.charges.pluck(:id).sort }, marcadas.sort
    assert marcadas.any?, "el formulario de corregir no puede abrir en blanco"
  end

  test "la familia corrige su reporte mientras nadie lo ha mirado" do
    reporte = reportar!
    sign_in @rep_usuario
    cobro = con_el_colegio(@colegio) { Charge.first }

    patch pago_path(reporte), params: {
      cobros: [ cobro.id ],
      payment_report: { referencia: "0012-9999", banco: "0102", monto: 45,
                        pagado_el: Date.current, depositante_nombre: "María Pérez" }
    }

    assert_redirected_to pagos_path
    con_el_colegio(@colegio) do
      assert_equal "0012-9999", reporte.reload.referencia
      assert reporte.corregido?, "queda la marca de que se tocó"
    end
  end

  # ⚠️ Después de la revisión NO: editar un validado convierte el papel que la
  # oficina ya comparó con el banco en otro papel, y nadie se entera. Quien se
  # equivocó ahí lo arregla por el otro lado —revertir o revalidar—.
  test "un pago ya revisado no lo corrige la familia" do
    reporte = reportar!
    sign_in @dir_usuario
    patch validar_finanza_path(reporte)

    sign_in @rep_usuario
    get edit_pago_path(reporte)

    assert_redirected_to pagos_path
  end

  # ⚠️ Cambiar el id en la URL no puede dejar corregir el reporte de otra
  # familia.
  test "no se corrige el reporte de otro representante" do
    reporte = reportar!
    otra = con_el_colegio(@colegio) do
      u = usuario("otrarep", @colegio.id)
      Representative.create!(user: u, school: @colegio)
      u
    end
    sign_in otra

    get edit_pago_path(reporte)

    assert_response :not_found
  end

  # Retirarlo entero: el error no fue un dato, fue el reporte completo.
  test "retirar el reporte deja las cuotas libres otra vez" do
    reporte = reportar!
    sign_in @rep_usuario

    assert_difference "con_el_colegio(@colegio) { PaymentReport.count }", -1 do
      delete pago_path(reporte)
    end

    con_el_colegio(@colegio) do
      assert_nil Charge.first.reload.payment_report_id
      assert EstadoDeCuenta.de(@esc.inscripcion).en_mora?, "vuelve a deber"
    end
  end

  # ⚠️ El caso que muerde no es que la familia se equivoque: es que la oficina
  # abra el reporte, se vaya al banco a buscar la referencia, y mientras tanto
  # la familia la cambie. Vuelve, valida, y validó números que nunca leyó.
  test "la bandeja avisa que un reporte se corrigió" do
    reporte = reportar!
    con_el_colegio(@colegio) { reporte.update!(corregido_el: Time.current) }
    sign_in @dir_usuario

    get finanzas_path

    assert_select ".dato-secundario", /corregido hace/
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

  # ⚠️ Sin esto hay un CALLEJÓN SIN SALIDA: la referencia es única por colegio,
  # así que a una familia a la que le rechazaron un pago bueno no le queda
  # ninguna puerta — no puede volver a reportar el mismo número.
  test "un rechazado por error se valida después" do
    reporte = reportar!
    sign_in @dir_usuario
    patch rechazar_finanza_path(reporte), params: { motivo: "no la vi en el banco" }
    con_el_colegio(@colegio) { assert_not Charge.first.reload.pagado? }

    patch validar_finanza_path(reporte)

    con_el_colegio(@colegio) do
      assert reporte.reload.validado?
      assert Charge.first.reload.pagado?, "las cuotas que declaró vuelven a quedar pagadas"
    end
  end

  # ⚠️ Pero NO pisa un reporte nuevo: si el rechazo fue correcto y la familia ya
  # volvió a reportar esas cuotas, revalidar el viejo las robaría del nuevo.
  test "revalidar un rechazado no pisa lo que la familia reportó después" do
    viejo = reportar!
    sign_in @dir_usuario
    patch rechazar_finanza_path(viejo), params: { motivo: "referencia equivocada" }

    nuevo = con_el_colegio(@colegio) do
      r = PaymentReport.create!(representative: @representante,
                                referencia: "REF99999", banco: "0102", monto: 45,
                                pagado_el: Date.current, depositante_nombre: "María Pérez")
      r.declarar!(Charge.where(enrollment_id: @esc.inscripcion.id))
      r
    end

    patch validar_finanza_path(viejo)

    assert_redirected_to finanza_path(viejo)
    con_el_colegio(@colegio) do
      assert viejo.reload.rechazado?, "no se revalida sobre cuotas que ya son de otro"
      assert_equal nuevo.id, Charge.first.reload.payment_report_id
    end
  end

  # ⚠️ Daniel: *«esta lista debería tener enlaces al detalle del deudor»*. Una
  # lista de cobranza que no lleva a ningún lado obliga a buscar al alumno por
  # el menú de Usuarios, que es otro camino y otra pantalla.
  test "la lista de morosos enlaza al estado de cuenta del alumno" do
    sign_in @dir_usuario

    get finanzas_path

    assert_select "a[href=?]", deudor_path(@esc.inscripcion), minimum: 1
  end

  # ⚠️ Lo que la oficina hace DESPUÉS de ver que alguien debe es LLAMAR. Una
  # pantalla de cobranza que muestra la deuda y no el teléfono manda a buscarlo
  # a otro menú.
  test "el detalle del deudor trae a quién llamar y qué debe" do
    con_el_colegio(@colegio) do
      @representante.update!(phone: "0414-1234567")
      StudentRepresentative.create!(student: @esc.alumno, representative: @representante,
                                    parentesco: :madre) unless StudentRepresentative.exists?(student_id: @esc.alumno.id, representative_id: @representante.id)
    end
    sign_in @dir_usuario

    get deudor_path(@esc.inscripcion)

    assert_response :success
    assert_select "a[href^=?]", "tel:", minimum: 1, message: "hace falta el teléfono para cobrar"
    assert_select ".pastilla-de-cobro", text: "Vencido", minimum: 1
  end

  test "solo quien cobra ve el detalle del deudor" do
    sign_in @rep_usuario

    get deudor_path(@esc.inscripcion)

    assert_response :redirect
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
      reporte = PaymentReport.create!(representative: @representante,
                                      referencia: "REF12345", banco: "0102", monto: 45,
                                      pagado_el: Date.current, depositante_nombre: "María Pérez")
      reporte.declarar!(Charge.where(enrollment_id: @esc.inscripcion.id))
      reporte
    end
  end
end
