# Lo que hace falta para probar el cobro de la suscripción: los ajustes de SIGA
# con sus medios de pago, un comprobante y un pago ya reportado (spec
# `docs/specs/del-registro-al-cobro.md`, tanda 2).
#
# No se incluye en todos los tests: lo pide quien lo necesita, como
# `CorreosDeMuestra`.
module CobroDeLaSuscripcion
  # Los ajustes de la plataforma, con TODOS los medios cargados. Un test que
  # prueba qué pasa cuando falta un dato lo pide en blanco: `binance: nil`.
  #
  # Son dos tablas, como en `/siga/ajustes`: el WhatsApp va a `Setup` y lo
  # demás a `SigaSetting`. Quien llama no tiene por qué saberlo:
  # `whatsapp: nil` lo apaga igual que antes.
  #
  # ⚠️ Se reemplaza la fila si ya hay una: la tabla admite una sola
  # (`index_siga_settings_una_sola_fila`), y dos llamadas en el mismo test
  # reventarían contra ese índice en vez de probar lo que querían.
  def cargar_los_ajustes_de_siga(**cambios)
    poner_el_whatsapp(cambios.fetch(:whatsapp, "0414-1234567"))

    SigaSetting.delete_all
    SigaSetting.create!({ titular: "Empresa de Prueba, C.A.",
                          documento: "J-12345678-9", pago_movil_banco: "0102",
                          pago_movil_telefono: "0424-7654321", cuenta: "01020000000000001234",
                          binance: "987654321" }.merge(cambios.except(:whatsapp)))
  end

  # El WhatsApp de SIGA (`Setup`). `nil` lo APAGA con una fila vacía, y no lo
  # borra: sin fila valdría `SIGA_WHATSAPP`, y el test dependería de si la
  # máquina que lo corre la tiene puesta.
  def poner_el_whatsapp(numero)
    Setup.where(nombre: "whatsapp").delete_all
    Setup.create!(nombre: "whatsapp", valor: numero)
  end

  # Ningún medio: ni datos para pagar ni WhatsApp, que es por donde se
  # coordina el efectivo.
  def sin_medios_de_pago
    SigaSetting.delete_all
    poner_el_whatsapp(nil)
  end

  # Una imagen de verdad, para adjuntar: el modelo exige foto o PDF.
  IMAGEN_DE_PRUEBA = Rails.root.join("app/assets/images/escudo_vzla.png").freeze

  # Para un formulario (`post …, params:`).
  def comprobante_para_subir
    Rack::Test::UploadedFile.new(IMAGEN_DE_PRUEBA, "image/png")
  end

  # Un pago que el colegio ya reportó y espera validación.
  #
  # `reportado_el:` deja escribir CUÁNDO se reportó sin viajar en el tiempo: la
  # regla de «pagó tarde» mira esa fecha, no la de la validación.
  def pago_reportado(completo, medio: "pago_movil", reportado_el: nil, **datos)
    con_el_colegio(completo.colegio) do
      pago = SubscriptionPayment.nuevo_para(Subscription.find_by!(school_id: completo.colegio.id),
                                            por: completo.director, medio: medio,
                                            monto: 50_000, pagado_el: Date.current,
                                            referencia: (medio == "efectivo" ? nil : "REF-#{SecureRandom.hex(4).upcase}"),
                                            **datos)
      unless medio == "efectivo"
        pago.comprobante.attach(io: File.open(IMAGEN_DE_PRUEBA), filename: "comprobante.png", content_type: "image/png")
      end
      pago.save!
      pago.update_columns(created_at: reportado_el.to_time.change(hour: 12)) if reportado_el
      pago
    end
  end

  # Alguien del equipo de SIGA.
  def equipo_de_siga(rol = :fundador)
    correo = "#{rol}.#{SecureRandom.hex(3)}@siga.app"
    persona = User.create!(first_name: "Equipo", last_name: rol.to_s.capitalize, password: "123123",
                           email: correo, document: "V-#{correo.bytes.sum}#{rand(1000..9999)}")
    SigaStaff.create!(user: persona, role: rol)
    persona
  end

  # Una variable de entorno, puesta y devuelta como estaba: el aviso a SIGA
  # sale solo si `SIGA_AVISOS_EMAIL` dice a quién.
  def con_la_variable(nombre, valor)
    anterior = ENV[nombre]
    ENV[nombre] = valor
    yield
  ensure
    ENV[nombre] = anterior
  end

  # Alguien de la administración del colegio con el cargo que se pida.
  def admin_del_colegio(completo, rol)
    con_el_colegio(completo.colegio) do
      persona = usuario("#{rol}#{SecureRandom.hex(2)}", completo.colegio.id)
      Admin.create!(user: persona, school: completo.colegio, role: rol)
      persona
    end
  end
end
