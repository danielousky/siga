require "test_helper"
require "orden_de_borrado"

# El orden en que se pueden borrar las tablas (MOR-146).
#
# ## Por qué esto vale un test
#
# `demo:limpiar` tenía la lista escrita a mano y falló DOS VECES contra
# producción, cada vez por una tabla distinta que le faltaba. Y le faltaban
# además las cinco de `MOR-136` y `MOR-216`, que nacieron después: el tercer
# intento también habría fallado.
#
# El test no comprueba una lista concreta —eso sería la misma copia del esquema
# con otro nombre— sino la PROPIEDAD que tiene que cumplir: nadie se borra
# antes que quien le apunta.
class OrdenDeBorradoTest < ActiveSupport::TestCase
  test "ninguna tabla se borra antes que otra que le apunta" do
    orden = OrdenDeBorrado.calcular
    conexion = ActiveRecord::Base.connection

    orden.each_with_index do |tabla, posicion|
      conexion.foreign_keys(tabla).each do |fk|
        destino = fk.to_table
        next if destino == tabla || !orden.include?(destino)

        assert posicion < orden.index(destino),
               "«#{tabla}» apunta a «#{destino}» y se borra después: " \
               "el DELETE va a violar #{fk.name}"
      end
    end
  end

  # ⚠️ TODAS las tablas de dominio, no las que alguien recordó. Es lo que falló
  # dos veces: `siga_staffs` y `importaciones` existían y no estaban en la lista.
  test "están todas las tablas de dominio" do
    orden = OrdenDeBorrado.calcular

    %w[schools users students teachers admins representatives siga_staffs
       importaciones academic_periods sections enrollments
       competencies indicators activity_competencies rubrics informes].each do |tabla|
      assert_includes orden, tabla, "«#{tabla}» tiene que borrarse y no está en el orden"
    end
  end

  # ⚠️ La maquinaria NO se toca: borrarla no limpia una demo, rompe la
  # instalación.
  test "la cola de trabajos y las tablas de Rails quedan afuera" do
    orden = OrdenDeBorrado.calcular

    assert_not_includes orden, "schema_migrations"
    assert_not_includes orden, "ar_internal_metadata"
    assert_empty orden.grep(/\Asolid_queue_/),
                 "la cola de trabajos es maquinaria de la plataforma, no datos de un colegio"
  end

  # ⚠️ Los ajustes de la plataforma —las cuentas con que cobra SIGA en
  # `siga_settings`, su WhatsApp y la dirección de la muestra en `setup`— no son
  # de la demo: limpiarla no se los puede llevar. Y para que borrar a las
  # personas no choque con quién los cambió, esa clave foránea se pone en nulo
  # sola.
  test "los ajustes de la plataforma quedan afuera, y sobreviven a que se borre quien los cambió" do
    orden = OrdenDeBorrado.calcular
    assert_not_includes orden, "siga_settings"
    assert_not_includes orden, "setup"

    persona = User.create!(first_name: "Quien", last_name: "Cambia", email: "cambia@siga.test", password: "123123",
                           document: "V-19000111", document_type: :cedula_v)
    SigaSetting.delete_all
    SigaSetting.create!(binance: "987654321", actualizado_por: persona)
    Setup.create!(nombre: "whatsapp", valor: "0414-1234567", actualizado_por: persona)

    persona.delete

    assert_equal "987654321", SigaSetting.actuales.binance
    assert_nil SigaSetting.actuales.actualizado_por_id
    assert_equal "0414-1234567", Setup.whatsapp
    assert_nil Setup.fila("whatsapp").actualizado_por_id
  end

  # Los pagos de la suscripción sí son del colegio: se van con él.
  test "los pagos de la suscripción se borran antes que el colegio y que las personas" do
    orden = OrdenDeBorrado.calcular

    assert_operator orden.index("subscription_payments"), :<, orden.index("schools")
    assert_operator orden.index("subscription_payments"), :<, orden.index("users")
  end

  # El orden tiene que ser estable: dos corridas dan la misma lista, o el diff
  # de una revisión no significa nada.
  test "el orden es el mismo en cada corrida" do
    assert_equal OrdenDeBorrado.calcular, OrdenDeBorrado.calcular
  end

  # ⚠️ Un ciclo no se adivina: se dice cuál es y se para.
  test "un ciclo de claves foráneas se denuncia, no se resuelve a la fuerza" do
    ciclo = { "a" => [ "b" ], "b" => [ "a" ] }

    error = assert_raises(OrdenDeBorrado::Ciclo) do
      OrdenDeBorrado.ordenar(%w[a b], ciclo)
    end
    assert_match(/a, b/, error.message)
  end
end
