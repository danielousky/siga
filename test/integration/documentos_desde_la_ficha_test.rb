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
end
