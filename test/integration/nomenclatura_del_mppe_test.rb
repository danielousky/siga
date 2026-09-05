require "test_helper"

# La nomenclatura del MPPE (MOR-212).
#
# Daniel, de la jornada del 3 de septiembre: *«corrección de nomenclatura:
# Preescolar = Educación Inicial; Primaria = Educación Primaria; Bachillerato =
# Educación Media General; Técnico Medio = Educación Técnica Media»*.
#
# No es purismo: un director llena planillas del ministerio con estas palabras,
# y un sistema que le dice «Bachillerato» donde el MPPE dice «Educación Media»
# lo obliga a traducir en cada pantalla.
class NomenclaturaDelMppeTest < ActiveSupport::TestCase
  test "cada nivel se llama como lo llama el MPPE" do
    assert_equal "Educación Inicial", GradoOficial.etiqueta(:preescolar)
    assert_equal "Educación Primaria", GradoOficial.etiqueta(:primaria)
    assert_equal "Educación Media", GradoOficial.etiqueta(:secundaria)
    assert_equal "Educación Técnica Media", GradoOficial.etiqueta(:media_tecnica)
  end

  # ⚠️ La forma corta va donde el nombre largo no cabe: la barra, el menú, los
  # chips. Es una sola palabra y sigue siendo inequívoca.
  test "la forma corta es una palabra y no se confunde con nada" do
    cortas = GradoOficial::ETIQUETAS_CORTAS.values
    assert_equal cortas.uniq, cortas, "dos niveles no pueden abreviarse igual"
    assert_equal %w[Inicial Primaria Media], cortas.first(3)
  end

  # ⚠️ El ENUM no cambia, y esa es la decisión que hace barato el renombre.
  #
  # `grades.level` sigue diciendo `secundaria` y `preescolar`: son enteros
  # escritos en la base de todos los colegios, y renombrarlos sería una
  # migración de datos para arreglar un problema de TEXTO.
  test "el enum de la base sigue igual" do
    assert_includes Grade.levels.keys, "secundaria"
    assert_includes Grade.levels.keys, "preescolar"
  end

  # ⚠️ Nadie escribe «Bachillerato» a mano en una vista: se pide a
  # `GradoOficial.etiqueta`. Con el texto escrito, el día que el MPPE cambie una
  # palabra hay que salir a buscarla por todo el proyecto — que es justamente
  # de donde venimos.
  test "ninguna vista escribe el nombre de un nivel a mano" do
    # ⚠️ Los COMENTARIOS de Haml no cuentan, y hay que saltarlos línea por
    # línea: no se ven en pantalla, y varios explican justamente por qué el
    # nombre viejo estaba mal. Un `(?<![-#])` sobre el archivo entero no
    # alcanza — el `-#` está al principio del renglón, no pegado a la palabra.
    culpables = Dir[Rails.root.join("app/views/**/*.haml")].select do |archivo|
      File.readlines(archivo)
          .reject { |linea| linea.lstrip.start_with?("-#", "/") }
          .any? { |linea| linea.match?(/\b(Bachillerato|Preescolar)\b/) }
    end.map { |a| a.delete_prefix("#{Rails.root}/") }

    assert_empty culpables,
                 "estas vistas escriben el nombre viejo de un nivel en vez de pedirlo " \
                 "a `GradoOficial.etiqueta`: #{culpables.join(', ')}"
  end

  # ── «Materias» → «Áreas de aprendizaje» ───────────────────────────────────

  test "el área de aprendizaje se llama como la llama el MPPE" do
    assert_equal "Áreas de aprendizaje", Vocabulario::AREAS
    assert_equal "Área", Vocabulario::AREA_CORTA
  end

  # ⚠️ El plural va ESCRITO. `"área".pluralize` devuelve «área» —el inflector de
  # Rails es inglés— y el proyecto ya tiene `ApplicationHelper#contar` por eso.
  test "el plural de área no se deduce" do
    assert_equal "1 área de aprendizaje", Vocabulario.areas(1)
    assert_equal "3 áreas de aprendizaje", Vocabulario.areas(3)
    assert_equal "3 áreas", Vocabulario.areas(3, corto: true)
  end

  # ⚠️ La URL se queda en `/materias`, y no es un olvido: `/areas-de-aprendizaje`
  # son veintiún caracteres para lo mismo, y `MOR-162` dice que la URL se lee
  # bien, no que repita el término oficial.
  test "la URL sigue siendo corta" do
    assert_equal "/materias", Rails.application.routes.url_helpers.subjects_path
  end

  # ⚠️ Y el MODELO tampoco: `Subject` es de donde Rails deduce la tabla y las
  # asociaciones. Renombrarlo sería una migración para arreglar un problema de
  # texto.
  test "el modelo sigue siendo Subject" do
    assert_equal "subjects", Subject.table_name
  end
end
