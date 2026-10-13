module Siga
  # El estado de la cartera: quién está al día, quién debe, cuánto factura la
  # plataforma (MOR-108).
  #
  # Vive acá y no en el panel del colegio por la misma razón que el pipeline
  # comercial: **es dato de SIGA**. Un colegio tiene derecho a saber si ÉL está
  # al día —eso se lo dice su propio panel— pero no a ver quién más debe.
  #
  # ⚠️ Ya no tiene «Dar de alta». Servía para el colegio SIN suscripción, y
  # desde el cobro por alumno ninguno queda sin ella: todo colegio nace en
  # gratis (decisión 16 del spec `del-registro-al-cobro`). Activar una
  # suscripción es validar un pago, y eso llega con la tanda 2 de ese spec.
  class CarteraController < BaseController
    def index
      Subscription.actualizar_todas!

      @colegios = School.order(:name).to_a
      @suscripciones = Subscription.all.index_by(&:school_id)

      # Una consulta para todas las matrículas, no una por colegio.
      @matriculas = matriculas_por_colegio
      @cotizaciones = @colegios.to_h do |colegio|
        alumnos = @matriculas[colegio.id]
        suscripcion = @suscripciones[colegio.id]

        [ colegio.id, suscripcion ? suscripcion.cotizacion(alumnos) : Subscription.cotizar(alumnos) ]
      end

      @facturacion = @suscripciones.values.select(&:permite_escribir?).sum { |s| s.precio_mensual.to_d }
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
