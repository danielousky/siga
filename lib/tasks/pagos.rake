# Un escenario de pagos para revisar a mano (spec: `docs/specs/pagos-de-la-familia.md`).
#
#     bin/rails pagos:demo
#
# ## Por qué una tarea y no un script suelto
#
# Los seeds no son datos de adorno: son los casos de QA que hacen visible cada
# regla. Un escenario de cobranza necesita los CUATRO estados a la vez —al día,
# en mora, esperando revisión y rechazado— porque la mitad de lo que hay que
# mirar es la diferencia entre ellos.
#
# ⚠️ Solo en desarrollo. Escribe datos inventados en la base que se esté usando.
namespace :pagos do
  desc "Monta un escenario de cobranza para revisar a mano (MOR-…, solo desarrollo)"
  task demo: :environment do
    abort "Solo en desarrollo." unless Rails.env.development?

    VOUCHER = Rails.root.join("db/qa/voucher_de_prueba.jpg")

    Current.sin_aislamiento do
      colegio = School.find_by(name: "U.E. SIMÓN BOLÍVAR")
      abort "Faltan los seeds: corre bin/rails db:seed" if colegio.nil?

      Current.school = colegio
      # ⚠️ El año que TIENE ALUMNOS, no la fila más nueva.
      #
      # Es la cuarta vez que aparece esta trampa en el proyecto (§ MOR-165): en
      # septiembre la fila más nueva es el año que empieza y todavía no tiene ni
      # una sección, así que el escenario se montaba sobre cero inscripciones y
      # la tarea no creaba nada — sin fallar.
      periodo = AcademicPeriod.en_operacion || AcademicPeriod.order(:start_date).last
      puts "── #{colegio.name} · #{periodo.name}"

      # ── Lo que cobra el colegio ────────────────────────────────────────────
      Fee.calendario_propuesto(periodo, mensualidad: 45, inscripcion: 120).each do |datos|
        Fee.find_or_create_by!(academic_period: periodo, nombre: datos[:nombre]) do |f|
          f.monto = datos[:monto]
          f.vence_el = datos[:vence_el]
          f.orden = datos[:orden]
        end
      end
      puts "   #{Fee.where(academic_period_id: periodo.id).count} conceptos de cobro"

      # ── Y una familia por estado ───────────────────────────────────────────
      #
      # ⚠️ Se reparte por INSCRIPCIÓN, no por representante, y hace falta: con
      # los seeds, un representante tiene dos hijos y otro ninguno inscrito en
      # este año. Repartiendo por representante, el cuarto estado —el rechazado,
      # que es el que muestra el motivo en la pantalla de la familia— no le
      # tocaba a nadie y el escenario quedaba incompleto sin avisar.
      casos = Representative.includes(:user).flat_map do |rep|
        rep.students.filter_map do |alumno|
          inscripcion = Enrollment.where(student_id: alumno.id).joins(:section)
                                  .find_by(sections: { academic_period_id: periodo.id })
          [ rep, inscripcion ] if inscripcion
        end
      end
      abort "Ningún representante tiene un hijo inscrito en #{periodo.name}." if casos.empty?

      # ⚠️ Se acotan a doce, y no es por tiempo: con los ciento ochenta
      # representantes de los seeds la bandeja de finanzas queda con noventa
      # reportes esperando, y ahí ya no se REVISA nada — se scrollea. Doce
      # alcanzan para ver los cuatro estados tres veces cada uno.
      #
      # Y van los conocidos primero: son las credenciales que están escritas en
      # el CLAUDE.md, así que quien revisa entra con las que ya sabe.
      CONOCIDOS = %w[carmen.lopez@familia.test jose.ramos@familia.test
                     maria.perez@familia.test].freeze
      casos = casos.partition { |rep, _| CONOCIDOS.include?(rep.user&.email) }.flatten(1).first(12)

      ESTADOS = %i[al_dia en_mora esperando rechazado].freeze
      casos.each_with_index do |(rep, inscripcion), i|
        estado = ESTADOS[i % ESTADOS.size]
        Charge.emitir_para(inscripcion)
        montar(estado, inscripcion, rep)
        puts format("   %-10s %-24s %s", estado,
                    inscripcion.student.user.apellidos_y_nombres.to_s[0, 24], rep.user.email)
      end

      faltan = ESTADOS - casos.each_index.map { |i| ESTADOS[i % ESTADOS.size] }
      puts "   ⚠️  sin ejemplo: #{faltan.join(', ')}" if faltan.any?
    end
  end

  # ⚠️ Cada estado se arma desde CERO cada vez: correr la tarea dos veces deja
  # el mismo escenario, no uno acumulado. Sin esto, la segunda corrida deja una
  # familia con seis reportes y ninguna manera de ver el caso limpio.
  def montar(estado, inscripcion, rep)
    cobros = Charge.where(enrollment_id: inscripcion.id).en_orden.to_a
    PaymentReport.where(enrollment_id: inscripcion.id).destroy_all
    Charge.where(id: cobros.map(&:id)).update_all(pagado_el: nil, payment_report_id: nil)

    case estado
    when :al_dia
      # Todo lo vencido, pagado. Lo que no ha vencido queda por pagar.
      vencidos = cobros.select { |c| c.vence_el <= Date.current }
      Charge.where(id: vencidos.map(&:id)).update_all(pagado_el: 1.month.ago)
    when :en_mora
      # Las primeras cuatro pagadas y el resto debiendo: es el caso que bloquea.
      Charge.where(id: cobros.first(4).map(&:id)).update_all(pagado_el: 3.months.ago)
    when :esperando
      Charge.where(id: cobros.first(4).map(&:id)).update_all(pagado_el: 3.months.ago)
      reporte = reportar(inscripcion, rep, cobros[4], "0098")
      puts "     ↳ reporte #{reporte.referencia} esperando revisión, con voucher"
    when :rechazado
      Charge.where(id: cobros.first(3).map(&:id)).update_all(pagado_el: 3.months.ago)
      reporte = reportar(inscripcion, rep, cobros[3], "0055")
      reporte.rechazar!(por: User.joins(:admins).first,
                        motivo: "La referencia no aparece en el estado de cuenta del colegio.")
    end
  end

  # ⚠️ La referencia lleva el id de la inscripción pegado.
  #
  # Es única POR COLEGIO —que es lo correcto, ver `PaymentReport`— así que dos
  # familias con la misma referencia fija revientan la tarea a mitad. Pasó, y el
  # índice hizo exactamente lo que tiene que hacer.
  def reportar(inscripcion, rep, cobro, prefijo)
    reporte = PaymentReport.create!(
      representative: rep, enrollment: inscripcion,
      referencia: "#{prefijo}-#{format('%04d', inscripcion.id % 10_000)}",
      banco: "0134", monto: cobro&.monto || 45, pagado_el: Date.current - 1,
      depositante_nombre: "José Ramos", depositante_documento: "12345678",
      nota: "Transferí desde la cuenta de su papá."
    )
    # ⚠️ El voucher entra grande a propósito: es lo que hace visible que se
    # guarda encogido. Ver `EncogeElVoucher`.
    reporte.voucher.attach(io: File.open(VOUCHER), filename: "voucher.jpg",
                           content_type: "image/jpeg")
    reporte.save!
    cobro&.update!(payment_report: reporte)
    reporte
  end
end
