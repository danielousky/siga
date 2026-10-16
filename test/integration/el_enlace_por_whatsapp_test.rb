require "test_helper"

# El enlace de acceso, por WhatsApp de un toque (16 de octubre de 2026).
#
# Antes: [Copiar el enlace] → [WhatsApp] junto al teléfono, que abría el chat
# con un saludo y SIN el enlace → pegarlo. Ahora el botón abre el chat con el
# mensaje entero ya escrito (`ContactoHelper#whatsapp_con_el_enlace`).
class ElEnlacePorWhatsappTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos
  end

  test "con un celular, el botón abre WhatsApp con el enlace, el colegio y los hijos" do
    mama = representante(telefono: "0414-1112233", hijos: [ @a.alumno ])

    codigo = generar_codigo_para(mama)

    enlace = css_select(".codigo-de-acceso a[target=_blank]").find { |a| a["href"].start_with?("https://wa.me/") }
    assert enlace, "falta [Enviar por WhatsApp] en el bloque del código"
    assert_equal "noopener", enlace["rel"]
    assert enlace["href"].start_with?("https://wa.me/584141112233?text="), "el número va sin el cero: 58 + 414…"

    mensaje = CGI.unescape(enlace["href"].split("?text=", 2).last)
    assert_includes mensaje, activar_url(codigo), "el enlace va ENTERO en el mensaje"
    assert_includes mensaje, @a.colegio.name
    assert_includes mensaje, Normaliza.titulo(@a.alumno.user.first_name.split.first), "nombra al hijo"
    assert_includes mensaje, "#{(User::ACTIVACION_VALIDA_POR / 1.hour).to_i} horas"
    # ⚠️ `%20`, no «+»: WhatsApp documenta el primero, y un «+» que una versión
    # de la app no traduzca aparece tal cual en el chat de la mamá.
    assert_no_match(/\+/, enlace["href"].split("?text=", 2).last)
  end

  test "sin hijos vinculados, el mensaje dice «su representado»" do
    mama = representante(telefono: "0424-5556677")

    generar_codigo_para(mama)

    enlace = css_select(".codigo-de-acceso a[href^='https://wa.me/']").first
    assert_includes CGI.unescape(enlace["href"]), "las notas de su representado"
  end

  # Un fijo no tiene WhatsApp: el botón que abre un chat con nadie es peor que
  # no tenerlo (`Contacto::MOVILES`).
  test "con un teléfono fijo, o sin teléfono, no hay botón de WhatsApp" do
    [ "0212-5556677", nil ].each do |telefono|
      generar_codigo_para(representante(telefono: telefono))

      assert_select ".codigo-de-acceso a[href^='https://wa.me/']", 0, "con #{telefono.inspect} no hay chat que abrir"
      assert_select "p.codigo-de-acceso-enlace", 1, "el enlace sigue a la vista para copiarlo"
    end
  end

  # El bloque es el mismo para todos, pero solo el representante tiene teléfono.
  test "el código de un profesor no ofrece WhatsApp" do
    sign_in @a.director
    post codigo_teacher_path(@a.registro_de_profesor)
    follow_redirect!

    assert_select "p.codigo-de-acceso-enlace", 1
    assert_select ".codigo-de-acceso a[href^='https://wa.me/']", 0
  end

  private

  def representante(telefono:, hijos: [])
    @n = @n.to_i + 1
    con_el_colegio(@a.colegio) do
      persona = User.create!(first_name: "Mamá", last_name: "Prueba#{@n}", document: "7766554#{@n}",
                             document_type: :cedula_v)
      Representative.create!(school: @a.colegio, phone: telefono, user: persona).tap do |r|
        hijos.each { |hijo| StudentRepresentative.create!(student: hijo, representative: r) }
      end
    end
  end

  def generar_codigo_para(representante)
    sign_in @a.director
    post codigo_representative_path(representante)
    follow_redirect!
    session[:codigo_a_la_vista]&.dig("codigo")
  end
end
