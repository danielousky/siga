require "test_helper"

# De qué colegio es una persona, cuando es de uno solo (`User#unico_colegio`).
#
# Lo usa el correo de recuperar la contraseña, que se manda SIN sesión: sale con
# el escudo del colegio cuando no hay duda de cuál es, y de SIGA cuando la hay.
#
#     un rol, o varios, en UN colegio   →  ese colegio
#     roles en DOS colegios             →  nil   (la cuenta es una; los colegios, dos)
#     ningún rol                        →  nil   (el equipo de SIGA, o una cuenta recién creada)
class UnicoColegioTest < ActiveSupport::TestCase
  setup { @a, @b = dos_colegios_completos }

  # ⚠️ Se pregunta SIN colegio en la sesión, que es como llega el correo. Con el
  # aislamiento puesto, las tablas de roles devuelven cero filas y todo el mundo
  # sería «de ningún colegio»: el correo saldría siempre de SIGA y nadie lo
  # notaría, porque nada falla.
  test "quien tiene un solo rol es de ese colegio, aunque nadie haya iniciado sesión" do
    assert_nil Current.school, "este test tiene que correr sin colegio en la sesión"

    assert_equal @a.colegio, @a.director.unico_colegio
    assert_equal @b.colegio, @b.director.unico_colegio
  end

  test "con dos roles en el MISMO colegio sigue siendo de uno solo" do
    director = @a.director
    Current.en_el_colegio(@a.colegio) { Teacher.create!(user: director, school: @a.colegio) }

    assert_equal @a.colegio, director.unico_colegio
  end

  test "quien tiene rol en dos colegios no es de ninguno en particular" do
    director = @a.director
    Current.en_el_colegio(@b.colegio) { Teacher.create!(user: director, school: @b.colegio) }

    assert_nil director.unico_colegio
  end

  test "un representante con hijos en un solo colegio es de ese colegio" do
    madre = User.create!(first_name: "Marta", last_name: "Rivas", document: "14000111",
                         document_type: :cedula_v, email: "marta@familia.test")
    Current.en_el_colegio(@a.colegio) { Representative.create!(user: madre, school: @a.colegio) }

    assert_equal @a.colegio, madre.unico_colegio

    Current.en_el_colegio(@b.colegio) { Representative.create!(user: madre, school: @b.colegio) }
    assert_nil madre.unico_colegio, "con un hijo en cada colegio, ya no es de uno solo"
  end

  test "quien no tiene ningún rol no es de ningún colegio" do
    suelto = User.create!(first_name: "Sol", last_name: "Nadie", document: "14000222",
                          document_type: :cedula_v, email: "sol@nadie.test")

    assert_nil suelto.unico_colegio
  end

  # ⚠️ Preguntar apaga el aislamiento un instante. Tiene que quedar como estaba:
  # si no, lo que venga después en la misma petición vería la plataforma entera.
  test "preguntar no deja el aislamiento apagado" do
    @a.director.unico_colegio

    assert_not Current.tenant_scope_disabled
    assert_equal "off", ActiveRecord::Base.connection.select_value("SHOW siga.bypass_rls")
  end
end
