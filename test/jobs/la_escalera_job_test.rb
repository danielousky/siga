require "test_helper"
require "fugit"   # lo que usa Solid Queue para leer «at 12pm every day»

# La escalera de la suscripción (`LaEscaleraJob`, spec
# `docs/specs/del-registro-al-cobro.md`, § 5.7).
#
#     5 días antes       correo: «vence el 9 de noviembre»      sigue activa
#     vence              correo: «venció; quedan 15 días»       pasa a la gracia
#     pasados 15 días    correo: solo lectura                   pasa a vencida
#
# El tiempo va detenido en cada escalón (`travel_to`), y siempre al mediodía en
# UTC: es la hora a la que corre el trabajo, y a la que la fecha es la misma en
# Venezuela.
class LaEscaleraJobTest < ActiveJob::TestCase
  include CobroDeLaSuscripcion
  include ActionMailer::TestHelper

  VENCE = Date.new(2026, 11, 9)

  setup do
    travel_to Time.utc(2026, 10, 20, 12)
    @a, @b = dos_colegios_completos
    pagando(@a, vence: VENCE)
    # El otro colegio está lejos de vencer: no tiene que recibir nada.
    pagando(@b, vence: VENCE + 6.months)
    @finanzas = admin_del_colegio(@a, :finanzas)
    @secretaria = admin_del_colegio(@a, :secretaria)
  end

  # ── Los tres escalones ────────────────────────────────────────────────────

  test "seis días antes no dice nada; cinco días antes avisa que vence" do
    el_dia(VENCE - 6) { assert_no_enqueued_emails { LaEscaleraJob.perform_now } }

    el_dia(VENCE - 5) do
      assert_enqueued_emails(1) { LaEscaleraJob.perform_now }

      correo = el_correo_de(:por_vencer)
      assert_match(/vence el 9 de noviembre de 2026/, correo.subject)
      assert suscripcion_de(@a.colegio).activa?, "avisar no cambia nada: sigue activa"
    end
  end

  test "el día después de vencer pasa a la gracia y avisa hasta cuándo funciona" do
    el_dia(VENCE + 1) do
      assert_enqueued_emails(1) { LaEscaleraJob.perform_now }

      assert suscripcion_de(@a.colegio).en_gracia?
      correo = el_correo_de(:vencio)
      assert_match(/venció/, correo.subject)
      assert_match(/24 de noviembre de 2026/, correo.subject, "los quince días de gracia terminan el 24")
    end
  end

  test "pasados los quince días queda en solo lectura, y lo dice" do
    el_dia(VENCE + 16) do
      assert_enqueued_emails(1) { LaEscaleraJob.perform_now }

      assert suscripcion_de(@a.colegio).vencida?
      assert_match(/quedó en solo lectura/, el_correo_de(:solo_lectura).subject)
    end
  end

  # ⚠️ Nadie tiene que abrir la Cartera: hasta esta tanda, el estado se movía
  # solo cuando el fundador pasaba a mirar.
  test "el estado se mueve aunque nadie abra nada" do
    el_dia(VENCE + 16) do
      assert suscripcion_de(@a.colegio).activa?, "antes de correr, la fila sigue diciendo «activa»"

      LaEscaleraJob.perform_now

      assert suscripcion_de(@a.colegio).vencida?
    end
  end

  # ── Cada correo, una sola vez ─────────────────────────────────────────────

  # El trabajo corre todos los días y un colegio pasa quince en la gracia.
  test "correrlo otra vez el mismo día no manda nada" do
    el_dia(VENCE - 5) do
      LaEscaleraJob.perform_now

      assert_no_enqueued_emails { LaEscaleraJob.perform_now }
    end
  end

  test "ni los días siguientes, mientras siga en el mismo escalón" do
    el_dia(VENCE + 1) { LaEscaleraJob.perform_now }

    (2..15).each do |dias|
      el_dia(VENCE + dias) { assert_no_enqueued_emails { LaEscaleraJob.perform_now } }
    end
  end

  test "el recorrido entero son tres correos, ni uno más" do
    correos = (-10..40).sum do |dias|
      el_dia(VENCE + dias) do
        antes = enqueued_jobs.size
        LaEscaleraJob.perform_now
        enqueued_jobs.size - antes
      end
    end

    assert_equal 3, correos
  end

  # ⚠️ Si el trabajo estuvo caído, sale el aviso de HOY y no los que faltaron:
  # a quien ya está en solo lectura no le sirve leer que «vence en cinco días».
  test "si se saltó escalones, manda solo el de hoy" do
    el_dia(VENCE + 20) do
      assert_enqueued_emails(1) { LaEscaleraJob.perform_now }

      assert_match(/solo lectura/, el_correo_de(:solo_lectura).subject)
    end
  end

  # Al pagar, la cuenta empieza de nuevo sola: el mes siguiente tiene sus avisos.
  test "después de pagar, el mes siguiente vuelve a avisar" do
    el_dia(VENCE - 5) { LaEscaleraJob.perform_now }
    pagando(@a, vence: VENCE + 1.month)

    el_dia(VENCE + 1.month - 5) do
      assert_enqueued_emails(1) { LaEscaleraJob.perform_now }
    end
  end

  # ── A quién, y a quién no ─────────────────────────────────────────────────

  # Quien lleva el dinero es quien paga (decisión 14): dirección y finanzas.
  test "le escribe a dirección y a finanzas, y a nadie más" do
    el_dia(VENCE - 5) do
      LaEscaleraJob.perform_now

      destinatarios = el_correo_de(:por_vencer).to
      assert_includes destinatarios, @a.director.email
      assert_includes destinatarios, @finanzas.email
      assert_not_includes destinatarios, @secretaria.email, "la secretaría no paga la suscripción"
      assert_not_includes destinatarios, @a.profesor.email
      assert_not_includes destinatarios, @b.director.email, "ni la dirección de otro colegio"
    end
  end

  # ⚠️ El colegio ya pagó: lo que falta es que SIGA lo mire. Escribirle «su
  # suscripción venció» con su comprobante esperando es reclamarle una demora
  # que es nuestra.
  test "con un pago esperando validación, ni baja ni reclama" do
    cargar_los_ajustes_de_siga
    el_dia(VENCE - 1) { pago_reportado(@a) }

    el_dia(VENCE + 20) do
      assert_no_enqueued_emails { LaEscaleraJob.perform_now }

      assert suscripcion_de(@a.colegio).activa?
    end
  end

  # ⚠️ Y el caso que el de arriba NO ve: quien reportó ANTES de vencer. Ahí el
  # estado ni se mueve —sigue activa—, así que lo único que lo salva del «vence
  # en cinco días» es preguntar por el pago. Sin esta prueba, quitar esa
  # pregunta no rompía nada: lo encontré rompiéndola a propósito.
  test "a quien ya reportó el pago no le avisa que está por vencer" do
    cargar_los_ajustes_de_siga
    el_dia(VENCE - 6) { pago_reportado(@a) }

    el_dia(VENCE - 5) { assert_no_enqueued_emails { LaEscaleraJob.perform_now } }
    el_dia(VENCE - 1) { assert_no_enqueued_emails { LaEscaleraJob.perform_now } }
  end

  # Un colegio en gratis no tiene vencimiento: no hay nada que avisarle.
  test "a un colegio que solo carga no le escribe" do
    con_el_colegio(@a.colegio) { suscripcion_de(@a.colegio).update!(plan: :gratis, vigente_hasta: nil, vigente_desde: nil) }

    (-6..20).each do |dias|
      el_dia(VENCE + dias) { assert_no_enqueued_emails { LaEscaleraJob.perform_now } }
    end
  end

  # ── El correo llega: el trabajo encolado lleva su colegio ─────────────────

  # ⚠️ La lección de la tanda 2. `LaEscaleraJob` no tiene colegio, y un trabajo
  # se lleva el que haya al encolarlo: sin él, el worker busca la suscripción
  # con el RLS puesto, no la encuentra, y el correo no sale — sin que nada
  # falle. Un test que entrega el correo aquí mismo NO lo ve.
  test "el correo se encola con el colegio de esa suscripción" do
    el_dia(VENCE - 5) do
      LaEscaleraJob.perform_now

      encolado = enqueued_jobs.find { |j| j["job_class"] == "MailerDeliveryJob" }
      assert_equal @a.colegio.id, encolado["school_id"], "sin colegio en la carga, el worker no encuentra la suscripción"
    end
  end

  test "y entregado, dice la fecha y el monto de ese colegio" do
    el_dia(VENCE - 5) do
      perform_enqueued_jobs { LaEscaleraJob.perform_now }

      correo = ActionMailer::Base.deliveries.last
      assert_match(/9 de noviembre de 2026/, correo.html_part.body.to_s)
      assert_match(/45,00 \$/, correo.html_part.body.to_s, "dos alumnos: le toca el mínimo")
      assert_match(/#{Regexp.escape(@a.colegio.name)}/, correo.text_part.body.to_s)
    end
  end

  # ── A qué hora corre ──────────────────────────────────────────────────────

  # ⚠️ La app corre en UTC, y «hoy» ya es mañana desde las 8 p. m. de Venezuela.
  # De noche, un colegio pasaría a la gracia un día antes de lo que dice su
  # pantalla.
  test "está agendado a una hora en que la fecha es la misma en UTC y en Venezuela" do
    tarea = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml"))
                                            .fetch("production").fetch("la_escalera_de_las_suscripciones")

    assert_equal "LaEscaleraJob", tarea["class"]
    hora_utc = Fugit.parse(tarea["schedule"]).hours.first
    assert_includes 4..23, hora_utc, "antes de las 4 UTC, en Venezuela todavía es ayer"
  end

  private

  # El mediodía en UTC de ese día: la hora a la que corre el trabajo.
  def el_dia(fecha)
    travel_to(fecha.to_time(:utc).change(hour: 12)) { yield }
  end

  # El correo encolado de ese escalón, ya armado.
  def el_correo_de(aviso)
    encolado = enqueued_jobs.reverse.find { |j| j["job_class"] == "MailerDeliveryJob" && j["arguments"][1] == aviso.to_s }
    assert encolado, "no se encoló el correo «#{aviso}»"

    con_el_colegio(@a.colegio) { SuscripcionMailer.public_send(aviso, suscripcion_de(@a.colegio)).tap(&:message) }
  end

  # Deja al colegio con su suscripción paga, venciendo el día que se diga.
  def pagando(completo, vence:)
    Current.sin_aislamiento do
      suscripcion_de(completo.colegio).update!(
        plan: :por_alumno, status: :activa,
        precio_por_alumno: Subscription::PRECIO_POR_ALUMNO, minimo_mensual: Subscription::MINIMO_MENSUAL,
        precio_mensual: Subscription::MINIMO_MENSUAL, vigente_desde: vence - 1.month, vigente_hasta: vence
      )
    end
  end
end
