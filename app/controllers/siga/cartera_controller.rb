module Siga
  # El estado de la cartera: quién está al día, quién debe, cuánto factura la
  # plataforma (MOR-108).
  #
  # Vive acá y no en el panel del colegio por la misma razón que el pipeline
  # comercial: **es dato de SIGA**. Un colegio tiene derecho a saber si ÉL está
  # al día —eso se lo dice su propio panel— pero no a ver quién más debe.
  class CarteraController < BaseController
    def index
      Subscription.actualizar_todas!

      @colegios = School.order(:name).to_a
      @suscripciones = Subscription.all.index_by(&:school_id)

      # Una consulta para todas las matrículas, no una por colegio.
      @matriculas = matriculas_por_colegio

      @facturacion = @suscripciones.values.select(&:permite_escribir?).sum { |s| s.precio_mensual.to_i }
      @con_problema = @suscripciones.values.count { |s| s.solo_lectura? }
      @sin_suscripcion = @colegios.count { |c| @suscripciones[c.id].nil? }
    end

    def update
      @suscripcion = Subscription.find(params[:id])

      if @suscripcion.update(suscripcion_params)
        @suscripcion.actualizar_estado!
        redirect_to siga_cartera_index_path, notice: "Suscripción de #{@suscripcion.school.name} actualizada."
      else
        redirect_to siga_cartera_index_path, alert: @suscripcion.errors.full_messages.to_sentence
      end
    end

    # Crear la suscripción de un colegio que todavía no la tiene, con el plan que
    # le corresponde por su matrícula de hoy.
    def create
      colegio = School.find(params[:school_id])
      alumnos = Subscription.matricula_de(colegio.id)

      suscripcion = Subscription.new(
        school: colegio,
        plan: Subscription.plan_para(alumnos),
        matricula_facturada: alumnos,
        precio_mensual: Subscription.precio_para(alumnos),
        vigente_desde: Date.current,
        vigente_hasta: Date.current + 1.month,
        status: :activa
      )

      if suscripcion.save
        redirect_to siga_cartera_index_path, notice: "#{colegio.name} quedó con plan #{suscripcion.etiqueta_de_plan}."
      else
        redirect_to siga_cartera_index_path, alert: suscripcion.errors.full_messages.to_sentence
      end
    end

    private

    # La misma definición que `Subscription.matricula_de`, pero para todos los
    # colegios de una vez: el año escolar que cuenta es el último CON
    # INSCRIPCIONES, no el "vigente" por fechas — ver el comentario del modelo.
    def matriculas_por_colegio
      @colegios.to_h { |c| [c.id, Subscription.matricula_de(c.id)] }
    end

    def suscripcion_params
      params.require(:subscription).permit(:plan, :status, :precio_mensual, :vigente_hasta, :dias_de_gracia, :notas)
    end
  end
end
