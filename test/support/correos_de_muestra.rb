# Los correos de SIGA, armados con un colegio de prueba.
#
# Los usan dos tests que miran cosas distintas del mismo correo: QUÉ dice
# (`correos_con_identidad_test`) y CÓMO se ve en un teléfono
# (`correos_en_el_telefono_test`). Escrito dos veces, el día que nazca un
# correo nuevo entraría en uno y en el otro no — y nacieron tres con el cobro
# de la suscripción (spec `del-registro-al-cobro`), que entraron aquí.
#
# No se incluye en todos los tests: lo pide quien lo necesita.
require_relative "cobro_de_la_suscripcion"

module CorreosDeMuestra
  include CobroDeLaSuscripcion

  # Deja `@a`, `@b`, `@colegio`, `@madre` y `@boletin`.
  def preparar_los_correos
    @a, @b = dos_colegios_completos(nivel: :primaria)
    @colegio = @a.colegio
    @colegio.update!(direccion: "Av. Principal, Edif. Uno", telefono: "0212-5551234")

    con_el_colegio(@colegio) do
      @madre = usuario("mama", @colegio.id)
      representante = Representative.create!(user: @madre, school: @colegio)
      StudentRepresentative.create!(student: @a.escenario.alumno, representative: representante)

      @boletin = ReportCard.create!(
        enrollment: @a.escenario.inscripcion, evaluation_moment: @a.escenario.lapso(1), issued_by: @a.director,
        snapshot: ReportCardData.para(enrollment: @a.escenario.inscripcion, evaluation_moment: @a.escenario.lapso(1))
      )
    end
  end

  def html_de(correo)  = correo.html_part.body.to_s
  def texto_de(correo) = correo.text_part.body.to_s

  def recuperacion_de(persona)
    Devise.mailer.reset_password_instructions(persona, persona.send(:set_reset_password_token))
  end

  # Los tres que escribe el colegio.
  #
  # ⚠️ Se arman DENTRO del colegio y se fuerza el mensaje ahí: el del boletín
  # busca a la familia y su estado de cuenta, que están aislados por colegio, y
  # un correo no se arma hasta que alguien le pide el mensaje.
  def correos_del_colegio
    con_el_colegio(@colegio) do
      {
        "activar el acceso"   => AccesoMailer.activacion(@madre, "un-codigo", @colegio),
        "boletín disponible"  => BoletinMailer.liberado(@boletin),
        "mensaje del colegio" => ComunicacionMailer.mensaje_del_colegio(
          destinatario: @madre, colegio: @colegio, remitente: @a.director,
          asunto: "Reunión de representantes", cuerpo: "La reunión es el viernes a las 7:30."
        )
      }.each_value(&:message)
    end
  end

  # Todos. Los de la contraseña salen del colegio: `@a.director` es de uno solo.
  def todos_los_correos
    de_siga = {
      "bienvenida"          => BienvenidaMailer.cuenta_creada(User.new(first_name: "YOLEIMA", email: "yoleima@sucolegio.edu")),
      "colegio nuevo"       => aviso_de_colegio_nuevo,
      "recuperar"           => recuperacion_de(@a.director),
      "contraseña cambiada" => Devise.mailer.password_change(@a.director)
    }
    de_siga.each_value(&:message)

    correos_del_colegio.merge(de_siga).merge(correos_del_cobro)
  end

  # Los tres del cobro de la suscripción (spec `del-registro-al-cobro`). Son de
  # SIGA: el primero le llega a su equipo, y los otros dos a quien reportó.
  #
  # ⚠️ Con el WhatsApp cargado: el del rechazo lleva su enlace solo si hay
  # número, y esa es la versión más larga — la que hay que mirar en un teléfono.
  #
  # ⚠️ Se arman UNA vez por test. Cada llamada reporta tres pagos, y la segunda
  # chocaría contra «uno en revisión a la vez».
  def correos_del_cobro
    @correos_del_cobro ||= begin
      cargar_los_ajustes_de_siga

      rechazado = pago_reportado(@a)
      con_el_colegio(@colegio) { rechazado.rechazar!(por: @a.director, motivo: "La referencia no aparece en el banco") }
      validado = pago_reportado(@a)
      con_el_colegio(@colegio) { validado.validar!(por: @a.director) }
      en_revision = pago_reportado(@a)

      con_la_variable("SIGA_AVISOS_EMAIL", "avisos@siga.test") do
        con_el_colegio(@colegio) do
          {
            "pago por validar" => PlataformaMailer.pago_reportado(en_revision),
            "pago validado"    => SuscripcionMailer.pago_validado(validado),
            "pago rechazado"   => SuscripcionMailer.pago_rechazado(rechazado)
          }.each_value(&:message)
        end
      end
    end
  end

  # ⚠️ El mensaje se fuerza DENTRO de los dos bloques: afuera ya no hay
  # dirección a la que avisar —y el mailer devuelve un correo vacío—, ni colegio
  # con el que leer sus grados, que es de donde sale «qué dicta».
  def aviso_de_colegio_nuevo
    con_la_variable("SIGA_AVISOS_EMAIL", "avisos@siga.test") do
      con_el_colegio(@colegio) { PlataformaMailer.colegio_registrado(@colegio, @a.director).tap(&:message) }
    end
  end

  def ponerle_escudo_al_colegio
    con_el_colegio(@colegio) do
      @colegio.logo.attach(io: File.open(Rails.root.join("app/assets/images/escudo_vzla.png")),
                           filename: "escudo.png", content_type: "image/png")
    end
  end

  # `con_la_variable` —una variable de entorno, puesta y devuelta como estaba—
  # viene de `CobroDeLaSuscripcion`.
end
