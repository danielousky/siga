require "test_helper"

# Subir las materias y los profesores del colegio (MOR-126, tanda 2).
#
# Es lo que habilita el módulo de evaluación, que ya existe y no tiene con qué
# arrancar: sin materias asignadas a secciones, un profesor entra y no ve nada
# que calificar.
#
# El recorrido es el mismo de la matrícula —subir, mapear, previsualizar,
# confirmar— y eso es lo que más importa probar: que compartir el recorrido no
# haya hecho que una planilla se lea con las columnas de la otra.
class ImportarPensumTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos
    sign_in @a.director
  end

  def subir(nombre = "pensum_de_colegio.csv")
    post importaciones_path,
         params: { importacion: { archivo: fixture_file_upload(nombre, "text/csv"), tipo: "pensum" } }
  end

  def ultima = con_el_colegio(@a.colegio) { Importacion.order(:id).last }

  # ── la plantilla ──────────────────────────────────────────────────────────

  test "el colegio descarga la plantilla de materias, distinta de la de matrícula" do
    get plantilla_importaciones_path(tipo: :pensum)

    assert_response :success
    assert_match(/pensum-/, response.headers["Content-Disposition"])
  end

  test "sin decir el tipo, la plantilla es la de matrícula" do
    get plantilla_importaciones_path

    assert_match(/matricula-/, response.headers["Content-Disposition"])
  end

  # ── subir y mapear ────────────────────────────────────────────────────────

  test "la importación recuerda que trae materias, no alumnos" do
    subir

    assert ultima.pensum?
    assert_equal 5, ultima.filas_leidas, "el subtotal del medio no es una fila"
  end

  # ⚠️ Lo que de verdad se prueba acá: que la planilla de pensum NO se lea con
  # las columnas de la matrícula. «PROFESOR» y «REPRESENTANTE» ocupan el mismo
  # lugar en la planilla, y confundirlos cargaría profesores como madres.
  test "propone el mapeo con las columnas de pensum" do
    subir
    get importacion_path(ultima)

    assert_response :success
    assert_equal({
                   "AÑO/SECC" => "seccion", "ASIGNATURA" => "materia", "CÓDIGO" => "codigo",
                   "DEPARTAMENTO" => "departamento", "PROFESOR" => "profesor",
                   "CEDULA PROFESOR" => "cedula_del_profesor",
                   "CORREO PROFESOR" => "correo_del_profesor"
                 }, ultima.mapeo_sugerido)
  end

  test "las columnas que ofrece son las de pensum" do
    subir
    get importacion_path(ultima)

    assert_select "select option", text: "CÓDIGO DE LA MATERIA"
    assert_select "select option", text: "CÉDULA DEL PROFESOR"
    assert_select "select option", text: "CÉDULA DEL REPRESENTANTE", count: 0
  end

  # ── previsualizar ─────────────────────────────────────────────────────────

  test "muestra materias y profesores distintos, no filas" do
    subir
    patch importacion_path(ultima), params: { mapeo: ultima.mapeo_sugerido }
    follow_redirect!

    assert_response :success
    # 4 cargables de 5: «1er Año C» no existe y Física viene sin correo.
    assert_select ".cifra-numero", text: "3"
    assert_select "body", text: /materias distintas/
    assert_select "body", text: /profesores distintos/
  end

  # El código es lo que identifica a la materia dentro del colegio y aparece en
  # boletines: un código inventado tiene que verse antes de confirmar.
  test "avisa cuáles códigos se inventó" do
    subir
    patch importacion_path(ultima), params: { mapeo: ultima.mapeo_sugerido }
    follow_redirect!

    assert_select "body", text: /Códigos que SIGA le puso/
    assert_select "code", text: "BIO"
    assert_select "code", text: "CASL"
  end

  test "ofrece crear la sección que la planilla nombra y el colegio no tiene" do
    subir
    patch importacion_path(ultima), params: { mapeo: ultima.mapeo_sugerido }
    follow_redirect!

    assert_select "body", text: /1er Año C/
    assert_select "form[action=?]", crear_seccion_importacion_path(ultima)
  end

  # ⚠️ CON EL NÚMERO. El conteo es lo único que separa una sección de verdad de
  # un dedazo —«1er Año C · 18» contra «1er Año K · 1»— y sin él la columna no
  # dice nada. `pluralizar` devuelve solo la palabra; el número lo pone `contar`.
  test "el conteo de la sección que falta sale con su número" do
    subir
    patch importacion_path(ultima), params: { mapeo: ultima.mapeo_sugerido }
    follow_redirect!

    assert_select "td", text: "1 materia"
  end

  # ⚠️ La diferencia con la matrícula, y es del modelo: `EntraAlSistema` exige el
  # correo del profesor. Un representante sin correo se carga igual.
  test "el profesor sin correo se rechaza, y se dice por qué" do
    subir
    patch importacion_path(ultima), params: { mapeo: ultima.mapeo_sugerido }
    follow_redirect!

    assert_select "body", text: /no puede entrar a cargar notas/
  end

  # ── confirmar ─────────────────────────────────────────────────────────────

  test "carga las materias, el pensum, los profesores y sus asignaciones" do
    subir
    patch importacion_path(ultima), params: { mapeo: ultima.mapeo_sugerido }

    # «1er Año C» no existe: hasta que se cree, no se carga nada.
    patch importacion_path(ultima), params: { confirmar: "1" }
    assert_redirected_to previsualizar_importacion_path(ultima)

    grado = con_el_colegio(@a.colegio) { Grade.first }
    post crear_seccion_importacion_path(ultima),
         params: { grade_id: grado.id, nombre: "C", cuantas: 1 }

    assert_difference -> { con_el_colegio(@a.colegio) { Subject.count } }, 2 do
      patch importacion_path(ultima), params: { confirmar: "1" }
    end

    assert_redirected_to resultado_importacion_path(ultima)

    con_el_colegio(@a.colegio) do
      assert ultima.confirmada?
      assert_equal 2, ultima.resultado["materias_creadas"]
      assert_equal 1, ultima.resultado["materias_reutilizadas"], "MAT ya existía"
      assert_equal 2, ultima.resultado["profesores_creados"]

      carlos = User.find_by(document: "31444555")
      assert_equal "carlos.garcia@sanjose.edu", carlos.email
      assert_equal 2, TeacherSection.where(teacher: Teacher.find_by(user: carlos)).count
    end
  end

  # ⚠️ El colegio ya tenía «1er Año A · Matemática» con otro profesor, y una
  # sección tiene UN profesor por materia.
  #
  # No es un caso rebuscado: es lo que pasa cuando el colegio cargó algo a mano
  # antes de importar, o cuando cambió de profesor a mitad de año y la planilla
  # trae al viejo. La fila no se guarda, las otras sí, y el reporte dice a quién
  # está asignada — que es lo único con lo que alguien puede decidir.
  test "una materia ya asignada a otro profesor se reporta sin romper el resto" do
    importar_todo

    con_el_colegio(@a.colegio) do
      assert_equal 3, ultima.resultado["asignaciones"]
      assert_equal 1, ultima.resultado["fallidas"].size

      fallida = ultima.resultado["fallidas"].first
      assert_equal "Matemática", fallida["materia"]
      assert_match(/ya está asignada a Prof/, fallida["motivo"])
    end
  end

  test "el reporte cuenta materias y profesores, no alumnos" do
    importar_todo
    get resultado_importacion_path(ultima)

    assert_response :success
    assert_select "h1", text: "Materias y profesores importados"
    assert_select "body", text: /materias nuevas/
    assert_select "body", text: /profesores nuevos/
    assert_select "body", text: /alumnos nuevos/, count: 0
  end

  # Reimportar es el caso NORMAL: el colegio corrige cuatro filas y vuelve a
  # mandar la planilla entera.
  test "volver a subir la misma planilla no duplica nada" do
    importar_todo

    assert_no_difference [ -> { con_el_colegio(@a.colegio) { Subject.count } },
                           -> { con_el_colegio(@a.colegio) { TeacherSection.count } } ] do
      importar_todo
    end
  end

  # ── el aislamiento ────────────────────────────────────────────────────────

  test "las materias del otro colegio no se tocan" do
    antes = con_el_colegio(@b.colegio) { Subject.pluck(:id) }
    importar_todo

    assert_equal antes, con_el_colegio(@b.colegio) { Subject.pluck(:id) }
  end

  private

  def importar_todo
    subir
    patch importacion_path(ultima), params: { mapeo: ultima.mapeo_sugerido }

    grado = con_el_colegio(@a.colegio) { Grade.first }
    post crear_seccion_importacion_path(ultima),
         params: { grade_id: grado.id, nombre: "C", cuantas: 1 }

    patch importacion_path(ultima), params: { confirmar: "1" }
  end
end
