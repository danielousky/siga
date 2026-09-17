require "test_helper"

# La pantalla que faltaba para poder cobrar.
#
# Los conceptos existían en la base y solo los creaba la tarea de demostración:
# un director real abría SIGA, veía la bandeja de pagos y no tenía dónde decir
# cuánto cuesta la inscripción. La cobranza entera colgaba de un `rake`.
class LoQueElColegioCobraTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(nombre: "Colegio que Cobra")
    @director = con_el_colegio(@esc.colegio) do
      u = usuario("dir", @esc.colegio.id)
      Admin.create!(user: u, school: @esc.colegio, role: :director)
      u
    end
  end

  test "el colegio carga una cuota" do
    sign_in @director

    assert_difference "con_el_colegio(@esc.colegio) { Fee.count }", 1 do
      post academic_period_cobros_path(@esc.periodo),
           params: { fee: { nombre: "Inscripción", monto: 120, vence_el: Date.current } }
    end

    assert_redirected_to academic_period_cobros_path(@esc.periodo)
  end

  # ⚠️ El calendario habitual, para no escribir trece filas a mano. Y agosto
  # vence en JULIO —solo agosto— que es la regla que nadie recuerda al cargarlo.
  test "proponer el calendario deja agosto venciendo en julio" do
    sign_in @director

    post proponer_academic_period_cobros_path(@esc.periodo),
         params: { mensualidad: 45, inscripcion: 120 }

    con_el_colegio(@esc.colegio) do
      assert_equal 13, Fee.count
      assert_equal 7, Fee.find_by(nombre: "Agosto").vence_el.month
      assert_equal 7, Fee.find_by(nombre: "Julio").vence_el.month
      assert_equal 9, Fee.find_by(nombre: "Septiembre").vence_el.month
    end
  end

  test "sin mensualidad no propone nada" do
    sign_in @director

    assert_no_difference "con_el_colegio(@esc.colegio) { Fee.count }" do
      post proponer_academic_period_cobros_path(@esc.periodo), params: { mensualidad: 0 }
    end
  end

  # ⚠️ Lo primero que un director asume al revés: su cuota copió el monto el día
  # que se emitió, igual que un boletín copia sus notas.
  test "cambiar el monto no cambia lo que un alumno ya debe" do
    concepto = con_el_colegio(@esc.colegio) do
      c = Fee.create!(academic_period: @esc.periodo, nombre: "Septiembre",
                      monto: 45, vence_el: Date.current)
      Charge.emitir_para(@esc.inscripcion)
      c
    end
    sign_in @director

    patch cobro_path(concepto), params: { fee: { nombre: "Septiembre", monto: 60,
                                                 vence_el: Date.current } }

    con_el_colegio(@esc.colegio) do
      assert_equal 60, concepto.reload.monto.to_i
      assert_equal 45, Charge.first.monto.to_i, "la cuota ya emitida no cambia"
    end
  end

  # ⚠️ Borrarlo dejaría a las familias con una cuota que no dice de qué es.
  test "un concepto con cuotas emitidas no se borra" do
    concepto = con_el_colegio(@esc.colegio) do
      c = Fee.create!(academic_period: @esc.periodo, nombre: "Septiembre",
                      monto: 45, vence_el: Date.current)
      Charge.emitir_para(@esc.inscripcion)
      c
    end
    sign_in @director

    assert_no_difference "con_el_colegio(@esc.colegio) { Fee.count }" do
      delete cobro_path(concepto)
    end
  end

  # ⚠️ Lo define quien COBRA: es el precio del colegio. La coordinadora carga la
  # matrícula y no le pone precio.
  test "la coordinadora no define lo que se cobra" do
    coordinadora = con_el_colegio(@esc.colegio) do
      u = usuario("coord", @esc.colegio.id)
      Admin.create!(user: u, school: @esc.colegio, role: :coordinador)
      u
    end
    sign_in coordinadora

    get academic_period_cobros_path(@esc.periodo)

    assert_response :redirect
  end
end
