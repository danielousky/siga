require "test_helper"

# El formulario público de captación (MOR-135).
#
# La regla que se prueba acá es de negocio, no de datos: **insistir no es un
# error**. Antes, `validates :email, uniqueness` le contestaba "Email ya está en
# uso" a la directora que escribía por segunda vez — o sea, el sistema le decía
# que se callara justo al prospecto más caliente que existe.
class DemoRequestTest < ActiveSupport::TestCase
  VALIDA = { name: "Ana Pérez", institution: "U.E. Ejemplo", phone: "0424-5556677" }.freeze

  test "el teléfono es obligatorio y el correo no" do
    sin_telefono = DemoRequest.new(VALIDA.except(:phone))
    assert_not sin_telefono.valid?
    assert sin_telefono.errors[:phone].any?

    sin_correo = DemoRequest.new(VALIDA)
    assert sin_correo.valid?, sin_correo.errors.full_messages.to_sentence
  end

  test "un teléfono demasiado corto no pasa" do
    assert_not DemoRequest.new(VALIDA.merge(phone: "12345")).valid?
  end

  test "un correo mal escrito no pasa, pero uno en blanco sí" do
    assert_not DemoRequest.new(VALIDA.merge(email: "esto-no-es-correo")).valid?
    assert DemoRequest.new(VALIDA.merge(email: "")).valid?
  end

  # El mismo número escrito de las cuatro formas en que se escribe en Venezuela.
  test "el teléfono se normaliza a sus últimos diez dígitos" do
    [ "0424-1234567", "+58 424 123 45 67", "(0424) 1234567", "0424 123 4567" ].each do |escrito|
      solicitud = DemoRequest.create!(VALIDA.merge(phone: escrito))
      assert_equal "4241234567", solicitud.telefono_normalizado,
                   "#{escrito.inspect} debería normalizar a 4241234567"
      solicitud.destroy
    end
  end

  test "pedir la demo dos veces suma en veces y no crea otra fila" do
    primera = DemoRequest.registrar(VALIDA)
    assert primera.persisted?
    assert_equal 1, primera.veces

    assert_no_difference "DemoRequest.count" do
      @segunda = DemoRequest.registrar(VALIDA.merge(phone: "+58 424 555 66 77"))
    end

    assert_equal primera.id, @segunda.id
    assert_equal 2, @segunda.veces
    assert @segunda.insistente?
  end

  # Lo que trae de nuevo pisa lo viejo; lo que viene en blanco no borra nada.
  test "la segunda solicitud no borra el correo que dio en la primera" do
    DemoRequest.registrar(VALIDA.merge(email: "ana@colegio.edu.ve"))
    segunda = DemoRequest.registrar(VALIDA.merge(institution: "U.E. Ejemplo (Sede Nueva)"))

    assert_equal "ana@colegio.edu.ve", segunda.email
    assert_equal "U.E. Ejemplo (Sede Nueva)", segunda.institution
  end

  test "dos personas del mismo colegio con números distintos son dos prospectos" do
    DemoRequest.registrar(VALIDA)

    assert_difference "DemoRequest.count", 1 do
      DemoRequest.registrar(VALIDA.merge(name: "Otro", phone: "0412-9998877"))
    end
  end

  # Quien ya tuvo su demo y vuelve a escribir un año después está pidiendo otra
  # cosa: pisar la fila anterior borraría el historial de la primera.
  test "una solicitud ya cerrada no se reabre: entra como nueva" do
    cerrada = DemoRequest.registrar(VALIDA)
    cerrada.update!(status: :completado)

    assert_difference "DemoRequest.count", 1 do
      nueva = DemoRequest.registrar(VALIDA)
      assert_equal 1, nueva.veces
    end
  end

  test "una solicitud inválida no toca la base ni revienta" do
    assert_no_difference "DemoRequest.count" do
      resultado = DemoRequest.registrar(name: "Ana", institution: "U.E. Ejemplo")
      assert_not resultado.persisted?
      assert resultado.errors[:phone].any?
    end
  end
end
