require "test_helper"

# El vistazo final antes de que la familia vea su boletín.
#
# Daniel: *«las boletas deberán pasar por una revisión por parte de Admin antes
# de ser mostradas al representante… y cuando considere que todo está OK,
# liberar con un solo clic»*.
class LiberarBoletinesTest < ActionDispatch::IntegrationTest
  setup do
    # ⚠️ DOS alumnos: con uno solo, «el boletín de otro» es el mismo y el test
    # pasaría sin probar nada.
    @esc = escenario_academico(nombre: "Colegio de Boletines", nivel: :primaria, alumnos: 2)
    con_el_colegio(@esc.colegio) do
      @director = usuario("dir", @esc.colegio.id)
      Admin.create!(user: @director, school: @esc.colegio, role: :director)

      @rep_usuario = usuario("rep", @esc.colegio.id)
      @representante = Representative.create!(user: @rep_usuario, school: @esc.colegio)
      StudentRepresentative.create!(student: @esc.alumno, representative: @representante)
    end
  end

  # ── la revisión ───────────────────────────────────────────────────────────

  test "la oficina revisa los boletines de una sección, uno por uno" do
    emitir!
    sign_in @director

    get revisar_boletines_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)

    assert_response :success
    assert_select ".revisar-navegacion"
    assert_select ".revisar-quien", /1 de 2/
  end

  test "un representante no revisa boletines" do
    sign_in @rep_usuario

    get revisar_boletines_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)

    assert_response :redirect
  end

  # ── liberar ───────────────────────────────────────────────────────────────

  # ⚠️ Un boletín emitido y sin revisar EXISTE pero todavía no es de la familia.
  test "la familia no ve un boletín emitido hasta que lo liberan" do
    boletin = emitir!
    sign_in @rep_usuario

    get hijo_representante_path(@esc.alumno)
    assert_select "a[href=?]", boletin_path(boletin), 0

    con_el_colegio(@esc.colegio) { boletin.liberar!(por: @director) }

    get hijo_representante_path(@esc.alumno)
    assert_select "a[href=?]", boletin_path(boletin), 1
  end

  test "un clic libera todo el lapso de la sección" do
    emitir!
    sign_in @director

    assert_emails 1 do
      patch liberar_boletines_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)
    end

    con_el_colegio(@esc.colegio) { assert ReportCard.first.reload.liberado? }
  end

  # ⚠️ Reversible: si al liberar aparece un error, se vuelve a esconder con el
  # mismo clic. Un botón de una sola dirección obliga a escribir a soporte por
  # un dedazo.
  test "liberar se deshace" do
    boletin = emitir!
    sign_in @director
    patch liberar_boletines_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)

    patch esconder_boletines_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)

    con_el_colegio(@esc.colegio) { assert_not boletin.reload.liberado? }
  end

  # ── la descarga ───────────────────────────────────────────────────────────

  test "el representante descarga su boletín liberado" do
    boletin = emitir!
    con_el_colegio(@esc.colegio) { boletin.liberar!(por: @director) }
    sign_in @rep_usuario

    get boletin_path(boletin)

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  # ⚠️ El filtro va en la CONSULTA: un id ajeno da 404, no el documento de otra
  # familia.
  test "no se descarga el boletín de otro alumno" do
    ajeno = con_el_colegio(@esc.colegio) do
      otro = @esc.inscripciones.last
      b = ReportCard.create!(enrollment: otro, evaluation_moment: @esc.lapso(1),
                             issued_by: @director,
                             snapshot: ReportCardData.para(enrollment: otro,
                                                           evaluation_moment: @esc.lapso(1)))
      b.liberar!(por: @director)
      b
    end
    sign_in @rep_usuario

    get boletin_path(ajeno)

    assert_response :not_found
  end

  # ⚠️ La deuda bloquea también la descarga directa: si el botón se esconde pero
  # la URL se comparte, el bloqueo tiene que seguir de pie.
  test "en mora no se descarga, aunque se tenga el enlace" do
    boletin = emitir!
    con_el_colegio(@esc.colegio) do
      boletin.liberar!(por: @director)
      Fee.create!(academic_period: @esc.periodo, nombre: "Septiembre", monto: 45,
                  vence_el: Date.current - 30)
      Charge.emitir_para(@esc.inscripcion)
    end
    sign_in @rep_usuario

    get boletin_path(boletin)

    assert_response :payment_required
  end

  # ── el correo ─────────────────────────────────────────────────────────────

  # ⚠️ Mandarle a una familia en mora «ya puede descargarlo» es prometerle una
  # pantalla que la va a rebotar.
  test "el correo dice lo que la familia va a encontrar" do
    boletin = emitir!

    # ⚠️ Se RENDERIZA dentro del bloque del colegio, no solo se construye.
    #
    # `mail()` es perezoso: arma el objeto y no toca las plantillas hasta que
    # alguien pide el cuerpo. Pedirlo afuera lo renderiza sin `Current.school`,
    # así que `EstadoDeCuenta` y los representantes salen vacíos y el correo
    # llega en blanco — sin fallar.
    assert_match(/descargarlo/i,
                 con_el_colegio(@esc.colegio) { cuerpo_de(BoletinMailer.liberado(boletin)) })

    con_el_colegio(@esc.colegio) do
      Fee.create!(academic_period: @esc.periodo, nombre: "Septiembre", monto: 45,
                  vence_el: Date.current - 30)
      Charge.emitir_para(@esc.inscripcion)
    end

    en_mora = con_el_colegio(@esc.colegio) { cuerpo_de(BoletinMailer.liberado(boletin.reload)) }
    assert_match(/al día con el colegio/i, en_mora)
    # ⚠️ NO es un correo de cobranza: sin monto y sin reclamo.
    assert_no_match(/45,00|debe \d/, en_mora)
  end

  private

  # ⚠️ `parts` está vacío hasta que el correo se RENDERIZA: `deliver_now` lo
  # fuerza, y en test no sale a ninguna parte.
  def cuerpo_de(correo)
    correo.deliver_now
    [ correo.html_part, correo.text_part ].compact.map { |p| p.body.to_s }.join("\n")
  end

  def emitir!
    con_el_colegio(@esc.colegio) do
      ReportCard.create!(enrollment: @esc.inscripcion, evaluation_moment: @esc.lapso(1),
                         issued_by: @director,
                         snapshot: ReportCardData.para(enrollment: @esc.inscripcion,
                                                       evaluation_moment: @esc.lapso(1)))
    end
  end
end
