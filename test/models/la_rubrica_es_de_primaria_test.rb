require "test_helper"

# La rúbrica se lee en PRIMARIA; en Media la nota es el número (MOR-136).
#
# Daniel, 14 de septiembre, con la pantalla de un muchacho de bachillerato
# delante: *«la calificación de los de Media es únicamente numérica, no lleva el
# PD - NP»*.
#
# ## Por qué se escapó
#
# `Rubric.en_orden` devuelve las cinco filas siempre que el colegio haya
# definido su rúbrica —y se siembra sola—, así que preguntarle a ELLA si hay
# nivel que mostrar contesta «sí» para todos los grados. Quien lo decide es el
# GRADO, y ningún test lo estaba mirando.
#
# ## Y alcanzaba más lejos que la pantalla
#
# El mismo dato alimenta el BOLETÍN: un muchacho de 1er Año recibía su boletín
# en PDF con la columna titulada «NIVEL», un «PD (10)» por materia y la tabla de
# los cinco niveles impresa al pie.
class LaRubricaEsDePrimariaTest < ActiveSupport::TestCase
  test "primaria se lee con rúbrica; media y preescolar, no" do
    assert grado_de(:primaria).califica_con_rubrica?
    assert_not grado_de(:secundaria).califica_con_rubrica?
    assert_not grado_de(:media_tecnica).califica_con_rubrica?
    assert_not grado_de(:preescolar).califica_con_rubrica?
  end

  # ⚠️ El boletín: `rubricas` vacía apaga las tres cosas de una vez —el nivel de
  # cada materia, el título de la columna y la leyenda del pie—.
  test "el boletín de bachillerato no trae nivel ni leyenda de rúbrica" do
    esc = escenario_academico(nombre: "Colegio de Media", nivel: :secundaria)

    datos = con_el_colegio(esc.colegio) do
      sembrar_rubrica(esc.colegio)
      ReportCardData.para(enrollment: esc.inscripcion, evaluation_moment: esc.lapso(1)).to_h
    end

    assert_nil datos["rubrica"], "la leyenda de los cinco niveles no va en un boletín de Media"
    datos["materias"].each do |materia|
      assert_not materia.key?("nivel_de_rubrica"), "«#{materia['materia']}» salió con nivel"
    end
  end

  test "el boletín de primaria SÍ trae la rúbrica" do
    esc = escenario_academico(nombre: "Colegio de Primaria", nivel: :primaria)

    datos = con_el_colegio(esc.colegio) do
      sembrar_rubrica(esc.colegio)
      ReportCardData.para(enrollment: esc.inscripcion, evaluation_moment: esc.lapso(1)).to_h
    end

    assert datos["rubrica"].present?, "en primaria la familia lee el nivel, no el 17"
  end

  private

  def grado_de(nivel)
    Grade.new(name: GradoOficial::CATALOGO.find { |g| g.nivel == nivel }&.nombre, level: nivel)
  end

  # El colegio trae su rúbrica sembrada; en un escenario de test hay que ponerla.
  def sembrar_rubrica(colegio)
    return if Rubric.exists?

    Rubric::POR_DEFECTO.each do |datos|
      Rubric.create!(school: colegio, **datos)
    end
  end
end
