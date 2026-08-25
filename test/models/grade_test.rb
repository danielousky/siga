require "test_helper"

class GradeTest < ActiveSupport::TestCase
  setup { @colegio = escenario_academico.colegio }

  # ⚠️ Regla del dominio, no una preferencia: no existe la calificación literal
  # en secundaria.
  #
  # El modelo lo permitía, justificado en que la certificación EMG de media
  # general tiene dos áreas por literal. Puede ser cierto y aun así no justifica
  # nada, porque `escala` vive en el GRADO: poner un grado de bachillerato en
  # literal pondría en literal a Matemática.
  test "un grado de secundaria no se puede calificar por literal" do
    con_el_colegio(@colegio) do
      grado = Grade.new(school: @colegio, name: "3er Año", level: :secundaria, escala: :literal)

      assert_not grado.valid?
      assert_match(/siempre es numérica/, grado.errors[:escala].to_sentence)
    end
  end

  # La primaria SÍ elige: hay colegios que califican por número desde primer
  # grado. Por eso solo se valida un lado.
  test "un grado de primaria puede calificar por número o por literal" do
    con_el_colegio(@colegio) do
      assert Grade.new(school: @colegio, name: "3er Grado", level: :primaria, escala: :literal).valid?
      assert Grade.new(school: @colegio, name: "4to Grado", level: :primaria, escala: :numerica).valid?
    end
  end

  test "un grado nuevo nace con la escala que le toca por nivel" do
    con_el_colegio(@colegio) do
      assert Grade.new(level: :primaria).escala_literal?
      assert Grade.new(level: :secundaria).escala_numerica?
    end
  end

  # Cambiar un grado de primaria a secundaria tiene que arrastrar la escala, o
  # la validación lo deja bloqueado sin decir cómo salir.
  test "pasar un grado de primaria a secundaria no lo deja en un estado imposible" do
    con_el_colegio(@colegio) do
      grado = Grade.create!(school: @colegio, name: "6to Grado", level: :primaria, escala: :literal)

      grado.update(level: :secundaria, escala: :numerica)

      assert grado.valid?
      assert grado.escala_numerica?
    end
  end
end
