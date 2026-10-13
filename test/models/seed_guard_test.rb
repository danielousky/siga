require "test_helper"

# El guard que impide sembrar credenciales de prueba en la base de un colegio.
#
# Existe como clase —y no como veinte líneas dentro de `db/seeds.rb`— para que se
# pueda probar sin sembrar nada. Ver MOR-104.
class SeedGuardTest < ActiveSupport::TestCase
  # ══════════════════════════════════════════════════════════════════════════
  # Lo que tiene que dejar pasar
  # ══════════════════════════════════════════════════════════════════════════

  test "en desarrollo y en test corre, con la clave de siempre" do
    %w[development test].each do |entorno|
      guard = SeedGuard.new(entorno: entorno, variables: {})

      assert guard.verificar!
      assert_equal "123123", guard.clave, "en #{entorno} la clave de desarrollo sigue siendo el default"
    end
  end

  test "en desarrollo se puede cambiar la clave igual" do
    guard = SeedGuard.new(entorno: "development", variables: { "SIGA_SEED_PASSWORD" => "otra" })

    assert_equal "otra", guard.clave
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que tiene que frenar
  # ══════════════════════════════════════════════════════════════════════════

  test "en producción no corre, y el mensaje dice por qué" do
    guard = SeedGuard.new(entorno: "production", variables: {})

    error = assert_raises(SeedGuard::EntornoNoPermitido) { guard.verificar! }
    assert_match(/NO corren en production/, error.message)
    assert_match(/desarrollador/, error.message, "el mensaje tiene que decir qué es lo que está en juego")
  end

  # Lista blanca, no lista negra: `unless Rails.env.production?` habría dejado
  # pasar esto, y un staging con datos reales tiene el mismo problema.
  test "un staging tampoco corre, aunque no se llame production" do
    %w[staging demo qa preproduccion].each do |entorno|
      guard = SeedGuard.new(entorno: entorno, variables: {})

      assert_raises(SeedGuard::EntornoNoPermitido, "#{entorno} no puede sembrar") { guard.verificar! }
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La puerta de la demo pública
  # ══════════════════════════════════════════════════════════════════════════

  test "declarar la demo NO alcanza: la clave es obligatoria" do
    guard = SeedGuard.new(entorno: "production", variables: { "SIGA_ENTORNO_DEMO" => "1" })

    error = assert_raises(SeedGuard::FaltaLaClave) { guard.verificar! }
    assert_match(/Falta SIGA_SEED_PASSWORD/, error.message)
  end

  test "con la demo declarada Y una clave propia, corre" do
    guard = SeedGuard.new(entorno: "production", variables: {
      "SIGA_ENTORNO_DEMO" => "1", "SIGA_SEED_PASSWORD" => "una-clave-de-verdad"
    })

    assert guard.verificar!
    assert_equal "una-clave-de-verdad", guard.clave
  end

  # El default de desarrollo NO puede filtrarse a la demo pública: sería una
  # cuenta de administrador abierta a cualquiera que lea el repositorio.
  test "fuera de desarrollo nunca aparece la clave por defecto" do
    guard = SeedGuard.new(entorno: "production", variables: {
      "SIGA_ENTORNO_DEMO" => "1", "SIGA_SEED_PASSWORD" => "otra"
    })

    assert_not_equal SeedGuard::CLAVE_POR_DEFECTO, guard.clave
  end

  test "una clave vacía no cuenta como clave" do
    guard = SeedGuard.new(entorno: "production", variables: {
      "SIGA_ENTORNO_DEMO" => "1", "SIGA_SEED_PASSWORD" => "   "
    })

    assert_raises(SeedGuard::FaltaLaClave) { guard.verificar! }
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La instancia de MUESTRA: la segunda puerta
  # ══════════════════════════════════════════════════════════════════════════

  # Su clave es pública por decisión (spec `del-registro-al-cobro`, decisión 2):
  # está escrita en la pantalla de entrada. Por eso no se pide por variable —la
  # pantalla y la base tienen que decir la misma—.
  test "la muestra siembra en producción, con la clave que enseña su pantalla" do
    guard = SeedGuard.new(entorno: "production", variables: { "SIGA_MUESTRA" => "1" })

    assert guard.verificar!
    assert_equal Muestra::CLAVE, guard.clave
  end

  test "y no deja que una variable le cambie esa clave" do
    guard = SeedGuard.new(entorno: "production", variables: {
      "SIGA_MUESTRA" => "1", "SIGA_SEED_PASSWORD" => "otra-distinta"
    })

    assert_equal Muestra::CLAVE, guard.clave, "la pantalla de entrada dice esta, no la de la variable"
  end

  # ⚠️ `/siga` guarda las cuentas a donde se paga. Con la clave pública,
  # cualquiera pondría la suya en la página «cómo pagar» de la muestra.
  test "en la muestra, el equipo de SIGA NO lleva la clave pública" do
    guard = SeedGuard.new(entorno: "production", variables: { "SIGA_MUESTRA" => "1" })

    assert_not_equal Muestra::CLAVE, guard.clave_del_equipo
    assert_operator guard.clave_del_equipo.length, :>=, 24, "y no es una que se adivine"
  end

  test "salvo que alguien declare una para entrar" do
    guard = SeedGuard.new(entorno: "production", variables: {
      "SIGA_MUESTRA" => "1", "SIGA_SEED_STAFF_PASSWORD" => "la-del-equipo"
    })

    assert_equal "la-del-equipo", guard.clave_del_equipo
  end

  test "fuera de la muestra, el equipo lleva la misma clave que los demás" do
    assert_equal "123123", SeedGuard.new(entorno: "development", variables: {}).clave_del_equipo

    demo = SeedGuard.new(entorno: "production", variables: {
      "SIGA_ENTORNO_DEMO" => "1", "SIGA_SEED_PASSWORD" => "una-clave-de-verdad"
    })
    assert_equal "una-clave-de-verdad", demo.clave_del_equipo
  end

  # La puerta vieja no cambió: declarar la demo sigue exigiendo su clave.
  test "la demo de antes sigue pidiendo clave aunque exista la muestra" do
    guard = SeedGuard.new(entorno: "production", variables: { "SIGA_ENTORNO_DEMO" => "1" })

    assert_raises(SeedGuard::FaltaLaClave) { guard.verificar! }
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El correo del desarrollador
  # ══════════════════════════════════════════════════════════════════════════

  test "el desarrollador de prueba no lleva un correo personal" do
    guard = SeedGuard.new(entorno: "development", variables: {})

    assert_equal "desarrollador@siga.edu", guard.correo_desarrollador
    assert_no_match(/gmail|hotmail|outlook/, guard.correo_desarrollador)
  end

  test "el correo se puede cambiar por variable de entorno" do
    guard = SeedGuard.new(entorno: "development", variables: { "SIGA_SEED_DEV_EMAIL" => "yo@ejemplo.com" })

    assert_equal "yo@ejemplo.com", guard.correo_desarrollador
  end
end
