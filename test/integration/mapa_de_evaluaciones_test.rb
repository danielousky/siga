require "test_helper"

# «Evaluaciones» de la dirección: el mapa de los planes en un lapso.
#
# Daniel, el 13 de octubre de 2026, mirando 588 barras en la muestra: *«debe
# haber una mejor manera de mostrarlo»*. Eligió el mapa entre tres dibujos: una
# fila por sección, una casilla por área, y cada casilla abre ese plan.
#
#     ✓   cerró en 100 %      70   lleva 70 %      ·   sin evaluaciones
#     en blanco: el área no se dicta en esa sección
class MapaDeEvaluacionesTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos
    # El escenario trae Matemática en 1er Año A con un examen de 100 % en el
    # lapso 1. Se le suman dos áreas: una a medias y otra sin nada.
    @fisica, @quimica = con_el_colegio(@a.colegio) do
      %w[FIS QUI].zip(%w[Física Química]).map do |codigo, nombre|
        Subject.create!(department: @a.departamento, code: codigo, name: nombre).tap do |area|
          GradeSubject.create!(grade: @a.grado, subject: area)
          TeacherSection.create!(teacher: @a.registro_de_profesor, section: @a.seccion, subject: area)
        end
      end
    end
    con_el_colegio(@a.colegio) do
      EvaluationActivity.create!(section: @a.seccion, subject: @fisica, evaluation_moment: @a.lapso(1),
                                 description: "Taller", weight_percentage: 70, date_scheduled: Date.new(2025, 10, 1))
    end
    sign_in @a.director
  end

  test "una fila por sección y una casilla por área, con su estado" do
    get evaluation_activities_path

    assert_response :success
    assert_select ".mapa-de-evaluaciones tbody tr", 1
    assert_select ".mapa-de-evaluaciones thead th", text: "FIS"
    assert_select "a.mapa-marca--completa", text: "✓", count: 1
    assert_select "a.mapa-marca--a-medias", text: "70", count: 1
    assert_select "a.mapa-marca--vacia", count: 1
  end

  # Es ahí donde están las evaluaciones: el mapa no las repite.
  test "cada casilla abre el plan de esa sección, esa área y ese lapso" do
    get evaluation_activities_path

    assert_select "a.mapa-marca--a-medias[href='#{planificar_section_path(@a.seccion, area: @fisica.id, lapso: @a.lapso(1).id)}']"
    assert_select "a.mapa-marca--vacia[data-tooltip*='sin evaluaciones'][data-tooltip*='Química']"
  end

  # ⚠️ El blanco NO es «sin evaluaciones»: es que el área no se dicta ahí. Con
  # un punto en cada casilla vacía, la sección B parecería atrasada en Física.
  test "donde el área no se dicta, la casilla queda en blanco" do
    con_el_colegio(@a.colegio) do
      otra = Section.create!(grade: @a.grado, academic_period: @a.periodo, name: "B")
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: otra, subject: @a.materia)
    end

    get evaluation_activities_path

    assert_select ".mapa-de-evaluaciones tbody tr", 2
    fila_b = css_select(".mapa-de-evaluaciones tbody tr").find { |fila| fila.text.include?("#{@a.grado.name} B") }
    assert_equal 1, fila_b.css("a.mapa-marca").size, "B solo dicta Matemática: Física y Química, en blanco"
  end

  # Mostraba las de TODOS los años: 588 barras en la muestra.
  test "solo las secciones del año escolar de la sesión" do
    ano_escolar_viejo(@a.escenario, nombre: "2023-2024", seccion: "Z")

    get evaluation_activities_path

    assert_select ".mapa-seccion", text: /#{@a.grado.name} A/
    assert_select ".mapa-seccion", text: /#{@a.grado.name} Z/, count: 0
  end

  test "se elige el lapso, y abre en el último que tiene evaluaciones" do
    get evaluation_activities_path
    assert_select ".pastilla.activa", text: @a.lapso(1).name

    get evaluation_activities_path(lapso: @a.lapso(2).id)

    assert_select ".pastilla.activa", text: @a.lapso(2).name
    assert_select "a.mapa-marca--vacia", count: 3, text: "·"
  end

  # Educación Inicial no planifica: su calificación es un texto.
  test "Educación Inicial no aparece" do
    con_el_colegio(@a.colegio) do
      grupo = Grade.create!(school: @a.colegio, level: :preescolar, name: "1er Nivel")
      seccion = Section.create!(grade: grupo, academic_period: @a.periodo, name: "U")
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: seccion, subject: @a.materia)
    end

    get evaluation_activities_path

    assert_select ".mapa-seccion", text: /1er Nivel/, count: 0
  end

  # El profesor sigue yendo a calificar su primera sección (etapa ③).
  test "al profesor lo sigue llevando a calificar" do
    sign_in @a.profesor

    get evaluation_activities_path

    assert_redirected_to %r{/secciones/#{@a.seccion.id}\?area=}
  end

  test "el lapso que abre: el de hoy si hay fechas, si no el último con evaluaciones" do
    lapsos = con_el_colegio(@a.colegio) { EvaluationMoment.where(academic_period: @a.periodo).order(:id).to_a }

    assert_equal lapsos.first, con_el_colegio(@a.colegio) { MapaDeEvaluaciones.lapso_por_defecto(lapsos) },
                 "sin fechas, el último con evaluaciones: el escenario solo tiene en el primero"

    # Con fechas cargadas manda el calendario, aunque el lapso no tenga nada.
    travel_to Date.new(2026, 5, 4) do
      con_el_colegio(@a.colegio) { lapsos.last.update!(starts_on: Date.new(2026, 4, 6), ends_on: Date.new(2026, 7, 15)) }

      assert_equal lapsos.last, con_el_colegio(@a.colegio) { MapaDeEvaluaciones.lapso_por_defecto(lapsos) }
    end
  end
end
