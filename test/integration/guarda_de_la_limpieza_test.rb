require "test_helper"
require "rake"

# El guarda que protege la base antes de borrarla (MOR-146).
#
# ## Por qué esto tiene test y la tarea de borrar no
#
# La tarea de borrar se prueba corriéndola: o la base queda vacía o no. El
# GUARDA es lo contrario — su trabajo es NO dejar pasar, y eso solo se sabe
# intentando pasar. Un guarda roto no se nota hasta el día en que había que
# frenar algo, y ese día ya es tarde.
#
# Y ya falló una vez: comparaba nombres literales mientras `School` los guarda
# en mayúscula, así que declaraba que la propia demo «NO es de la demo». En
# producción pasaba por casualidad —ahí los nombres son los viejos, de antes de
# esa regla— o sea que el guarda dependía de cuándo se había sembrado la fila.
class GuardaDeLaLimpiezaTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["demo:es_solo_demo"].reenable
    @tarea = Rake::Task["demo:es_solo_demo"]
  end

  teardown { ENV.delete("SIGA_BORRAR_TAMBIEN") }

  test "deja pasar cuando solo está la demo, escriba como escriba el nombre" do
    Current.sin_aislamiento do
      School.create!(name: "U.E. Simón Bolívar", dea_code: "GUARD1", location: "Caracas")
      School.create!(name: "U.E. Andrés Bello", dea_code: "GUARD2", location: "Valencia")
    end

    assert_nothing_raised { @tarea.invoke }
  end

  # ⚠️ Lo que este guarda existe para hacer: frenar cuando hay un colegio que
  # alguien registró. Borrar acá se lleva el trabajo de una persona real.
  test "aborta cuando hay un colegio que no es de la demo" do
    Current.sin_aislamiento do
      School.create!(name: "U.E. Simón Bolívar", dea_code: "GUARD1", location: "Caracas")
      School.create!(name: "U.E. Andrés Bello", dea_code: "GUARD2", location: "Valencia")
      School.create!(name: "Colegio de Alguien", dea_code: "GUARD3", location: "Mérida")
    end

    error = assert_raises(SystemExit) { @tarea.invoke }
    assert_not_equal 0, error.status
  end

  # ⚠️ La autorización es EXPLÍCITA y por variable de entorno: el que venga
  # después no hereda el permiso de borrar el colegio de alguien.
  test "deja pasar un colegio ajeno solo si se lo autoriza por su nombre" do
    Current.sin_aislamiento do
      School.create!(name: "U.E. Simón Bolívar", dea_code: "GUARD1", location: "Caracas")
      School.create!(name: "U.E. Andrés Bello", dea_code: "GUARD2", location: "Valencia")
      School.create!(name: "Colegio de Alguien", dea_code: "GUARD3", location: "Mérida")
    end

    ENV["SIGA_BORRAR_TAMBIEN"] = "Colegio de Alguien"
    assert_nothing_raised { @tarea.invoke }
  end

  # ⚠️ Autorizar UNO no autoriza a los demás: cada nombre se escribe.
  test "autorizar un colegio no abre la puerta a otro" do
    Current.sin_aislamiento do
      School.create!(name: "U.E. Simón Bolívar", dea_code: "GUARD1", location: "Caracas")
      School.create!(name: "U.E. Andrés Bello", dea_code: "GUARD2", location: "Valencia")
      School.create!(name: "Colegio de Alguien", dea_code: "GUARD3", location: "Mérida")
      School.create!(name: "Colegio de Otro", dea_code: "GUARD4", location: "Maracay")
    end

    ENV["SIGA_BORRAR_TAMBIEN"] = "Colegio de Alguien"
    assert_raises(SystemExit) { @tarea.invoke }
  end
end
