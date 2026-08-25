require "test_helper"

# Subir las notas de años anteriores (MOR-126, tanda 3).
#
# Es lo último que trae un colegio y lo más difícil: hay que materializar el año
# viejo entero —período, lapsos, sección, inscripción— antes de poder colgarle
# una nota. Por eso la carga rápida importa más acá que en las otras dos.
class ImportarHistorialTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos
    sign_in @a.director
  end

  def subir(nombre = "historial_de_colegio.csv")
    post importaciones_path,
         params: { importacion: { archivo: fixture_file_upload(nombre, "text/csv"), tipo: "historial" } }
  end

  def ultima = con_el_colegio(@a.colegio) { Importacion.order(:id).last }

  def mapear = patch importacion_path(ultima), params: { mapeo: ultima.mapeo_sugerido }

  # ── el mapeo ──────────────────────────────────────────────────────────────

  test "la plantilla de historial es distinta de las otras dos" do
    get plantilla_importaciones_path(tipo: :historial)

    assert_response :success
    assert_match(/historial-/, response.headers["Content-Disposition"])
  end

  # ⚠️ La trampa de esta planilla: cuatro columnas de lapso que se parecen.
  test "cada lapso cae en su propio casillero" do
    subir

    assert_equal({ "APELLIDOS Y NOMBRES" => "nombre_completo", "CEDULA ESCOLAR" => "cedula_escolar",
                   "AÑO ESCOLAR" => "ano_escolar", "AÑO/SECC" => "seccion", "ASIGNATURA" => "materia",
                   "LAPSO 1" => "lapso_1", "LAPSO 2" => "lapso_2", "LAPSO 3" => "lapso_3",
                   "DEFINITIVA" => "definitiva", "REPARACIÓN" => "reparacion" },
                 ultima.mapeo_sugerido)
  end

  # ── el año escolar que falta ──────────────────────────────────────────────

  # ⚠️ Una nota de 2023 no tiene dónde colgarse sin el año Y sus lapsos: un
  # `MomentGrade` pertenece a un lapso, y el lapso al período.
  test "ofrece crear los años escolares que la planilla nombra y el colegio no tiene" do
    ano_escolar_viejo(@a.escenario, nombre: "2023-2024")
    subir
    mapear
    follow_redirect!

    assert_select "h2", text: /años escolares todavía no existen/i
    assert_select "form[action=?]", crear_ano_escolar_importacion_path(ultima)
    assert_select "button", text: /Crear 2019-2020 con 3 lapsos/
  end

  # Cuántos lapsos NO se pregunta: se cuentan las columnas de la planilla.
  test "crear el año escolar lo crea con sus lapsos" do
    subir
    mapear

    assert_difference -> { con_el_colegio(@a.colegio) { AcademicPeriod.count } }, 1 do
      post crear_ano_escolar_importacion_path(ultima), params: { nombre: "2023-2024", lapsos: 3 }
    end

    con_el_colegio(@a.colegio) do
      periodo = AcademicPeriod.find_by(name: "2023-2024")
      assert_equal Date.new(2023, 9, 15), periodo.start_date
      assert_equal Date.new(2024, 7, 31), periodo.end_date
      assert_equal 3, EvaluationMoment.where(academic_period: periodo).count
      assert_equal 100, EvaluationMoment.where(academic_period: periodo).sum(:weight)
    end
  end

  test "un año escolar mal escrito se rechaza con una frase que dice qué hacer" do
    subir
    mapear

    assert_no_difference -> { con_el_colegio(@a.colegio) { AcademicPeriod.count } } do
      post crear_ano_escolar_importacion_path(ultima), params: { nombre: "el año pasado", lapsos: 3 }
    end

    assert_match(/use la forma 2023-2024/, flash[:alert].to_s)
  end

  # ── previsualizar ─────────────────────────────────────────────────────────

  test "no deja confirmar mientras falte un año escolar" do
    subir
    mapear

    patch importacion_path(ultima), params: { confirmar: "1" }

    assert_redirected_to previsualizar_importacion_path(ultima)
    assert_not ultima.confirmada?
  end

  # ⚠️ El literal pierde el número exacto y el colegio tiene que enterarse ANTES.
  test "avisa cuáles notas vinieron en letra" do
    preparar_los_anos

    assert_select "h2", text: /Notas en letra/i
    assert_select "body", text: /se pierde/
  end

  test "no lleva selector de año escolar" do
    preparar_los_anos

    # Cada fila trae el suyo: un selector sugeriría que hay uno solo.
    assert_select "select[name=periodo_id]", count: 0
  end

  # ── confirmar ─────────────────────────────────────────────────────────────

  test "carga las notas, marcadas como importadas, y sobreviven al recálculo" do
    preparar_los_anos

    patch importacion_path(ultima), params: { confirmar: "1" }
    assert_redirected_to resultado_importacion_path(ultima)

    con_el_colegio(@a.colegio) do
      assert ultima.confirmada?
      assert MomentGrade.where(origen: :importada).any?
      assert FinalGradeBook.where(origen: :importada).any?

      viejo = AcademicPeriod.find_by(name: "2023-2024")
      inscripciones = Enrollment.joins(:section).where(sections: { academic_period_id: viejo.id })
      antes = MomentGrade.where(enrollment: inscripciones).count

      inscripciones.each { |i| GradeCalculator.calculate_all_for_enrollment(i) }

      assert_equal antes, MomentGrade.where(enrollment: inscripciones).count, "el recálculo las borró"
    end
  end

  test "la fila sin identificador queda fuera, con su motivo" do
    preparar_los_anos

    assert_select "body", text: /no se sabe de quién es esta nota/
  end

  test "el reporte cuenta calificaciones, no alumnos" do
    preparar_los_anos
    patch importacion_path(ultima), params: { confirmar: "1" }
    get resultado_importacion_path(ultima)

    assert_response :success
    assert_select "h1", text: /Notas de años anteriores/i
    assert_select "body", text: /notas de lapso/
    assert_select "body", text: /nadie las va a recalcular/
  end

  test "reimportar no duplica nada" do
    preparar_los_anos
    patch importacion_path(ultima), params: { confirmar: "1" }

    assert_no_difference [ -> { con_el_colegio(@a.colegio) { MomentGrade.count } },
                           -> { con_el_colegio(@a.colegio) { Enrollment.count } } ] do
      preparar_los_anos
      patch importacion_path(ultima), params: { confirmar: "1" }
    end
  end

  # ── el aislamiento ────────────────────────────────────────────────────────

  test "las notas del otro colegio no se tocan" do
    antes = con_el_colegio(@b.colegio) { MomentGrade.pluck(:id) }
    preparar_los_anos
    patch importacion_path(ultima), params: { confirmar: "1" }

    assert_equal antes, con_el_colegio(@b.colegio) { MomentGrade.pluck(:id) }
  end

  private

  # Sube la planilla y crea los dos años que nombra, con la carga rápida. Deja
  # todo listo para confirmar.
  def preparar_los_anos
    subir
    mapear
    post crear_ano_escolar_importacion_path(ultima), params: { nombre: "2023-2024", lapsos: 3 }
    post crear_ano_escolar_importacion_path(ultima), params: { nombre: "2019-2020", lapsos: 3 }

    # `find_or_create_by` y no `create!`: el helper se llama dos veces en el test
    # de reimportación, que es justamente el caso que hay que poder repetir.
    con_el_colegio(@a.colegio) do
      grado = Grade.first
      [ "2023-2024", "2019-2020" ].each do |nombre|
        Section.find_or_create_by!(grade: grado, academic_period: AcademicPeriod.find_by(name: nombre),
                                   name: "A") { |s| s.capacity = 30 }
      end
    end

    get previsualizar_importacion_path(ultima)
  end
end
