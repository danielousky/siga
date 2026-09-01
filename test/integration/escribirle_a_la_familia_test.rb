require "test_helper"

# Escribirle a una familia desde SIGA (MOR-181).
#
# Daniel: *«la comunicación con el representante es fundamental. Allí mismo
# debemos poder componerle un correo y enviárselo o whatsapearlo con el número
# telefónico»*.
#
# ⚠️ Los dos canales NO son dos versiones de lo mismo:
#
#     WhatsApp   un ENLACE. Abre la app con el número puesto y quien escribe
#                termina AFUERA. SIGA no se entera de si se envió.
#     Correo     lo manda SIGA y queda en la auditoría: se puede contestar
#                «¿le avisamos a la mamá de Eduardo?».
class EscribirleALaFamiliaTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos
    @representante = con_el_colegio(@a.colegio) do
      persona = User.create!(first_name: "CARMEN", last_name: "LÓPEZ",
                             email: "carmen@familia.test", document: "V-99887766")
      Representative.create!(user: persona, school: @a.colegio, phone: "0414-1112233")
    end
    sign_in @a.director
  end

  # ══════════════════════════════════════════════════════════════════════════
  # WhatsApp: un enlace, no un envío
  # ══════════════════════════════════════════════════════════════════════════

  test "el número venezolano se convierte al formato de wa.me" do
    assert_equal "584141112233", Contacto.whatsapp("0414-1112233")
  end

  # ⚠️ Se quita el CERO antes de anteponer el país: «58» + «0414…» es un número
  # que no existe, y WhatsApp abre igual con un chat hacia nadie.
  test "no deja el cero pegado al código de país" do
    assert_not Contacto.whatsapp("0414-1112233").start_with?("580")
  end

  # Un fijo no tiene WhatsApp. Un enlace que no lleva a nadie es peor que no
  # tenerlo.
  test "un teléfono fijo no ofrece WhatsApp" do
    assert_nil Contacto.whatsapp("0212-5551234")
    assert_nil Contacto.whatsapp_url("0212-5551234")
  end

  test "la ficha ofrece el enlace de WhatsApp con el saludo puesto" do
    get representative_path(@representante)

    assert_select "a[href^=?]", "https://wa.me/584141112233"
    assert_select "a[href*=?]", "text="
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El correo: lo manda SIGA
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ CERRADO hasta que alguien lo pide. Daniel: «si no le voy a enviar correo o
  # whatsapear, estorban. Si lo que voy a hacer es comunicarme, pues tenerlo a la
  # mano». Esta pantalla se abre muchas veces para mirar un teléfono y pocas para
  # escribir.
  test "el compositor está cerrado, detrás de un botón" do
    get representative_path(@representante)

    assert_select "details.compositor" do
      assert_select "summary", text: /Enviar correo/
      assert_select "form[action=?]", mensaje_al_representative_path(@representante)
      assert_select "input[name=asunto]"
      assert_select "textarea[name=cuerpo]"
    end
    assert_select "details.compositor[open]", count: 0,
                  message: "el formulario no puede venir abierto: ocupa media pantalla la mayoría de las veces"
  end

  test "se envía, y sale a nombre del colegio" do
    assert_enqueued_emails 1 do
      post mensaje_al_representative_path(@representante),
           params: { asunto: "Reunión de representantes", cuerpo: "La reunión es el viernes." }
    end

    assert_redirected_to representative_path(@representante)
    assert_match(/Mensaje enviado a carmen@familia.test/, flash[:notice])
  end

  # ⚠️ El remitente NO puede ser el colegio: ElasticEmail solo despacha dominios
  # verificados, y el único verificado es el de SIGA. La salida es el `reply_to`:
  # sale de SIGA y la respuesta va a quien escribió.
  test "el correo sale del dominio de SIGA y responde a quien lo escribió" do
    correo = ComunicacionMailer.mensaje_del_colegio(
      destinatario: @representante.user, colegio: @a.colegio,
      remitente: @a.director, asunto: "Reunión", cuerpo: "El viernes."
    )

    assert_equal [ "carmen@familia.test" ], correo.to
    assert_equal [ @a.director.email ], correo.reply_to
    assert_not correo.from.first.end_with?("@familia.test")
    # El nombre del colegio adelante: es lo que la familia reconoce en una
    # bandeja llena.
    assert_match(/\A#{Regexp.escape(@a.colegio.name)}: Reunión\z/, correo.subject)
  end

  test "no se envía sin asunto o sin mensaje" do
    assert_no_enqueued_emails do
      post mensaje_al_representative_path(@representante), params: { asunto: "", cuerpo: "Hola" }
      post mensaje_al_representative_path(@representante), params: { asunto: "Hola", cuerpo: "" }
    end
  end

  test "ni a alguien sin correo cargado" do
    con_el_colegio(@a.colegio) { @representante.user.update!(email: nil) }

    assert_no_enqueued_emails do
      post mensaje_al_representative_path(@representante), params: { asunto: "Hola", cuerpo: "Qué tal" }
    end
    assert_match(/no tiene correo cargado/, flash[:alert])
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El seguimiento (MOR-186)
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Daniel: «debemos permitir darle seguimiento a los correos, ese es otro tema
  # de Gestión importante. Simple, pero que al menos diga qué y cuándo se
  # envió».
  #
  # ⚠️ El registro de actividad NO servía: es una bitácora de quién hizo qué,
  # mezclada con altas, bajas y cambios de nota. Buscar ahí «qué le escribimos a
  # la mamá de Eduardo» es leer trescientas filas.

  test "cada correo queda guardado, con qué y cuándo" do
    assert_difference "Mensaje.unscoped.count", 1 do
      post mensaje_al_representative_path(@representante),
           params: { asunto: "Reunión", cuerpo: "La reunión es el viernes." }
    end

    mensaje = Current.sin_aislamiento { Mensaje.unscoped.order(:id).last }
    assert_equal "Reunión", mensaje.asunto
    assert_equal "La reunión es el viernes.", mensaje.cuerpo
    assert_equal @representante.user_id, mensaje.destinatario_id
    assert_equal @a.director.id, mensaje.remitente_id
  end

  # ⚠️ La dirección va CONGELADA. Si después se corrige el correo de la persona,
  # el registro tiene que seguir diciendo a dónde fue — que es justo lo que se
  # pregunta cuando alguien dice que no le llegó.
  test "guarda la dirección a la que se mandó, no la que tenga después" do
    post mensaje_al_representative_path(@representante),
         params: { asunto: "Reunión", cuerpo: "El viernes." }
    con_el_colegio(@a.colegio) { @representante.user.update!(email: "otro@familia.test") }

    mensaje = Current.sin_aislamiento { Mensaje.unscoped.order(:id).last }
    assert_equal "carmen@familia.test", mensaje.correo
  end

  test "y se ven en su ficha, del más nuevo al más viejo" do
    post mensaje_al_representative_path(@representante), params: { asunto: "El primero", cuerpo: "Uno" }
    post mensaje_al_representative_path(@representante), params: { asunto: "El segundo", cuerpo: "Dos" }

    get representative_path(@representante)

    asuntos = css_select(".mensaje-asunto").map(&:text)
    assert_equal [ "El segundo", "El primero" ], asuntos
  end

  # Los mensajes son del colegio: `SchoolScoped` los filtra y el RLS los sostiene.
  test "los correos de un colegio no se ven desde otro" do
    post mensaje_al_representative_path(@representante), params: { asunto: "Privado", cuerpo: "Algo" }

    con_el_colegio(@b.colegio) do
      assert_equal 0, Mensaje.count, "la correspondencia de un colegio se vio desde otro"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Queda constancia
  # ══════════════════════════════════════════════════════════════════════════

  test "el envío queda en la auditoría, con su asunto" do
    assert_difference "ActivityLog.unscoped.count", 1 do
      post mensaje_al_representative_path(@representante),
           params: { asunto: "Reunión de representantes", cuerpo: "La reunión es el viernes." }
    end

    registro = Current.sin_aislamiento { ActivityLog.unscoped.order(:id).last }
    assert_equal "mensaje_enviado", registro.action
    assert_equal "Mensaje enviado a la familia", registro.label
    assert_match(/«Reunión de representantes»/, registro.message)
  end

  # ⚠️ El CUERPO no se guarda. La pregunta del colegio es «¿le avisamos, y
  # cuándo?»; volcar el mensaje entero convertiría la auditoría en un archivo de
  # correspondencia con la familia, que es otra cosa y merece otra decisión.
  test "pero el cuerpo del mensaje no queda en el registro" do
    post mensaje_al_representative_path(@representante),
         params: { asunto: "Reunión", cuerpo: "Un secreto muy delicado sobre el niño." }

    registro = Current.sin_aislamiento { ActivityLog.unscoped.order(:id).last }
    assert_no_match(/secreto/, registro.message.to_s + registro.metadata.to_s)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Quién puede
  # ══════════════════════════════════════════════════════════════════════════

  test "un profesor no le escribe a la familia desde acá" do
    sign_in @a.profesor

    assert_no_enqueued_emails do
      post mensaje_al_representative_path(@representante), params: { asunto: "Hola", cuerpo: "Qué tal" }
    end
    assert_response :redirect
  end

  test "y no se le escribe a un representante de otro colegio" do
    ajeno = con_el_colegio(@b.colegio) do
      persona = User.create!(first_name: "OTRA", last_name: "PERSONA",
                             email: "otra@ajeno.test", document: "V-12121212")
      Representative.create!(user: persona, school: @b.colegio, phone: "0414-9998877")
    end

    assert_no_enqueued_emails do
      post mensaje_al_representative_path(ajeno), params: { asunto: "Hola", cuerpo: "Qué tal" }
    end
    assert_response :not_found
  end
end
