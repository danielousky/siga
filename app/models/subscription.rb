# La suscripción de un colegio (MOR-108, y desde el 12 de octubre de 2026 el
# spec `docs/specs/del-registro-al-cobro.md`).
#
# Las cuatro decisiones que la definen están escritas en la migración; acá vive
# la que más consecuencias tiene: **al vencer se degrada a SOLO LECTURA, nunca
# se corta el acceso.**
#
# Cortarle el acceso a un colegio a mitad de año escolar es quitarle las notas de
# sus alumnos. Se gana la disputa de cobranza y se pierde el cliente, su
# reputación, y la de quien lo escuche — en un mercado de 3.900 instituciones que
# se conocen entre sí, eso vale muchísimo más que una mensualidad.
class Subscription < ApplicationRecord
  include SchoolScoped

  belongs_to :school

  # ⚠️ Dos planes y ningún nombre (decisiones 5 y 15 del spec).
  #
  #     gratis       cargar e importar, sin tope y sin fecha
  #     por_alumno   todo el sistema, para todos los colegios
  #
  # Hasta el 12 de octubre de 2026 eran bandas —Inicial, Estándar y Grande—: el
  # alumno 151 duplicaba la factura y el colegio de 800 pagaba menos por alumno
  # que el de 150. Sus valores, del 0 al 3, no se reusan; el `CHECK` de la base
  # los deja fuera.
  #
  # ⚠️ Y TODO colegio tiene su fila (decisión 16). «Sin suscripción» era acceso
  # completo y sin fecha —lo que recibía el colegio dado de alta desde `/siga`—,
  # o sea todo el producto, gratis, para siempre. Ahora todo colegio nace en
  # `gratis`, y una cortesía o un piloto es `por_alumno` a 0 $, con su
  # vencimiento como cualquier otra.
  enum :plan, { gratis: 4, por_alumno: 5 }

  # `en_gracia` no es decorativo: es la diferencia entre un colegio que se
  # atrasó una semana y uno que dejó de pagar. Sin ese estado intermedio, el
  # primero se queda sin cargar notas el lunes por una transferencia que sale el
  # martes — y la cobranza en Venezuela es lenta por razones que no son suyas.
  enum :status, { activa: 0, en_gracia: 1, vencida: 2, cancelada: 3 }

  # ⚠️ El precio, en UN lugar. Subirlo es cambiar un número aquí.
  #
  #     hasta septiembre de 2026      bandas: 25 · 50 · 90
  #     septiembre de 2026            bandas: 30 · 60 · 90
  #     5 de octubre de 2026          bandas: 39 · 79 · 119
  #     12 de octubre de 2026         0,35 $ por alumno al mes, mínimo 45 $
  #
  # ⚠️ El precio es FINAL: lleva el IVA adentro. Ese mismo 12 de octubre nació
  # como «0,30 $ + IVA, mínimo 39», y Daniel lo corrigió antes de que saliera:
  # *«no podemos cobrar IVA en dólares, eso no es correcto… vamos a
  # incrementarle el IVA al costo, 0,30 × 1,16 = 0,348, poco menos de 0,35.
  # Pongámoslo de una vez como el costo»*. Ninguna pantalla dice «más IVA» ni
  # lo calcula: lo que se lee es lo que se paga.
  #
  # ⚠️ El mínimo, 45, es la misma cuenta —39 × 1,16 = 45,24— y lo deduje yo:
  # Daniel dijo el precio por alumno, no el mínimo. Está por confirmar.
  #
  # Lo leen la portada, la descripción y la ficha para buscadores, el muro de
  # lo gratis y el panel de SIGA. Lo cuida `los_precios_de_un_solo_lugar_test`,
  # que los cambia por unos que no existen y mira que cada pantalla diga esos:
  # tres veces se quedó atrás una copia escrita a mano, y ninguna rompió nada.
  #
  # ⚠️ Y subirlo NO le cambia la factura a nadie: cada suscripción congela su
  # precio por alumno y su mínimo el día que se activa (decisión 17). Subir el
  # precio toca solo a los colegios que entran después.
  PRECIO_POR_ALUMNO = BigDecimal("0.35")
  MINIMO_MENSUAL    = BigDecimal("45")

  # Lo que cuesta un mes. Es UNA cuenta, y la hacen todos los que muestran un
  # precio: escrita dos veces, el muro diría un número y la Cartera otro.
  Cotizacion = Data.define(:alumnos, :por_alumno, :minimo, :monto) do
    # El colegio chico paga el mínimo, no sus alumnos por el precio: con el de
    # hoy, hasta 128 alumnos.
    def en_el_minimo? = alumnos * por_alumno <= minimo
  end

  ETIQUETAS_ESTADO = {
    "activa" => "Al día", "en_gracia" => "En gracia",
    "vencida" => "Vencida", "cancelada" => "Cancelada"
  }.freeze

  validates :school_id, uniqueness: { message: "ya tiene una suscripción" }
  validates :dias_de_gracia, numericality: { greater_than_or_equal_to: 0 }

  scope :al_dia,       -> { where(status: [:activa, :en_gracia]) }
  scope :con_problema, -> { where(status: [:vencida, :cancelada]) }

  # La suscripción con que nace todo colegio: el que se registra y el que se da
  # de alta desde `/siga` (decisión 16). Una sola forma de abrirla, para que los
  # dos nazcan iguales.
  def self.abrir_gratis!(colegio, nota: "Gratis: creada al registrarse.")
    create!(school: colegio, plan: :gratis, status: :activa, precio_mensual: 0,
            vigente_desde: Date.current, notas: nota)
  end

  # ⚠️ Los valores por defecto se leen al LLAMAR, no al cargar la clase: es lo
  # que deja a `los_precios_de_un_solo_lugar_test` cambiar el precio y ver la
  # pantalla nueva.
  def self.cotizar(alumnos, por_alumno: PRECIO_POR_ALUMNO, minimo: MINIMO_MENSUAL)
    monto = [ (alumnos * por_alumno).round(2), minimo ].max

    Cotizacion.new(alumnos: alumnos, por_alumno: por_alumno, minimo: minimo, monto: monto)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que el resto del sistema le pregunta
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ Es la pregunta que gobierna si el colegio puede escribir: solo lectura es
  # vencida o cancelada. Lo gratis es otra pregunta, la de abajo.
  def permite_escribir? = activa? || en_gracia?

  # ⚠️ Esto pregunta por el PLAN, no por la solvencia — y la diferencia importa.
  #
  # Son dos estados que se parecen y no son lo mismo:
  #
  #   gratis    NUNCA tuvo estas funciones. No se le quita nada: es su plan.
  #   vencida   LAS TENÍA y debe dinero. Eso ya lo resuelve `permite_escribir?`,
  #             que lo deja en solo lectura — no puede calificar ni pasar lista,
  #             pero SÍ puede emitir una constancia, porque «la deuda es del
  #             colegio y el perjuicio no puede ser del alumno» (MOR-108).
  #
  # Mezclarlos le quitaría a un colegio endeudado la constancia que una familia
  # necesita para un pasaporte, que es la regla que este proyecto ya decidió y
  # dejó probada. El resultado de las dos reglas juntas es el que se pidió:
  # calificar y pasar lista exigen plan Y solvencia; emitir exige plan.
  def incluye_las_funciones_del_colegio? = !gratis?

  def solo_lectura? = !permite_escribir?

  def etiqueta_de_estado = ETIQUETAS_ESTADO.fetch(status, status)

  # Sin nombres de plan (decisión 15): el colegio tiene la suscripción o no.
  def etiqueta_de_plan = gratis? ? "Gratis" : "Por alumno"

  def dias_para_vencer
    return nil if vigente_hasta.blank?

    (vigente_hasta - Date.current).to_i
  end

  # Cuántos días antes del vencimiento se avisa (§ 5.7 del spec): el colegio
  # que paga por transferencia necesita unos días, y el aviso del mismo día
  # llega tarde.
  DIAS_DE_AVISO = 5

  def por_vencer?
    activa? && (dias = dias_para_vencer) && dias.between?(0, DIAS_DE_AVISO)
  end

  # Lo que le queda de gracia a una suscripción vencida, antes de la solo
  # lectura. Es una cuenta y no un campo: la gracia empieza al día siguiente
  # del vencimiento.
  def dias_de_gracia_restantes
    return nil if vigente_hasta.blank?

    [ (vigente_hasta + dias_de_gracia - Date.current).to_i, 0 ].max
  end

  # El reporte que el colegio mandó y todavía nadie validó, si hay uno: solo
  # cabe uno a la vez (§ 5.5).
  def pago_en_revision
    return @pago_en_revision if defined?(@pago_en_revision)

    @pago_en_revision = SubscriptionPayment.where(school_id: school_id).esperando.first
  end

  # Lo que le toca este mes, con la matrícula de hoy.
  #
  # ⚠️ Con SU precio si ya lo tiene congelado, y con el de hoy si todavía está
  # en gratis: el colegio que entró a 0,35 sigue a 0,35 aunque la constante
  # suba (decisión 17).
  #
  # La matrícula se puede pasar hecha: la Cartera ya la contó para todos los
  # colegios de una vez, y contarla otra vez aquí sería una consulta por fila.
  def cotizacion(alumnos = matricula_actual)
    self.class.cotizar(alumnos,
                       por_alumno: precio_por_alumno || PRECIO_POR_ALUMNO,
                       minimo: minimo_mensual || MINIMO_MENSUAL)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La matrícula
  # ══════════════════════════════════════════════════════════════════════════

  # Alumnos con inscripción vigente en el año escolar que el colegio está
  # cursando.
  #
  # No los históricos: un colegio de veinte años tendría miles y pagaría por sus
  # egresados. Ni todos los `students`, que incluyen egresados.
  #
  # ⚠️ **El año escolar que cuenta es el último CON INSCRIPCIONES, no
  # `AcademicPeriod.vigente`.** Parecen lo mismo y no lo son: un colegio suele
  # tener cargado el año siguiente antes de inscribir a nadie en él, así que en
  # agosto `vigente` devuelve un período vacío y la matrícula daría **cero** —
  # el colegio pagaría el mínimo justo antes de la inscripción.
  #
  # Lo encontró un test, y es exactamente lo que un colegio contestaría si se le
  # pregunta cuántos alumnos tiene en agosto: los del año que viene cursando,
  # hasta que se inscriba el siguiente.
  def self.matricula_de(school_id)
    Current.sin_aislamiento do
      periodo_id = Enrollment.unscoped
                             .joins(section: :academic_period)
                             .where(school_id: school_id, status: :regular)
                             .order("academic_periods.start_date DESC")
                             .limit(1)
                             .pick("academic_periods.id")

      return 0 if periodo_id.nil?

      Enrollment.unscoped
                .joins(:section)
                .where(sections: { academic_period_id: periodo_id })
                .where(school_id: school_id, status: :regular)
                .count
    end
  end

  # ⚠️ Se OBSERVA siempre y se COBRA al renovar. Que la matrícula crezca a mitad
  # de mes no cambia lo que ya se pagó: cuenta en la renovación siguiente, que
  # desde el 12 de octubre de 2026 es cada mes.
  def matricula_actual
    @matricula_actual ||= self.class.matricula_de(school_id)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El paso del tiempo
  # ══════════════════════════════════════════════════════════════════════════

  # Mueve el estado según la fecha. Idempotente: correrlo dos veces el mismo día
  # no cambia nada, que es lo que necesita una tarea programada.
  #
  # ⚠️ Pero NO BAJA mientras un pago espera validación (§ 5.7). El colegio que
  # pagó a tiempo no puede quedar en solo lectura porque el fundador no alcanzó
  # a mirar el comprobante: la demora sería nuestra y el castigo, suyo. Subir sí
  # sube: lo que no se permite es caer.
  def actualizar_estado!
    return if cancelada? || vigente_hasta.blank?

    nuevo =
      if Date.current <= vigente_hasta then :activa
      elsif Date.current <= vigente_hasta + dias_de_gracia then :en_gracia
      else :vencida
      end

    return if status.to_sym == nuevo
    return if bajaria_a?(nuevo) && pago_en_revision.present?

    update!(status: nuevo)
  end

  def self.actualizar_todas!
    Current.sin_aislamiento { unscoped.find_each(&:actualizar_estado!) }
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La escalera: qué aviso le toca, y que salga una sola vez
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Spec `del-registro-al-cobro`, § 5.7. El sistema cobra solo, y por escalones:
  #
  #     5 días antes       aviso :por_vencer      todo funciona
  #     vence              aviso :vencio          todo funciona — son los 15 días de gracia
  #     pasados 15 días    aviso :solo_lectura    ve y descarga; no carga nada nuevo
  #
  # Daniel no persigue pagos: lo hace un trabajo diario (`LaEscaleraJob`), y lo
  # que el colegio lee en su correo es lo mismo que lee arriba de su pantalla.
  AVISOS = { por_vencer: 1, vencio: 2, solo_lectura: 3 }.freeze

  # El aviso que le corresponde HOY, o nil si ninguno.
  #
  # ⚠️ Con un pago esperando validación, ninguno. El colegio ya pagó: lo que
  # falta es que SIGA lo mire, y escribirle «su suscripción venció» mientras su
  # comprobante espera es reclamarle una demora que es nuestra.
  def aviso_que_corresponde
    return nil if gratis? || cancelada? || vigente_hasta.blank?
    return nil if pago_en_revision.present?

    if vencida? then :solo_lectura
    elsif en_gracia? then :vencio
    elsif por_vencer? then :por_vencer
    end
  end

  # El último aviso que salió PARA ESTE vencimiento. Uno anotado para el
  # vencimiento anterior no cuenta: al pagar, la cuenta empieza de nuevo sola.
  def aviso_ya_enviado
    aviso_del_vencimiento == vigente_hasta ? aviso_enviado : 0
  end

  # El aviso que hay que mandar AHORA, o nil. Cada escalón sale una sola vez, y
  # nunca uno más bajo que el que ya salió.
  #
  # ⚠️ Si el trabajo estuvo caído y se saltó un escalón, sale el de hoy y no
  # los que faltaron: a quien ya está en solo lectura no le sirve leer, tres
  # días tarde, que «vence en cinco días».
  def aviso_pendiente
    aviso = aviso_que_corresponde
    aviso if aviso && AVISOS.fetch(aviso) > aviso_ya_enviado
  end

  def anotar_aviso!(aviso)
    update_columns(aviso_enviado: AVISOS.fetch(aviso), aviso_del_vencimiento: vigente_hasta,
                   updated_at: Time.current)
  end

  # A quién se le escribe: los correos de quienes pagan en este colegio.
  #
  # Sin el `default_scope` del colegio: lo pregunta un trabajo que recorre todas
  # las suscripciones, y `Admin` filtraría por el colegio de la sesión —que ahí
  # no hay—. El colegio va escrito en la consulta.
  def correos_de_quienes_pagan
    Admin.unscoped.que_pagan.where(school_id: school_id).joins(:user)
         .where.not(users: { email: nil }).order(:id).pluck("users.email").uniq
  end

  # Hasta cuándo dura la gracia: el último día en que todo funciona.
  def fin_de_la_gracia = vigente_hasta && vigente_hasta + dias_de_gracia

  # ══════════════════════════════════════════════════════════════════════════
  # Un pago validado
  # ══════════════════════════════════════════════════════════════════════════

  # Activa el mes que cubre un pago ya validado (`SubscriptionPayment#validar!`).
  #
  # ⚠️ El precio sale del PAGO, no de la constante: es lo que el colegio vio al
  # reportar. Y queda congelado en la suscripción (decisión 17), así el que
  # entró a 0,35 sigue a 0,35 aunque el precio suba.
  def activar_con!(pago)
    update!(plan: :por_alumno, status: :activa,
            precio_por_alumno: pago.precio_por_alumno, minimo_mensual: pago.minimo_mensual,
            precio_mensual: pago.precio_mensual, matricula_facturada: pago.alumnos,
            vigente_desde: pago.cubre_desde, vigente_hasta: pago.cubre_hasta)

    # Si el mes pagado ya pasó —un pago a tiempo que se validó muy tarde—, el
    # estado lo dice la fecha, no el entusiasmo de haber validado.
    actualizar_estado!
  end

  # Desde cuándo cuenta el mes que se paga (§ 5.7 del spec):
  #
  #     primer pago               desde que se valida
  #     a tiempo o en la gracia   desde el día que vencía     sin huecos ni días encimados:
  #                                                           los días de gracia se pagan
  #     ya en solo lectura        desde que se valida         lo de solo lectura no se cobra
  #
  # ⚠️ Lo tarde se mide por cuándo REPORTÓ, no por cuándo se validó. El colegio
  # que pagó el día 14 de la gracia pagó en la gracia, aunque el fundador lo
  # mire el 20: la demora de la validación no puede moverle el mes a nadie.
  #
  # Sin la fila del medio, un colegio que paga siempre el día 14 de la gracia
  # usaría casi cuatro meses gratis al año.
  def inicio_del_mes_pagado(reportado_el:, hoy: Date.current)
    return hoy if gratis? || cancelada? || vigente_hasta.blank?
    return hoy if reportado_el > vigente_hasta + dias_de_gracia

    vigente_hasta
  end

  private

  ORDEN_DE_ESTADOS = %i[activa en_gracia vencida].freeze

  def bajaria_a?(nuevo)
    ORDEN_DE_ESTADOS.index(nuevo).to_i > ORDEN_DE_ESTADOS.index(status.to_sym).to_i
  end
end
