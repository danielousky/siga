# La suscripción de un colegio (MOR-108).
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

  # El contrato llega hasta 800 alumnos. `a_convenir` es el borde que el issue
  # pedía definir: arriba de eso están las redes de colegios, donde la
  # suscripción probablemente sea de la RED. Inventarle un precio automático
  # sería inventar un producto que nadie definió.
  enum :plan, { basico: 0, estandar: 1, premium: 2, a_convenir: 3 }

  # `en_gracia` no es decorativo: es la diferencia entre un colegio que se
  # atrasó una semana y uno que dejó de pagar. Sin ese estado intermedio, el
  # primero se queda sin cargar notas el lunes por una transferencia que sale el
  # martes — y la cobranza en Venezuela es lenta por razones que no son suyas.
  enum :status, { activa: 0, en_gracia: 1, vencida: 2, cancelada: 3 }

  PLANES = {
    basico:   { hasta: 150, precio: 25, etiqueta: "Básico" },
    estandar: { hasta: 400, precio: 50, etiqueta: "Estándar" },
    premium:  { hasta: 800, precio: 90, etiqueta: "Premium" }
  }.freeze

  ETIQUETAS_ESTADO = {
    "activa" => "Al día", "en_gracia" => "En gracia",
    "vencida" => "Vencida", "cancelada" => "Cancelada"
  }.freeze

  validates :school_id, uniqueness: { message: "ya tiene una suscripción" }
  validates :dias_de_gracia, numericality: { greater_than_or_equal_to: 0 }

  scope :al_dia,       -> { where(status: [:activa, :en_gracia]) }
  scope :con_problema, -> { where(status: [:vencida, :cancelada]) }

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que el resto del sistema le pregunta
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ Es la pregunta que gobierna si el colegio puede escribir. Un colegio SIN
  # suscripción puede escribir: son los que todavía no se facturan —una demo, un
  # piloto—, y bloquearlos sería romper el producto para quien lo está probando.
  def permite_escribir? = activa? || en_gracia?

  def solo_lectura? = !permite_escribir?

  def etiqueta_de_estado = ETIQUETAS_ESTADO.fetch(status, status)

  def etiqueta_de_plan
    PLANES.dig(plan.to_sym, :etiqueta) || "A convenir"
  end

  def dias_para_vencer
    return nil if vigente_hasta.blank?

    (vigente_hasta - Date.current).to_i
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La matrícula, y el plan que le corresponde
  # ══════════════════════════════════════════════════════════════════════════

  # Alumnos con inscripción vigente en el año escolar que el colegio está
  # cursando — la respuesta a la pregunta 1 del issue.
  #
  # No los históricos: un colegio de veinte años tendría miles y pagaría el plan
  # más caro para siempre. Ni todos los `students`, que incluyen egresados.
  #
  # ⚠️ **El año escolar que cuenta es el último CON INSCRIPCIONES, no
  # `AcademicPeriod.vigente`.** Parecen lo mismo y no lo son: un colegio suele
  # tener cargado el año siguiente antes de inscribir a nadie en él, así que en
  # agosto `vigente` devuelve un período vacío y la matrícula daría **cero** —
  # el colegio pasaría al plan más barato justo antes de la inscripción.
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

  # El plan que le tocaría por su matrícula de hoy. Se OBSERVA siempre; se COBRA
  # al renovar (pregunta 2).
  def self.plan_para(alumnos)
    PLANES.each { |nombre, datos| return nombre if alumnos <= datos[:hasta] }

    :a_convenir
  end

  def self.precio_para(alumnos)
    PLANES.dig(plan_para(alumnos), :precio)
  end

  # El plan que le corresponde HOY, contra el que tiene facturado. Que difieran
  # no es un error: es exactamente lo que la pregunta 2 decidió.
  def plan_que_le_tocaria
    self.class.plan_para(matricula_actual)
  end

  def matricula_actual
    @matricula_actual ||= self.class.matricula_de(school_id)
  end

  def creció_de_plan? = plan_que_le_tocaria != plan.to_sym && !a_convenir?

  # ══════════════════════════════════════════════════════════════════════════
  # El paso del tiempo
  # ══════════════════════════════════════════════════════════════════════════

  # Mueve el estado según la fecha. Idempotente: correrlo dos veces el mismo día
  # no cambia nada, que es lo que necesita una tarea programada.
  def actualizar_estado!
    return if cancelada? || vigente_hasta.blank?

    nuevo =
      if Date.current <= vigente_hasta then :activa
      elsif Date.current <= vigente_hasta + dias_de_gracia then :en_gracia
      else :vencida
      end

    update!(status: nuevo) unless status.to_sym == nuevo
  end

  def self.actualizar_todas!
    Current.sin_aislamiento { unscoped.find_each(&:actualizar_estado!) }
  end
end
