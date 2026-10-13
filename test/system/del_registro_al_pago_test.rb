require "application_system_test_case"

# Del registro al pago, de punta a punta y en un navegador (spec
# `docs/specs/del-registro-al-cobro.md`, § 8).
#
#     se registra ──► carga ──► toca «Guardar asistencia»: EL MURO, con su precio
#                                        │
#                                        ▼  «Ver cómo activarla →»
#                               «Suscripción» ──► reporta el pago ──► en revisión
#                                        │
#                                        ▼  SIGA lo valida en /siga/cartera
#                               ya pasa lista
#
# ⚠️ Va como test de SISTEMA porque tres de sus eslabones son JavaScript, y un
# test de integración los ve correctos aunque no hagan nada:
#
#     el enlace del muro     lo pinta la planilla de asistencia, del JSON
#     la unidad del monto    la cambia `medio-de-pago` al elegir el medio
#     «¿Validamos?»          el diálogo de Turbo antes de activar al colegio
#
# El muro se toca por la ASISTENCIA y no por una nota: quien paga es la
# dirección, y la dirección pasa lista pero no califica — calificar es del
# profesor, que ve el muro sin precio.
class DelRegistroAlPagoTest < ApplicationSystemTestCase
  include CobroDeLaSuscripcion

  CLAVE = "clave-larga-123".freeze

  test "un colegio se registra, choca con el muro, reporta su pago, SIGA lo valida y ya pasa lista" do
    cargar_los_ajustes_de_siga
    fundador = equipo_de_siga

    # ── 1 · se registra ─────────────────────────────────────────────────────
    registrarse(correo: "rosa@delregistroalpago.test")
    directora = User.find_by!(email: "rosa@delregistroalpago.test")
    colegio   = Current.sin_aislamiento { Admin.find_by!(user_id: directora.id).school }

    assert suscripcion_de(colegio).gratis?, "un colegio recién registrado nace en gratis"

    # ── 2 · carga (es libre; aquí se arma por debajo para no repetir esos tests)
    seccion = una_seccion_con_un_alumno(colegio)

    # ── 3 · toca lo que no es cargar: el muro, con su precio y su salida ─────
    visit seccion_asistencia_path(seccion)
    esperando_la_pagina
    tocando { click_button "Guardar asistencia" }

    # Un alumno: le toca el mínimo, 45 $. El precio es final, sin IVA aparte.
    assert_text "se activan con la suscripción: 45,00 $ al mes"
    assert_no_text "IVA"
    capturar "1-el-muro"
    tocando { click_link "Ver cómo activarla" }

    # ── 4 · «Suscripción»: en qué está, cuánto cuesta y cómo pagar ───────────
    assert_current_path suscripcion_path
    assert_text "Sin suscripción activa"
    assert_text "45,00 $"
    assert_text "Banco de Venezuela (0102)"
    capturar "2-suscripcion-sin-activar"
    tocando { click_link "Reportar el pago" }

    # ── 5 · el reporte: la unidad y lo que se pide los da el medio ──────────
    assert_current_path new_suscripcion_pago_path
    esperando_la_pagina

    choose "Efectivo en dólares"
    assert_selector "[data-medio-de-pago-target='unidad']", text: "$"
    assert_selector "[data-medio-de-pago-target='conReferencia']", visible: :hidden
    assert_text "En efectivo es opcional."

    choose "Pago Móvil o transferencia"
    assert_selector "[data-medio-de-pago-target='unidad']", text: "Bs"
    assert_selector "[data-medio-de-pago-target='conReferencia']", visible: :visible
    assert_no_text "En efectivo es opcional."

    fill_in "subscription_payment[monto]", with: "18250.50"
    fill_in "subscription_payment[referencia]", with: "0012-3456"
    attach_file "subscription_payment[comprobante]", IMAGEN_DE_PRUEBA.to_s
    capturar "3-reportar-el-pago"
    tocando { click_button "Reportar el pago" }

    assert_current_path suscripcion_path, wait: 10
    assert_text "Pago en revisión"
    assert_text "Recibimos su pago"          # el aviso de arriba ya no pide pagar
    assert_no_link "Reportar el pago"        # uno a la vez
    capturar "4-suscripcion-en-revision"

    # ⚠️ Reportar no abre nada: lo abre la validación.
    assert suscripcion_de(colegio).gratis?

    # ── 6 · SIGA lo valida ──────────────────────────────────────────────────
    Capybara.reset_sessions!
    entrar_como(fundador)
    visit siga_cartera_index_path
    esperando_la_pagina

    assert_text "Pagos por validar"
    assert_text colegio.name
    assert_text "18.250,50 Bs"
    assert_text "0012-3456"
    capturar "5-cartera-por-validar"
    accept_confirm { click_button "Validar" }

    assert_text "Validado."
    assert_text "Ningún pago espera validación"
    capturar "6-cartera-validado"
    assert suscripcion_de(colegio).activa?
    assert suscripcion_de(colegio).por_alumno?

    # ── 7 · y el colegio ya pasa lista ──────────────────────────────────────
    Capybara.reset_sessions!
    entrar_como(directora, CLAVE)
    visit seccion_asistencia_path(seccion)
    esperando_la_pagina
    tocando { click_button "Guardar asistencia" }

    assert_text "Guardada"
    assert_no_text "se activan con la suscripción"

    visit suscripcion_path
    assert_text "Activa hasta el"
    assert_text "Validado"
    capturar "7-suscripcion-activa"
  end

  private

  # Con `CAPTURAS=una/carpeta`, deja una imagen de cada paso. Es para MIRAR el
  # recorrido: el test dice que funciona, no que se ve bien — lo mismo que hace
  # `correos_en_el_telefono_test` con los correos.
  def capturar(nombre)
    carpeta = ENV["CAPTURAS"].presence or return

    page.save_screenshot(File.join(carpeta, "#{nombre}.png"))
  end

  # El formulario de `/registrarse`, lleno con lo mínimo.
  def registrarse(correo:)
    visit new_user_registration_path
    fill_in "user[first_name]", with: "Rosa"
    fill_in "user[last_name]",  with: "Mendoza"
    fill_in "user[email]",      with: correo
    fill_in "user[password]",   with: CLAVE
    fill_in "user[password_confirmation]", with: CLAVE
    fill_in "school[name]",     with: "U.E. Del Registro Al Pago"
    check "nivel_primaria"
    tocando { find(".form-acciones input[type=submit]").click }

    # Registrarse siembra el colegio entero: la espera es larga a propósito.
    assert_current_path arranque_listo_path, wait: 20
  end

  # Una sección del año en curso con un alumno inscrito: lo mínimo para que
  # haya a quién pasarle lista.
  def una_seccion_con_un_alumno(colegio)
    con_el_colegio(colegio) do
      periodo = AcademicPeriod.en_curso.first!
      seccion = Section.create!(grade: Grade.order(:id).first!, academic_period: periodo, name: "A", capacity: 30)

      alumno = User.create!(first_name: "Ana", last_name: "Prueba", cedula_escolar: "E2E#{SecureRandom.hex(4).upcase}")
      estudiante = Student.create!(user: alumno, school: colegio, school_card: "E2E-1")
      Enrollment.create!(student: estudiante, section: seccion, enrollment_date: Date.current)

      seccion
    end
  end
end
