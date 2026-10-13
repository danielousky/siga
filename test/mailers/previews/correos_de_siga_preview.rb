# Los correos de SIGA, para MIRARLOS antes de mandarlos.
#
#     /rails/mailers/correos_de_siga      (con el servidor de desarrollo)
#
# ⚠️ Un correo no se revisa leyendo su HTML: hay que verlo, y sobre todo verlo
# angosto — la mitad de las familias lo va a abrir desde el teléfono. Los tests
# dicen que no se corre de lado; que se VEA institucional lo dice quien lo mira.
#
# Usan los datos de la demostración (`bin/rails db:seed`). Los del colegio salen
# con el escudo si ese colegio tiene uno cargado en «Mi colegio».
#
# ⚠️ Cada correo se arma DENTRO de su colegio y se le fuerza el mensaje ahí
# (`armado`). La vista previa no pasa por `ApplicationController`, así que no
# hay colegio en la sesión: sin esto el del boletín no encuentra a la familia
# —está aislada por colegio— y sale en blanco.
class CorreosDeSigaPreview < ActionMailer::Preview
  # ── Del colegio ──────────────────────────────────────────────────────────

  def activar_el_acceso
    armado { AccesoMailer.activacion(representante, "un-codigo-de-muestra", colegio) }
  end

  def boletin_disponible
    armado { BoletinMailer.liberado(boletin) }
  end

  def mensaje_del_colegio
    armado do
      ComunicacionMailer.mensaje_del_colegio(
        destinatario: representante, colegio: colegio, remitente: director,
        asunto: "Reunión de representantes",
        cuerpo: "La reunión del 1er lapso es el viernes 17 a las 7:30 a. m., en el salón de usos múltiples.\n\n" \
                "Por favor traiga el boletín firmado."
      )
    end
  end

  # Un colegio que todavía no cargó su escudo: sale con su nombre y sus datos.
  def activar_el_acceso_sin_escudo
    sin_escudo = School.new(name: "U.E. COLEGIO SIN ESCUDO", dea_code: "PD00123456",
                            location: "Maracaibo, Zulia", direccion: "Av. 5 de Julio, Edif. Uno",
                            telefono: "0261-5551234")

    AccesoMailer.activacion(representante, "un-codigo-de-muestra", sin_escudo)
  end

  # ── De la cuenta: del colegio si la persona es de uno solo; si no, de SIGA ─

  def recuperar_la_contrasena_de_un_colegio
    CuentaMailer.reset_password_instructions(director, "un-token-de-muestra")
  end

  # María Pérez tiene hijos en los DOS colegios de la demostración.
  def recuperar_la_contrasena_con_dos_colegios
    CuentaMailer.reset_password_instructions(User.find_by!(email: "maria.perez@familia.test"), "un-token-de-muestra")
  end

  def contrasena_cambiada
    CuentaMailer.password_change(director)
  end

  # ── De SIGA ──────────────────────────────────────────────────────────────

  def bienvenida
    BienvenidaMailer.cuenta_creada(
      User.new(first_name: "YOLEIMA", last_name: "CONTRERAS", email: "yoleima@sucolegio.edu")
    )
  end

  # El aviso que le llega al equipo de SIGA cuando un colegio se registra.
  def colegio_nuevo
    anterior = ENV["SIGA_AVISOS_EMAIL"]
    ENV["SIGA_AVISOS_EMAIL"] ||= "avisos@sigaeducando.com"

    armado { PlataformaMailer.colegio_registrado(colegio, director) }
  ensure
    ENV["SIGA_AVISOS_EMAIL"] = anterior
  end

  # ── El cobro de la suscripción (spec `del-registro-al-cobro`) ─────────────

  # El aviso que le llega al equipo de SIGA cuando un colegio reporta su pago.
  def pago_por_validar
    anterior = ENV["SIGA_AVISOS_EMAIL"]
    ENV["SIGA_AVISOS_EMAIL"] ||= "avisos@sigaeducando.com"

    armado { PlataformaMailer.pago_reportado(pago_de_muestra) }
  ensure
    ENV["SIGA_AVISOS_EMAIL"] = anterior
  end

  def pago_validado
    armado { SuscripcionMailer.pago_validado(pago_de_muestra) }
  end

  def pago_rechazado
    armado { SuscripcionMailer.pago_rechazado(pago_de_muestra) }
  end

  private

  # Un pago sin guardar: la vista previa no escribe en la base.
  def pago_de_muestra
    armado_sin_mensaje do
      SubscriptionPayment.nuevo_para(
        Subscription.find_by!(school_id: colegio.id), por: director,
        medio: "pago_movil", monto: 109_586.17, referencia: "0012345678", pagado_el: Date.current,
        created_at: Time.current, cubre_desde: Date.current, cubre_hasta: Date.current + 1.month,
        motivo: "La referencia no aparece en el estado de cuenta. Revise el número y repórtelo de nuevo."
      )
    end
  end

  def armado_sin_mensaje(&) = Current.en_el_colegio(colegio, &)

  def colegio  = @colegio  ||= School.find_by!(name: "U.E. SIMÓN BOLÍVAR")
  def director = @director ||= User.find_by!(email: "director.bolivar@siga.edu")

  def representante
    @representante ||= User.find_by!(email: "carmen.lopez@familia.test")
  end

  # Un boletín de alguien cuya familia tiene correo: sin destinatario, el mailer
  # no arma nada.
  def boletin
    vinculo = StudentRepresentative.joins(representative: :user).where.not(users: { email: nil }).first!
    inscripcion = Enrollment.where(student_id: vinculo.student_id).order(:id).last
    lapso = EvaluationMoment.where(academic_period_id: inscripcion.section.academic_period_id).order(:id).first

    ReportCard.new(enrollment: inscripcion, evaluation_moment: lapso, code: "BOL-DEMO-0001")
  end

  def armado
    Current.en_el_colegio(colegio) { yield.tap(&:message) }
  end
end
