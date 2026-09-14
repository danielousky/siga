require "test_helper"

# Los pagos de la familia (spec: `docs/specs/pagos-de-la-familia.md`).
#
# Lo que se prueba es lo que se rompe en silencio: el calendario de agosto, que
# un reporte no pague solo, que rechazar suelte los cobros, y que la mora no
# alcance a quien ya reportó.
class PagosTest < ActiveSupport::TestCase
  setup do
    @esc = escenario_academico(nombre: "Colegio de Pagos")
    @colegio = @esc.colegio
  end

  # ── el calendario ─────────────────────────────────────────────────────────

  # ⚠️ Daniel, corrigiendo: *«ese mes en particular, ¿ok? Ese mes en particular,
  # no todos»*. Agosto vence en julio; ningún otro mes va adelantado.
  test "agosto vence en julio y NINGÚN otro mes se adelanta" do
    periodo = Struct.new(:start_date).new(Date.new(2026, 9, 15))
    calendario = Fee.calendario_propuesto(periodo, mensualidad: 45, inscripcion: 120).index_by { |c| c[:nombre] }

    assert_equal 7, calendario["Agosto"][:vence_el].month, "agosto se paga en julio"
    assert_equal 7, calendario["Julio"][:vence_el].month
    assert_equal 9, calendario["Septiembre"][:vence_el].month
    assert_equal 1, calendario["Enero"][:vence_el].month

    # Y no el mismo día que julio: son dos cuotas, no dos veces la misma.
    assert_not_equal calendario["Julio"][:vence_el], calendario["Agosto"][:vence_el]
  end

  test "la inscripción vence antes que el primer mes" do
    periodo = Struct.new(:start_date).new(Date.new(2026, 9, 15))
    calendario = Fee.calendario_propuesto(periodo, mensualidad: 45, inscripcion: 120).index_by { |c| c[:nombre] }

    assert calendario["Inscripción"][:vence_el] < calendario["Septiembre"][:vence_el]
  end

  # ── los cobros ────────────────────────────────────────────────────────────

  # ⚠️ El monto se COPIA del concepto: si en marzo el colegio sube la
  # mensualidad, lo que este alumno debía en septiembre no cambia solo.
  test "subirle el precio al concepto no cambia lo que ya se debía" do
    con_el_colegio(@colegio) do
      concepto = crear_concepto("Septiembre", 45, Date.current - 10)
      Charge.emitir_para(@esc.inscripcion)
      cobro = Charge.find_by(fee_id: concepto.id)

      concepto.update!(monto: 60)

      assert_equal 45, cobro.reload.monto.to_i
    end
  end

  # ⚠️ Idempotente, como `CopiarLaEstructura`.
  test "emitir dos veces no duplica cobros" do
    con_el_colegio(@colegio) do
      crear_concepto("Septiembre", 45, Date.current - 10)
      Charge.emitir_para(@esc.inscripcion)

      assert_no_difference "Charge.count" do
        Charge.emitir_para(@esc.inscripcion)
      end
    end
  end

  # ── la mora ───────────────────────────────────────────────────────────────

  # ⚠️ Lo que vence la semana que viene NO es deuda. Cobrarle a alguien por algo
  # que todavía no toca es la manera más rápida de que un colegio deje esto.
  test "lo que todavía no vence no es mora" do
    con_el_colegio(@colegio) do
      crear_concepto("Octubre", 45, Date.current + 20)
      Charge.emitir_para(@esc.inscripcion)

      assert EstadoDeCuenta.de(@esc.inscripcion).al_dia?
    end
  end

  # ⚠️ Los días de gracia: un pago del 5 que la oficina valida el 8 no puede
  # dejar a la familia sin notas el 6 — y menos cuando el 5 cayó domingo.
  test "hay días de gracia después del vencimiento" do
    con_el_colegio(@colegio) do
      crear_concepto("Septiembre", 45, Date.current - 2)
      Charge.emitir_para(@esc.inscripcion)

      assert EstadoDeCuenta.de(@esc.inscripcion).al_dia?, "dos días no es mora todavía"
    end
  end

  test "una cuota vencida hace tiempo sí es mora" do
    con_el_colegio(@colegio) do
      crear_concepto("Septiembre", 45, Date.current - 30)
      Charge.emitir_para(@esc.inscripcion)

      estado = EstadoDeCuenta.de(@esc.inscripcion)
      assert estado.en_mora?
      assert_equal [ "Septiembre" ], estado.meses_que_debe
      assert_equal 45, estado.deuda.to_i
    end
  end

  # ⚠️ Quien ya reportó NO queda bloqueado mientras la oficina revisa. El daño
  # de castigar a quien pagó por la demora de un tercero es mayor que el riesgo
  # de que alguien reporte un pago falso.
  test "lo reportado no cuenta como mora" do
    con_el_colegio(@colegio) do
      crear_concepto("Septiembre", 45, Date.current - 30)
      Charge.emitir_para(@esc.inscripcion)
      reportar!

      assert EstadoDeCuenta.de(@esc.inscripcion).al_dia?
    end
  end

  # ── el reporte ────────────────────────────────────────────────────────────

  # ⚠️ Un reporte NO paga nada por sí solo. Sin esto, quien escriba cualquier
  # número de referencia se libera el acceso a las notas.
  test "reportar no paga: hace falta que la oficina valide" do
    con_el_colegio(@colegio) do
      crear_concepto("Septiembre", 45, Date.current - 30)
      Charge.emitir_para(@esc.inscripcion)
      reporte = reportar!

      assert_not Charge.first.pagado?
      assert reporte.esperando_revision?

      reporte.validar!(por: admin_del_colegio)

      assert Charge.first.reload.pagado?
      assert reporte.reload.validado?
    end
  end

  # ⚠️ Al rechazar, los cobros se SUELTAN: la familia puede volver a reportarlos
  # con la referencia correcta. Dejarlos colgando los deja en un limbo.
  test "rechazar suelta los cobros y vuelven a deberse" do
    con_el_colegio(@colegio) do
      crear_concepto("Septiembre", 45, Date.current - 30)
      Charge.emitir_para(@esc.inscripcion)
      reporte = reportar!

      reporte.rechazar!(por: admin_del_colegio, motivo: "no aparece en el banco")

      cobro = Charge.first.reload
      assert_nil cobro.payment_report_id
      assert_not cobro.pagado?
      assert EstadoDeCuenta.de(@esc.inscripcion).en_mora?, "vuelve a deber"
    end
  end

  # ── la referencia ─────────────────────────────────────────────────────────

  # ⚠️ Los espacios y los puntos que copia la gente del SMS del banco convierten
  # «0012 3456» y «00123456» en dos referencias distintas, y entonces el índice
  # único no impide el reporte repetido — que es para lo que existe.
  test "la referencia se normaliza a mayúscula sin espacios ni puntos" do
    con_el_colegio(@colegio) do
      crear_concepto("Septiembre", 45, Date.current - 30)
      Charge.emitir_para(@esc.inscripcion)

      assert_equal "0012-3456", reportar!(referencia: " 0012-34.56 ").referencia
    end
  end

  test "la misma referencia no se puede reportar dos veces en el colegio" do
    con_el_colegio(@colegio) do
      crear_concepto("Septiembre", 45, Date.current - 30)
      crear_concepto("Octubre", 45, Date.current - 5)
      Charge.emitir_para(@esc.inscripcion)
      reportar!(referencia: "REPETIDA1")

      repetido = nuevo_reporte(referencia: "REPETIDA1")

      assert_not repetido.valid?
      assert_includes repetido.errors[:referencia].to_s, "ya fue reportada"
    end
  end

  # ⚠️ El calendario no ofrece el año pasado: el dedazo de año —«03/09/2025» en
  # vez de 2026— deja un pago que nadie encuentra en el banco.
  test "no se reporta un pago de hace más de un mes ni uno del futuro" do
    con_el_colegio(@colegio) do
      viejo = nuevo_reporte(pagado_el: 3.months.ago.to_date)
      assert_not viejo.valid?

      futuro = nuevo_reporte(pagado_el: Date.current + 2)
      assert_not futuro.valid?
    end
  end

  test "el banco tiene que estar en la lista" do
    con_el_colegio(@colegio) do
      assert_not nuevo_reporte(banco: "9999").valid?
      assert nuevo_reporte(banco: "0102").valid?
    end
  end

  # ── el voucher ────────────────────────────────────────────────────────────

  # ⚠️ ESTE TEST FALTABA, y su ausencia dejó la función sin hacer nada.
  #
  # `EncogeElVoucher` tiene un `rescue StandardError` a propósito —perder el
  # reporte por no poder encoger una foto sería mucho peor que guardarla
  # entera— y eso se tragó un «invalid source»: `ImageProcessing::Vips.source`
  # no acepta un `StringIO`. El voucher se guardaba de 714 KB, el log decía una
  # línea que nadie leyó, y nada fallaba.
  #
  # Un rescue así SOLO es aceptable con un test que compare los bytes.
  test "el voucher se guarda encogido, no como salió del teléfono" do
    con_el_colegio(@colegio) do
      reporte = nuevo_reporte
      reporte.save!
      reporte.voucher.attach(io: File.open(voucher_de_prueba), filename: "voucher.jpg",
                             content_type: "image/jpeg")
      antes = reporte.voucher.blob.byte_size
      assert_operator antes, :>, EncogeElVoucher::DESDE, "el de prueba tiene que ser grande"

      EncogeElVoucher.new(reporte.voucher).encoger!

      despues = reporte.reload.voucher.blob.byte_size
      assert_operator despues, :<, antes / 2, "de #{antes} bytes a #{despues} no es encoger"
      assert_equal "image/jpeg", reporte.voucher.blob.content_type
    end
  end

  # ⚠️ Un PDF no se toca: redibujarlo como imagen le quita el texto
  # seleccionable, que es justo lo que hace fácil buscar la referencia.
  test "un PDF se guarda tal cual" do
    con_el_colegio(@colegio) do
      reporte = nuevo_reporte
      reporte.save!
      reporte.voucher.attach(io: StringIO.new("%PDF-1.4\n" + ("x" * 500_000)),
                             filename: "comprobante.pdf", content_type: "application/pdf")
      antes = reporte.voucher.blob.byte_size

      EncogeElVoucher.new(reporte.voucher).encoger!

      assert_equal antes, reporte.reload.voucher.blob.byte_size
      assert_equal "application/pdf", reporte.voucher.blob.content_type
    end
  end

  private

  def voucher_de_prueba = Rails.root.join("db/qa/voucher_de_prueba.jpg")

  def crear_concepto(nombre, monto, vence_el)
    Fee.create!(academic_period: @esc.periodo, nombre: nombre, monto: monto, vence_el: vence_el)
  end

  def representante_del_alumno
    @representante_del_alumno ||= begin
      usuario = usuario("rep", @colegio.id)
      rep = Representative.create!(user: usuario, school: @colegio)
      StudentRepresentative.create!(student: @esc.alumno, representative: rep)
      rep
    end
  end

  def admin_del_colegio
    @admin_del_colegio ||= begin
      usuario = usuario("dir", @colegio.id)
      Admin.create!(user: usuario, school: @colegio, role: :director)
      usuario
    end
  end

  def nuevo_reporte(**cambios)
    PaymentReport.new({ representative: representante_del_alumno, enrollment: @esc.inscripcion,
                        referencia: "REF#{rand(100_000)}", banco: "0102", monto: 45,
                        pagado_el: Date.current, depositante_nombre: "María Pérez" }.merge(cambios))
  end

  def reportar!(**cambios)
    reporte = nuevo_reporte(**cambios)
    reporte.save!
    Charge.where(enrollment_id: @esc.inscripcion.id).sin_reportar
          .update_all(payment_report_id: reporte.id)
    reporte
  end
end
