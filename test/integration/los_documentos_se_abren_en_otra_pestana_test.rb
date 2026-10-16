require "test_helper"

# Todo documento se abre en el visor del navegador, en OTRA pestaña, y el Excel
# se baja (`EntregaDocumentos`). Daniel, 16 de octubre de 2026: *«todos los
# documentos deberían tener una misma forma de salida»*.
#
# ⚠️ Se prueba en las TRES capas, porque cada una puede fallar sola y las otras
# dos no se enteran:
#
#     el servidor   ¿lo manda para abrirse (inline) o para bajarse?
#     la pantalla   ¿el botón abre otra pestaña, o reemplaza a SIGA?
#     la emisión    ¿recargar la pestaña emite otro papel? ¿una precarga audita?
class LosDocumentosSeAbrenEnOtraPestanaTest < ActionDispatch::IntegrationTest
  # ══════════════════════════════════════════════════════════════════════════
  # El servidor
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ Un controlador nuevo que arme su propio `send_data` de un PDF vuelve a
  # escribir la regla a su manera — que es exactamente como se llegó a cinco
  # formas de salir.
  #
  # El manual queda fuera: es un archivo PUBLICADO, no un papel del colegio, y
  # ya se abre en el visor (lo cuida `manual_test`).
  test "ningún controlador manda un PDF por su cuenta, ni para bajarse" do
    propios = %w[concerns/entrega_documentos.rb manual_controller.rb]
    culpables = Dir[Rails.root.join("app/controllers/**/*.rb")].flat_map do |archivo|
      next [] if propios.any? { |p| archivo.end_with?(p) }

      texto = File.read(archivo)
      ruta = archivo.delete_prefix("#{Rails.root}/")
      [ ("#{ruta}: para bajarse" if texto.include?('disposition: "attachment"')),
        ("#{ruta}: un PDF fuera de `entregar_pdf`" if texto.include?("application/pdf")) ].compact
    end

    assert_empty culpables, "Los PDF salen por `EntregaDocumentos#entregar_pdf`:\n  " + culpables.join("\n  ")
  end

  test "los papeles de la ficha se mandan para ABRIRSE" do
    liceo = colegio_completo("Liceo", nivel: :secundaria)
    sign_in liceo.director

    get certificacion_de_calificaciones_path(student_id: liceo.alumno, format: :pdf)

    assert_response :success
    assert_match(/\Ainline; filename="certificacion-31059-/, response.headers["Content-Disposition"])
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La emisión: POST ──303──► la dirección firmada
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ Recargar la pestaña es pedir otra vez la DIRECCIÓN, no repetir el POST:
  # con el PDF como respuesta del POST, cada recarga emitía un boletín nuevo,
  # con otro código, y otra línea en la auditoría.
  test "emitir un boletín abre su dirección, y recargarla no emite otro" do
    escuela = colegio_completo("Escuela", nivel: :primaria)
    sign_in escuela.director

    post report_cards_path, params: { section_id: escuela.seccion.id, enrollment_id: escuela.inscripcion.id,
                                      evaluation_moment_id: escuela.lapso(1).id }

    assert_response :see_other
    assert_match %r{/boletines/impresion\.pdf\?firma=}, response.location

    sin_emitir_otro(escuela, ReportCard) { recargar_dos_veces(response.location, /boletines-6to-grado-a-lapso-1-/) }
  end

  test "emitir una constancia abre su dirección, y recargarla no emite otra" do
    escuela = colegio_completo("Escuela", nivel: :primaria)
    sign_in escuela.director

    post constancias_path, params: { section_id: escuela.seccion.id, enrollment_id: escuela.inscripcion.id }

    assert_response :see_other
    sin_emitir_otro(escuela, Constancia) { recargar_dos_veces(response.location, /constancia-/) }
  end

  test "emitir un certificado abre su dirección, y recargarla no lo vuelve a auditar" do
    escuela = colegio_completo("Escuela", nivel: :primaria)
    sign_in escuela.director

    post certificados_path, params: { section_id: escuela.seccion.id, enrollment_id: escuela.inscripcion.id }

    assert_response :see_other
    sin_emitir_otro(escuela) { recargar_dos_veces(response.location, /certificado-primaria-/) }
  end

  # ⚠️ La dirección firmada no es una puerta para sacar papeles sin rastro: se
  # consigue SOLO emitiendo, y vence.
  test "una dirección vencida o tocada a mano no entrega nada" do
    escuela = colegio_completo("Escuela", nivel: :primaria)
    sign_in escuela.director
    post constancias_path, params: { section_id: escuela.seccion.id, enrollment_id: escuela.inscripcion.id }
    direccion = response.location

    get direccion.sub("firma=", "firma=x")
    assert_redirected_to constancias_path
    assert_match(/ya no sirve/, flash[:alert])

    travel EntregaDocumentos::VIGENCIA_DE_LA_IMPRESION + 1.minute do
      get direccion
    end
    assert_redirected_to constancias_path
  end

  # ⚠️ La pared reconoce un archivo por su FORMATO: sin `.pdf`, esta dirección
  # pasaría en gratis como una pantalla más (`RespetaLaSuscripcion`).
  test "en gratis, la dirección del PDF también choca con la pared" do
    gratis = colegio_completo("Gratis", nivel: :primaria, suscripcion: :gratis)
    sign_in gratis.director
    constancia = con_el_colegio(gratis.colegio) { Constancia.emitir!(gratis.inscripcion, por: gratis.director) }
    firma = Rails.application.message_verifier("impresiones")
                 .generate({ "ids" => [ constancia.id ], "nombre" => "x.pdf" }, expires_in: 1.hour, purpose: :impresion)

    get impresion_de_constancias_path(firma: firma, format: :pdf)

    assert_response :payment_required
  end

  # ⚠️ Turbo 8 pide un enlace con solo pasar el mouse por encima, y estos
  # papeles se auditan al dibujarse. El 16 de octubre, en la muestra, una
  # constancia de prosecución quedó NUEVE veces en la auditoría.
  test "una precarga no dibuja ni audita el papel" do
    escuela = colegio_completo("Escuela", nivel: :primaria)
    sign_in escuela.director

    assert_no_difference -> { con_el_colegio(escuela.colegio) { ActivityLog.count } } do
      get documento_de_primaria_path(enrollment_id: escuela.inscripcion), headers: { "X-Sec-Purpose" => "prefetch" }
    end
    assert_response :no_content

    assert_difference -> { con_el_colegio(escuela.colegio) { ActivityLog.count } }, 1 do
      get documento_de_primaria_path(enrollment_id: escuela.inscripcion)
    end
    assert_equal "application/pdf", response.media_type
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La pantalla: cada botón de un PDF abre otra pestaña
  # ══════════════════════════════════════════════════════════════════════════

  test "la ficha, en los tres niveles" do
    escuela = colegio_completo("Escuela", nivel: :primaria)
    sign_in escuela.director
    get student_path(escuela.alumno)

    assert_select "form[action=?][target=_blank]", constancias_path, 2   # la cabecera y la tarjeta
    assert_select "form[action=?][target=_blank]", report_cards_path, 4  # tres lapsos y el anual
    assert_select "a[href=?][target=_blank]", documento_de_primaria_path(enrollment_id: escuela.inscripcion)
    sin_formularios_que_emitan_en_la_misma_pestana

    liceo = colegio_completo("Liceo", nivel: :secundaria)
    sign_in liceo.director
    get student_path(liceo.alumno)

    assert_select "a[href=?][target=_blank]", certificacion_de_calificaciones_path(student_id: liceo.alumno, format: :pdf)
    # El Excel se BAJA: abrirlo en otra pestaña dejaría una pestaña en blanco.
    assert_select "a[href=?]:not([target])", certificacion_de_calificaciones_path(student_id: liceo.alumno, format: :xlsx)

    jardin = escenario_academico(nombre: "Jardín", nivel: :preescolar)
    directora = con_el_colegio(jardin.colegio) do
      usuario("dir", jardin.colegio.id).tap { |u| Admin.create!(user: u, school: jardin.colegio, role: :director) }
    end
    sign_in directora
    get student_path(jardin.alumno)

    assert_select "a[href=?][target=_blank]", documento_de_inicial_path(enrollment_id: jardin.inscripcion)
  end

  test "las tres pestañas de Documentos" do
    escuela = colegio_completo("Escuela", nivel: :primaria)
    sign_in escuela.director

    { report_cards_path(section_id: escuela.seccion.id) => report_cards_path,
      constancias_path(section_id: escuela.seccion.id) => constancias_path,
      certificados_path(section_id: escuela.seccion.id) => certificados_path }.each do |pantalla, accion|
      get pantalla

      assert_select "form[action=?][method=post][target=_blank]", accion, 1, "#{pantalla} emite en la misma pestaña"
      assert_no_match(/Emitir y descargar/, response.body, "#{pantalla}: ya no se descarga, se abre")
    end
  end

  test "el Resumen Final de una sección de Media" do
    liceo = colegio_completo("Liceo", nivel: :secundaria)
    sign_in liceo.director

    get alumnos_section_path(liceo.seccion)

    assert_select "a[href=?][target=_blank]", resumen_final_path(liceo.seccion, format: :pdf)
  end

  test "la familia abre su boletín en otra pestaña" do
    escuela = colegio_completo("Escuela", nivel: :primaria)
    mama = con_el_colegio(escuela.colegio) do
      persona = usuario("rep", escuela.colegio.id)
      representante = Representative.create!(user: persona, school: escuela.colegio)
      StudentRepresentative.create!(student: escuela.alumno, representative: representante)
      escuela.boletin.liberar!(por: escuela.director)
      persona
    end
    sign_in mama

    get hijo_representante_path(escuela.alumno)

    assert_select "a[href=?][target=_blank]", boletin_path(escuela.boletin), text: /Ver/

    get boletin_path(escuela.boletin)
    assert_match(/\Ainline/, response.headers["Content-Disposition"])
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La 31059 en Excel, también desde Documentos ▸ Certificados
  # ══════════════════════════════════════════════════════════════════════════

  # Daniel, 16 de octubre: *«no veo ningún enlace al Excel, solo el PDF»*.
  # Estaba solo en la ficha.
  test "Certificados ofrece la 31059 en Excel: la sección, un libro con una hoja por alumno" do
    liceo = colegio_completo("Liceo", nivel: :secundaria)
    sign_in liceo.director

    get certificados_path(section_id: liceo.seccion.id)
    # ⚠️ `formtarget="_self"`: el formulario abre OTRA pestaña, y un Excel no
    # tiene visor que la llene.
    assert_select "button[name=formato][value=xlsx][formtarget=_self]", text: /En Excel/

    assert_difference -> { con_el_colegio(liceo.colegio) { ActivityLog.where(action: "certificacion_emitida").count } }, 1 do
      post certificados_path, params: { section_id: liceo.seccion.id, formato: "xlsx" }
    end

    assert_response :success
    assert_equal Mime[:xlsx].to_s, response.media_type
    assert_match(/\Aattachment; filename="certificacion-31059-1er-ano-a\.xlsx"/, response.headers["Content-Disposition"])
    assert_equal 2, hojas_del_libro(response.body), "una hoja por alumno"

    post certificados_path, params: { section_id: liceo.seccion.id, enrollment_id: liceo.inscripcion.id, formato: "xlsx" }

    assert_equal 1, hojas_del_libro(response.body)
  end

  test "fuera de Media no hay Excel: los otros papeles no tienen casillas que completar" do
    escuela = colegio_completo("Escuela", nivel: :primaria)
    sign_in escuela.director

    get certificados_path(section_id: escuela.seccion.id)

    assert_select "button[value=xlsx]", 0
  end

  private

  def recargar_dos_veces(direccion, nombre)
    2.times do
      get direccion

      assert_response :success
      assert_equal "application/pdf", response.media_type
      assert response.body.start_with?("%PDF")
      assert_match(/\Ainline; filename="#{nombre}/, response.headers["Content-Disposition"])
    end
  end

  # Ni un papel nuevo ni otra línea en la auditoría: la emisión fue el POST.
  def sin_emitir_otro(colegio, modelo = nil, &)
    cuentas = [ -> { con_el_colegio(colegio.colegio) { ActivityLog.count } } ]
    cuentas << -> { con_el_colegio(colegio.colegio) { modelo.count } } if modelo

    assert_no_difference cuentas, &
  end

  # Un formulario que emite y NO abre otra pestaña reemplazaría a SIGA por el PDF.
  def sin_formularios_que_emitan_en_la_misma_pestana
    acciones = [ report_cards_path, constancias_path, certificados_path ]
    sueltos = css_select("form[method=post]").select { |f| acciones.include?(f["action"]) && f["target"] != "_blank" }

    assert_empty sueltos.map { |f| f["action"] }, "formularios que emiten en la misma pestaña"
  end

  def hojas_del_libro(xlsx)
    Zip::File.open_buffer(StringIO.new(xlsx)).read("xl/workbook.xml").scan("<sheet ").size
  end
end
