require "test_helper"
require "stringio"

# El restablecido de la muestra BORRA UNA BASE ENTERA (`RestablecerLaMuestra`).
#
#     SE NIEGA   si la instancia no se declaró muestra
#     SE NIEGA   si en la base hay un colegio que no es de la muestra
#     O TODO O NADA   si la siembra falla, lo borrado vuelve
#
# La siembra de verdad tarda un minuto y la corre `bin/ci` en su propio paso;
# aquí se reemplaza por una de mentira para probar lo que da miedo: qué borra,
# cuándo se niega y qué pasa cuando algo sale mal a la mitad.
class RestablecerLaMuestraTest < ActiveSupport::TestCase
  include ColegioDeMuestra

  setup do
    @a, @b = dos_colegios_completos
    @sembro = false
  end

  # ── Cuándo se niega ───────────────────────────────────────────────────────

  test "sin declararse muestra, no toca nada" do
    montar_la_muestra(@a, @b)

    error = assert_raises(RestablecerLaMuestra::NoEsLaMuestra) { restablecer }

    assert_match(/no se declaró muestra/, error.message)
    assert_nada_se_borro
  end

  # ⚠️ El cerrojo que mira los DATOS: es el que impide que una variable mal
  # puesta borre el sistema de los colegios.
  test "declarada muestra pero con un colegio de verdad adentro, se niega" do
    en_la_muestra do
      error = assert_raises(RestablecerLaMuestra::NoEsLaMuestra) { restablecer }

      assert_match(/NO son de la muestra/, error.message)
      assert_match(/#{Regexp.escape(@a.colegio.dea_code)}/, error.message, "y dice cuáles")
    end

    assert_nada_se_borro
  end

  test "alcanza UN colegio ajeno para negarse" do
    montar_la_muestra(@a)   # el vecino queda con su código de prueba

    en_la_muestra { assert_raises(RestablecerLaMuestra::NoEsLaMuestra) { restablecer } }

    assert_nada_se_borro
  end

  # ── Qué hace cuando sí ────────────────────────────────────────────────────

  test "en la muestra borra todo y vuelve a sembrar" do
    montar_la_muestra(@a, @b)

    en_la_muestra { restablecer }

    assert @sembro, "tiene que haber sembrado"
    Current.sin_aislamiento do
      assert_equal 0, School.count
      assert_equal 0, User.count
      assert_equal 0, ActivityGrade.unscoped.count
      assert_equal 0, ReportCard.unscoped.count
    end
  end

  # ⚠️ Los ajustes NO se van con `demo:limpiar` —son las cuentas con que SIGA
  # cobra—, pero aquí son de la muestra y se reescriben.
  test "y se lleva también los ajustes de la plataforma" do
    montar_la_muestra(@a, @b)
    SigaSetting.delete_all
    SigaSetting.create!(binance: "la-cuenta-que-puso-un-visitante")

    en_la_muestra { restablecer }

    assert_equal 0, SigaSetting.count
  end

  test "y los archivos de lo que borró" do
    montar_la_muestra(@a, @b)
    Current.sin_aislamiento do
      @a.colegio.logo.attach(io: File.open(Rails.root.join("app/assets/images/escudo_vzla.png")),
                             filename: "escudo.png", content_type: "image/png")
    end
    llave = Current.sin_aislamiento { @a.colegio.logo.blob.key }
    assert ActiveStorage::Blob.service.exist?(llave), "el escudo tiene que estar en disco antes"

    en_la_muestra { restablecer }

    assert_equal 0, ActiveStorage::Blob.count
    assert_not ActiveStorage::Blob.service.exist?(llave), "el archivo de ayer se tira del disco"
  end

  # ── O todo o nada ─────────────────────────────────────────────────────────

  # ⚠️ Nadie mira una muestra a las cuatro de la mañana: una siembra que falla
  # no puede dejarla vacía hasta que alguien se entere.
  test "si la siembra falla, lo borrado vuelve" do
    montar_la_muestra(@a, @b)

    en_la_muestra do
      assert_raises(RuntimeError) { restablecer(siembra: -> { raise "la siembra se rompió" }) }
    end

    assert_nada_se_borro
  end

  test "y los archivos de ayer siguen en el disco" do
    montar_la_muestra(@a, @b)
    Current.sin_aislamiento do
      @a.colegio.logo.attach(io: File.open(Rails.root.join("app/assets/images/escudo_vzla.png")),
                             filename: "escudo.png", content_type: "image/png")
    end
    llave = Current.sin_aislamiento { @a.colegio.logo.blob.key }

    en_la_muestra do
      assert_raises(RuntimeError) { restablecer(siembra: -> { raise "la siembra se rompió" }) }
    end

    assert ActiveStorage::Blob.service.exist?(llave), "un archivo borrado no vuelve con un ROLLBACK"
  end

  private

  def restablecer(siembra: -> { @sembro = true })
    RestablecerLaMuestra.new(salida: StringIO.new, siembra: siembra).ahora!
  end

  def assert_nada_se_borro
    Current.sin_aislamiento do
      assert_equal 2, School.where(id: [ @a.colegio.id, @b.colegio.id ]).count, "los colegios siguen ahí"
      assert User.exists?(@a.director.id)
      assert ActivityGrade.unscoped.exists?(@a.nota.id)
    end
    assert_not @sembro, "y no sembró nada encima"
  end
end
