require "test_helper"

# Lo que la instancia de MUESTRA hace distinto, fuera de las pantallas (spec
# `docs/specs/del-registro-al-cobro.md`, § 4.3).
#
#     LAS PUERTAS NO SE ROMPEN   ni el correo, ni la clave, ni el rol, ni el cargo
#     NO SALE NINGÚN CORREO      ni aunque haya por dónde
#
# Y cada regla se prueba dos veces: que en la muestra frena, y que fuera de ella
# NO hace nada. Una protección de la muestra que alcanzara a un colegio de
# verdad sería un director que no puede cambiarse la contraseña.
class MuestraTest < ActiveSupport::TestCase
  include ColegioDeMuestra

  setup do
    @a, @b = dos_colegios_completos
    montar_la_muestra(@a, @b)
  end

  # ── Qué es una puerta ─────────────────────────────────────────────────────

  test "las tres puertas son director, profesor y representante" do
    assert_equal %w[director profesor representante], Muestra::CUENTAS.map(&:clave)
    assert_equal "director.bolivar@mail.com", Muestra.cuenta("director").correo
  end

  test "ninguna puerta repite clave ni correo" do
    assert_equal Muestra::TODAS.size, Muestra::TODAS.map(&:clave).uniq.size
    assert_equal Muestra::TODAS.size, Muestra.correos.uniq.size
  end

  test "una puerta abre solo con ESE rol en ESE colegio" do
    puerta = Muestra.cuenta("director")
    assert_equal @a.director, Muestra.usuario_de(puerta)

    Current.sin_aislamiento { @a.colegio.update_columns(dea_code: "OTRO001") }
    assert_nil Muestra.usuario_de(puerta), "el mismo correo en otro colegio no es la puerta"
  end

  test "sin la variable, la instancia no es muestra" do
    assert_not Muestra.activa?
    en_la_muestra { assert Muestra.activa? }
    assert_not Muestra.activa?, "y vuelve a no serlo al salir del bloque"
  end

  # ── El correo y la clave de una puerta ────────────────────────────────────

  test "en la muestra, a una puerta no se le cambia la contraseña" do
    en_la_muestra do
      assert_not @a.director.update(password: "otra-clave", password_confirmation: "otra-clave")
      assert_match(/colegio de muestra/, @a.director.errors.full_messages.to_sentence)
    end

    assert @a.director.reload.valid_password?("123123"), "la clave de siempre sigue abriendo"
  end

  test "ni el correo" do
    en_la_muestra do
      assert_not @a.director.update(email: "otro@colegio.test")
    end

    assert_equal Muestra.cuenta("director").correo, @a.director.reload.email
  end

  # ⚠️ «Olvidé mi contraseña» es otra puerta al mismo cuarto.
  test "ni recuperándola" do
    en_la_muestra do
      assert_not @a.director.reset_password("otra-clave", "otra-clave")
    end

    assert @a.director.reload.valid_password?("123123")
  end

  # Lo demás de su ficha sí: la muestra está para tocarla.
  test "pero su nombre y su teléfono sí se pueden cambiar" do
    en_la_muestra do
      assert @a.director.update(first_name: "Otro Nombre")
    end
  end

  test "y a quien no es una puerta se le cambia todo" do
    en_la_muestra do
      assert @a.estudiante.update(password: "otra-clave", password_confirmation: "otra-clave")
    end
  end

  test "fuera de la muestra, esas mismas cuentas cambian su clave como cualquiera" do
    assert @a.director.update(password: "otra-clave", password_confirmation: "otra-clave")
    assert @a.director.update(email: "otro@colegio.test")
  end

  # ── El rol de una puerta ──────────────────────────────────────────────────

  test "en la muestra, el rol de una puerta no se borra" do
    con_el_colegio(@a.colegio) do
      en_la_muestra do
        assert_not @a.registro_de_admin.destroy
        assert_match(/puertas de entrada/, @a.registro_de_admin.errors.full_messages.to_sentence)

        assert_not @a.registro_de_profesor.destroy
      end

      assert Admin.exists?(@a.registro_de_admin.id)
      assert Teacher.exists?(@a.registro_de_profesor.id)
    end
  end

  # ⚠️ Abortar DESPUÉS de borrar lo que cuelga dejaría al profesor en pie y sin
  # sus secciones: la puerta abriría a un panel vacío.
  test "y al negarse no se lleva lo que cuelga de él" do
    con_el_colegio(@a.colegio) do
      antes = TeacherSection.where(teacher: @a.registro_de_profesor).count
      assert_operator antes, :>, 0

      en_la_muestra { @a.registro_de_profesor.destroy }

      assert_equal antes, TeacherSection.where(teacher: @a.registro_de_profesor).count
    end
  end

  test "ni se le cambia el cargo al director" do
    con_el_colegio(@a.colegio) do
      en_la_muestra do
        assert_not @a.registro_de_admin.update(role: :secretaria)
      end

      assert @a.registro_de_admin.reload.director?
    end
  end

  test "fuera de la muestra, el rol se borra y el cargo se cambia" do
    con_el_colegio(@a.colegio) do
      assert @a.registro_de_admin.update(role: :secretaria)
      assert @a.registro_de_admin.destroy
    end
  end

  # ── El correo ─────────────────────────────────────────────────────────────

  test "en la muestra no sale ningún correo" do
    en_la_muestra do
      assert_no_difference -> { ActionMailer::Base.deliveries.size } do
        BienvenidaMailer.cuenta_creada(@a.director).deliver_now
      end
    end
  end

  test "fuera de la muestra, el mismo correo sale" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      BienvenidaMailer.cuenta_creada(@a.director).deliver_now
    end
  end
end
