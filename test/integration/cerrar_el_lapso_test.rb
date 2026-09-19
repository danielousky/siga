require "test_helper"

# Control de Estudio cierra el lapso (QA de Cyndi).
#
# Daniel, 18 de septiembre: *«CE mira las boletas y da por "cerrado" el proceso
# de carga y completación de la calificación. Al dar el visto bueno se envía el
# correo al representante y ya puede entrar a ver sus notas, y a su vez el profe
# ya no puede modificar las notas»*.
#
#     POR CALIFICAR ──► CALIFICADA ──► CERRADA
#      falta una nota   están todas    alguien miró y firmó
#
# ⚠️ Cerrar REEMPLAZÓ a liberar, y no es el mismo botón con otro nombre:
# liberar dejaba salir lo emitido aunque faltaran notas en otros boletines.
class CerrarElLapsoTest < ActionDispatch::IntegrationTest
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

  # ── cerrar ────────────────────────────────────────────────────────────────

  test "un clic cierra el lapso: emite, libera, avisa y traba las notas" do
    calificar_todo!
    sign_in @director

    assert_difference -> { cantidad(SectionClosure) }, 1 do
      patch cerrar_lapso_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)
    end

    con_el_colegio(@esc.colegio) do
      # Se emitieron los DOS, aunque no hubiera ninguno antes.
      boletines = ReportCard.where(evaluation_moment_id: @esc.lapso(1).id)
      assert_equal 2, boletines.count, "cerrar emite los que falten"
      assert boletines.all?(&:liberado?), "y los libera: la familia tiene que poder verlos"

      cierre = SectionClosure.find_by(section_id: @esc.seccion.id,
                                      evaluation_moment_id: @esc.lapso(1).id)
      assert_equal @director.id, cierre.cerrado_por_id, "queda quién dio el visto bueno"
    end

    get revisar_boletines_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)
    assert_select ".detail-value", text: "Cerrada"
  end

  # ⚠️ Lo que Daniel pidió y el código hacía al revés: liberar dejaba salir lo
  # emitido aunque faltaran notas. Cerrar exige el 100 %.
  test "no se cierra un lapso con materias sin nota" do
    sign_in @director

    assert_no_difference -> { cantidad(SectionClosure) } do
      patch cerrar_lapso_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)
    end

    assert_match(/sin nota/i, flash[:alert])
  end

  # ⚠️ El informe descriptivo también IMPIDE cerrar, no solo avisa.
  #
  # Daniel, 19 de septiembre: *«sí, el informe debe ser obligatorio para
  # cerrar»*. Una boleta sin una línea del docente es una factura: el «PA» dice
  # en qué banda cayó el niño y el informe dice que lee mejor que en octubre.
  test "con las notas completas pero sin informes, tampoco se cierra" do
    solo_las_notas!
    sign_in @director

    assert_no_difference -> { cantidad(SectionClosure) } do
      patch cerrar_lapso_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)
    end

    assert_match(/sin informe descriptivo/i, flash[:alert])
  end

  # ⚠️ Y la pantalla lo dice con las palabras de ese estado: las notas están, lo
  # que falta es otra cosa. Con el mensaje de las notas mandaría a buscar algo
  # que ya está hecho.
  test "la pantalla dice que lo que falta son los informes" do
    solo_las_notas!
    sign_in @director

    get revisar_boletines_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)

    assert_response :success
    assert_select ".detail-value", text: "Calificada"
    assert_select ".revisar-faltantes li", 2
    assert_select "a[href*=?]", "informes", true, "y lleva a escribirlos"
    assert_select "form[action*=?]", "cerrar", 0
  end

  # ⚠️ Y la pantalla dice QUIÉNES faltan, no «no se puede»: quien revisa tiene
  # que saber a quién perseguir.
  test "la pantalla lista a los que le faltan notas" do
    sign_in @director

    get revisar_boletines_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)

    assert_response :success
    assert_select ".revisar-faltantes li", 2
    assert_select "form[action*=?]", "cerrar", 0, "sin el 100 % no hay botón de cerrar"
    # ⚠️ Y el estado se dice con su nombre, que es lo que Daniel pidió.
    assert_select ".detail-value", text: "Por calificar"
  end

  # ⚠️ Es lo que hace que el cierre signifique algo: sin esto, el profesor
  # cambia una nota y el boletín que la familia ya descargó dice otra cosa.
  test "cerrado el lapso, el profesor no puede tocar las notas" do
    calificar_todo!
    sign_in @director
    patch cerrar_lapso_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)

    con_el_colegio(@esc.colegio) do
      nota = ActivityGrade.first
      nota.score = 5

      assert_not nota.save, "la nota se guardó con el lapso cerrado"
      assert_match(/cerró este lapso/i, nota.errors.full_messages.to_sentence)

      # Borrar también es cambiar: vaciar el campo de la planilla es un destroy.
      assert_not nota.destroy, "la nota se borró con el lapso cerrado"

      # Y la EVALUACIÓN tampoco: cambiarle el peso recalcula a los treinta.
      actividad = EvaluationActivity.first
      actividad.weight_percentage = 50
      assert_not actividad.save, "se cambió la ponderación con el lapso cerrado"
    end
  end

  # ⚠️ Reabrir existe porque un error en una nota se descubre DESPUÉS de cerrar.
  # Sin esta puerta, la única salida sería tocar la base.
  test "reabrir deshace el cierre y el profesor vuelve a poder cargar" do
    calificar_todo!
    sign_in @director
    patch cerrar_lapso_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)

    assert_difference -> { cantidad(SectionClosure) }, -1 do
      patch reabrir_lapso_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)
    end

    con_el_colegio(@esc.colegio) do
      assert ReportCard.where(evaluation_moment_id: @esc.lapso(1).id).none?(&:liberado?),
             "las familias dejan de verlos"
      nota = ActivityGrade.first
      nota.score = 5
      assert nota.save, "el profesor tiene que volver a poder cargar"
    end
  end

  # ⚠️ Un alumno RETIRADO no tiene notas y nunca las va a tener. Contándolo, la
  # sección se quedaba en «por calificar» para siempre y el visto bueno no
  # llegaba nunca — y tampoco se le emite boletín.
  test "un alumno retirado no impide cerrar el lapso" do
    con_el_colegio(@esc.colegio) do
      @esc.inscripciones.last.update!(status: :retirado)
      calificar!(solo: [ @esc.inscripcion ])
    end
    sign_in @director

    assert_difference -> { cantidad(SectionClosure) }, 1 do
      patch cerrar_lapso_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)
    end
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

  # Deja el lapso LISTO PARA CERRAR: todas las notas y todos los informes.
  #
  # ⚠️ Los dos, desde el 19 de septiembre: *«el informe debe ser obligatorio
  # para cerrar»*. Con las notas solas el botón ya no aparece.
  def calificar_todo! = con_el_colegio(@esc.colegio) { calificar!(solo: @esc.inscripciones) }

  def calificar!(solo:)
    examen = actividad(@esc, lapso: @esc.lapso(1), peso: 100, descripcion: "Examen")
    solo.each do |inscripcion|
      nota(examen, inscripcion.student, 16)
      Informe.create!(enrollment: inscripcion, evaluation_moment: @esc.lapso(1),
                      cuerpo: "Avanzó bien en el lapso.", escrito_por: @director)
    end
  end

  # Solo las notas: el estado anterior al informe, que es donde el botón
  # todavía no está.
  def solo_las_notas!
    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @esc.lapso(1), peso: 100, descripcion: "Examen")
      @esc.inscripciones.each { |i| nota(examen, i.student, 16) }
    end
  end
end
