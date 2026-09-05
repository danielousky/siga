require "test_helper"

# El menú del profesor: sus secciones, agrupadas por nivel.
#
# QA de Daniel: *«lo mismo con ese chorrero de secciones, hay que dividirlas por
# Nivel»*. Un profesor de Matemática con diecinueve secciones tenía diecinueve
# renglones seguidos, primaria y bachillerato mezclados.
class MenuDelProfesorTest < ActionDispatch::IntegrationTest
  setup do
    # PRIMARIA: es quien evalúa por competencias.
    @a, = dos_colegios_completos(nivel: :primaria)
  end

  # ⚠️ Con un solo nivel NO aparece encabezado: sería un rótulo que no separa
  # nada. El agrupamiento es para quien tiene algo que separar.
  test "un profesor de un solo nivel ve sus secciones sin encabezado de nivel" do
    sign_in @a.profesor
    get dashboards_profesor_path

    assert_select ".sidebar-section-title", text: "Mis secciones"
    assert_select ".sidebar-section-title", text: "Primaria", count: 0
    assert_select ".sidebar-section-title", text: "Bachillerato", count: 0
  end

  test "un profesor de dos niveles las ve separadas y en orden pedagógico" do
    con_el_colegio(@a.colegio) do
      otro_nivel = Grade.create!(name: "1er Año", school: @a.colegio)
      seccion = Section.create!(grade: otro_nivel, academic_period: @a.escenario.periodo,
                                name: "A", capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: seccion,
                             subject: @a.escenario.materia)
    end

    sign_in @a.profesor
    get dashboards_profesor_path

    titulos = css_select(".sidebar-section-title").map { |n| n.text.strip }
    assert_includes titulos, GradoOficial.etiqueta(:primaria, corto: true)
    assert_includes titulos, GradoOficial.etiqueta(:secundaria, corto: true)
    assert_not_includes titulos, "Mis secciones",
                        "con dos niveles el encabezado genérico sobra: cada grupo dice cuál es"
    assert titulos.index(GradoOficial.etiqueta(:primaria, corto: true)) <
           titulos.index(GradoOficial.etiqueta(:secundaria, corto: true)),
           "el orden es el pedagógico, no el de cuántas secciones tenga cada nivel"
  end

  # ⚠️ «Competencias e indicadores» solo a quien dicta PRIMARIA.
  #
  # QA de Daniel: *«si el profesor no tiene secciones de primaria, para qué
  # mostrarle esa vista, sobra»*. Y el nombre importa igual: un plan de
  # evaluación de bachillerato existe —las evaluaciones y su ponderación— y
  # vive en «Mis evaluaciones».
  test "un profesor de bachillerato no ve la entrada de competencias" do
    media, = dos_colegios_completos(nivel: :secundaria)
    sign_in media.profesor
    get dashboards_profesor_path

    enlaces = css_select(".sidebar-nav-link span").map { |n| n.text.strip }
    assert_not_includes enlaces, "Competencias e indicadores"
    assert_includes enlaces, "Mis evaluaciones"
  end

  test "un profesor de primaria sí la ve" do
    sign_in @a.profesor
    get dashboards_profesor_path

    assert_select ".sidebar-nav-link span", text: "Competencias e indicadores"
  end

  # ⚠️ El 6to Año de la Media Técnica va en BACHILLERATO, no en un grupo suyo.
  #
  # Es la trampa que ya está anotada en el modelo: `media_tecnica` es un valor
  # distinto del enum, así que agrupar por `grade.level` a secas le abre al
  # sexto año un encabezado propio con una sola sección adentro. Lo que decide
  # el grupo es `se_elige_como`, que es la misma pregunta que hace la barra.
  test "el 6to Año de Media Técnica cae bajo Bachillerato" do
    con_el_colegio(@a.colegio) do
      sexto = Grade.create!(name: "6to Año", school: @a.colegio)
      assert_equal "media_tecnica", sexto.level, "el nivel se deduce del nombre"

      s = Section.create!(grade: sexto, academic_period: @a.escenario.periodo, name: "U", capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: s, subject: @a.escenario.materia)
    end

    sign_in @a.profesor
    get dashboards_profesor_path

    titulos = css_select(".sidebar-section-title").map { |n| n.text.strip }
    assert_not_includes titulos, GradoOficial.etiqueta(:media_tecnica, corto: true),
                        "la Media Técnica no es un grupo aparte: su 6to Año es bachillerato"
    assert_select ".sidebar-nav-link span", text: /6to Año/
  end
end
