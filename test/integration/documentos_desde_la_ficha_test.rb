require "test_helper"

# Los documentos oficiales, pedidos desde la ficha del alumno y PASANDO POR EL
# CONTROLADOR.
#
# ## Por qué existe este archivo
#
# Los armadores tenían sus tests (`test/services/documentos_*_test.rb`) y el
# controlador no tenía ninguno. Ese hueco dejó vivir un error en producción
# desde el 11 de septiembre de 2026: emitir el documento de Educación Inicial
# desde la ficha levantaba un `NoMethodError` en cualquier colegio que tuviera
# director cargado — o sea, en todos los de verdad.
#
#     el controlador   →  le pasa al armador el REGISTRO del director (`Admin`)
#     el armador       →  le pedía `nombre_completo` a lo que recibiera
#     su único test    →  lo llamaba sin director, y pasaba
#
# Las tres piezas estaban bien por separado. Lo que estaba roto era la costura,
# y una costura solo se prueba cosiendo: con una petición de verdad.
#
# ⚠️ Por eso acá hay SIEMPRE un director. Es el caso normal —quien registra el
# colegio es su director— y es justamente el que ningún test ejercitaba.
class DocumentosDesdeLaFichaTest < ActionDispatch::IntegrationTest
  test "la 31059 sale en PDF y en Excel" do
    liceo = colegio_completo("Liceo", nivel: :secundaria)
    sign_in liceo.director

    get certificacion_de_calificaciones_path(student_id: liceo.alumno, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")

    get certificacion_de_calificaciones_path(student_id: liceo.alumno, format: :xlsx)

    assert_response :success
  end

  test "el documento de primaria sale, firmado por el director" do
    escuela = colegio_completo("Escuela", nivel: :primaria)
    sign_in escuela.director

    get documento_de_primaria_path(enrollment_id: escuela.inscripcion)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
  end

  # ⚠️ El que estaba roto. Sin director pasaba; con director —el caso de todo
  # colegio real— era un 500.
  test "el documento de Educación Inicial sale, también con director cargado" do
    jardin = escenario_academico(nombre: "Jardín", nivel: :preescolar)
    directora = con_el_colegio(jardin.colegio) do
      usuario("dir", jardin.colegio.id).tap { |u| Admin.create!(user: u, school: jardin.colegio, role: :director) }
    end
    sign_in directora

    get documento_de_inicial_path(enrollment_id: jardin.inscripcion)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
  end

  test "un profesor no los emite" do
    liceo = colegio_completo("Liceo", nivel: :secundaria)
    sign_in liceo.profesor

    get certificacion_de_calificaciones_path(student_id: liceo.alumno, format: :pdf)

    assert_redirected_to dashboards_profesor_path
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La constancia y el boletín, a un clic (13 de octubre de 2026)
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Daniel, en la muestra: el botón «Constancia» llevaba a «Documentos» con la
  # SECCIÓN puesta —había que volver a buscar al alumno entre treinta— y la
  # tarjeta de documentos no tenía ni la constancia ni el boletín.
  #
  # ⚠️ Se prueba COSIENDO, como el resto de este archivo: se lee el formulario
  # que dibuja la ficha y se envía tal cual. Probar la acción por su lado
  # pasaría aunque el botón mandara otro alumno, u otro lapso.

  test "«Constancia» emite la de ESTE alumno en el mismo clic" do
    escuela = colegio_completo("Escuela", nivel: :primaria)
    sign_in escuela.director

    get student_path(escuela.alumno)
    constancias = formularios_que_emiten(constancias_path)

    assert_equal [ "Constancia", "Emitir" ], constancias.map { |f| f[:texto] },
                 "la de la cabecera y la de la tarjeta"
    constancias.each do |f|
      assert_equal escuela.inscripcion.id.to_s, f[:campos]["enrollment_id"]
      assert_equal "false", f[:turbo], "con Turbo, el PDF se queda en memoria y no baja"
      assert_equal "_blank", f[:target], "el papel se abre en otra pestaña, y la ficha queda donde estaba"
    end

    post constancias_path, params: constancias.first[:campos]
    follow_redirect!

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/constancia-prueba-alumno1\.pdf/, response.headers["Content-Disposition"])
  end

  test "el boletín: un botón por lapso y el anual, todos de este alumno" do
    escuela = colegio_completo("Escuela", nivel: :primaria)
    sign_in escuela.director

    # El SEGUNDO alumno: con el primero no se vería un botón que manda siempre
    # la primera inscripción de la sección.
    get student_path(escuela.escenario.alumno(2))
    boletines = formularios_que_emiten(report_cards_path)

    assert_equal [ "Lapso 1", "Lapso 2", "Lapso 3", "Anual" ], boletines.map { |f| f[:texto] }
    assert_equal [ escuela.escenario.inscripcion(2).id.to_s ], boletines.map { |f| f[:campos]["enrollment_id"] }.uniq
    assert_equal [ *escuela.escenario.lapsos.map { |l| l.id.to_s }, "anual" ],
                 boletines.map { |f| f[:campos]["evaluation_moment_id"] }

    post report_cards_path, params: boletines.first[:campos]
    follow_redirect!

    assert_response :success
    assert_equal "application/pdf", response.media_type
    # El apellido en el nombre del archivo es la señal de UN boletín: el de la
    # sección entera se llama solo por el grado y el lapso.
    assert_match(/boletines-6to-grado-a-lapso-1-prueba\.pdf/, response.headers["Content-Disposition"])
  end

  private

  # Los formularios de la ficha que emiten un papel: el texto del botón, si
  # Turbo los deja en paz, y los campos que mandan.
  def formularios_que_emiten(accion)
    css_select("form[action='#{accion}']").map do |form|
      { texto: form.css("button").text.squish, turbo: form["data-turbo"], target: form["target"],
        campos: form.css("input[type=hidden]").to_h { |campo| [ campo["name"], campo["value"] ] }
                    .except("authenticity_token") }
    end
  end
end
