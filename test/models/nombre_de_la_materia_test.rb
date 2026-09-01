require "test_helper"

# La materia se GUARDA en mayúscula y se MUESTRA en Tipo Título (MOR-188).
#
# Daniel: *«Tipo Título en pantalla y docs, mayúscula en la base. Lo que quiero
# es evitar que se vuelva un arrozConMango y terminen unas en minúsculas, otras
# Mayúsculas y otras títulos. Creéme, pasa»*.
class NombreDeLaMateriaTest < ActiveSupport::TestCase
  setup do
    @colegio = escenario_academico.colegio
    @materia = con_el_colegio(@colegio) do
      Subject.create!(code: "prb", name: "  castellano   y literatura ")
    end
  end

  test "guarda en mayúscula y muestra en Tipo Título" do
    assert_equal "CASTELLANO Y LITERATURA", @materia.name_canonico,
                 "la base guarda la forma canónica"
    assert_equal "Castellano y Literatura", @materia.name,
                 "la pantalla lee la forma de leer, con las partículas en minúscula"
  end

  test "la forma de mostrar sobrevive a recargar" do
    con_el_colegio(@colegio) do
      assert_equal "Castellano y Literatura", Subject.find(@materia.id).name
    end
  end

  # ⚠️ Ésta es LA trampa de resolverlo en el getter, y ya costó un boletín.
  #
  # `pluck` y `select` de una sola columna van directo al SQL: no pasan por el
  # modelo, así que devuelven la MAYÚSCULA. Donde ese valor se muestra, se ve
  # gritado; donde se usa como clave —el boletín cruza el nombre contra su
  # snapshot— no cruza con nada y la columna desaparece sin un error.
  test "pluck NO pasa por el getter: quien lo use tiene que saberlo" do
    con_el_colegio(@colegio) do
      assert_equal "CASTELLANO Y LITERATURA", Subject.where(id: @materia.id).pluck(:name).first
      assert_equal "Castellano y Literatura", Subject.where(id: @materia.id).first.name
    end
  end

  test "ninguna vista lee la columna cruda de la materia" do
    crudas = Dir[Rails.root.join("app/views/**/*.haml")].select do |v|
      File.read(v) =~ /subjects?\.(pluck|select)\(?:?name/
    end
    assert_empty crudas.map { |v| v.sub("#{Rails.root}/", "") },
                 "leen subjects.name por SQL y verían la mayúscula"
  end
end
