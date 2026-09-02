module Siga
  # El tablero de la operación: cuántos colegios, de qué tamaño, y qué se movió.
  #
  # Todo esto **no tenía dueño en ningún lado**. El total de colegios de la
  # plataforma no lo mostraba ninguna pantalla, y el pipeline comercial vivía en
  # el panel de los colegios (`MOR-133`).
  class PanelController < BaseController
    def index
      @colegios = School.order(:name).to_a

      # Una consulta por métrica y no una por colegio: con veinte colegios en la
      # plataforma, contar alumnos dentro del `each` son veinte consultas para
      # pintar una tabla.
      @alumnos_por_colegio    = Student.group(:school_id).count
      @profesores_por_colegio = Teacher.group(:school_id).count
      @secciones_por_colegio  = Section.group(:school_id).count

      @total_alumnos = @alumnos_por_colegio.values.sum
      @solicitudes_pendientes = DemoRequest.pending.count

      # Qué se movió en la plataforma esta semana. Sin `user`/`school` cargados
      # sería una consulta por fila.
      @actividad = ActivityLog.includes(:user, :school).recent.limit(15)
    end

    private

    # El plan que le toca a un colegio por su matrícula.
    #
    # ⚠️ Acá vivía una SEGUNDA tabla de planes, escrita a mano, con los precios
    # de antes de septiembre de 2026 —25/50/90—. Su propio comentario decía
    # «cuando exista MOR-108 se muda a la suscripción», y MOR-108 se cerró: la
    # mudanza es esta. Con dos tablas, subir un precio dejaba la cartera de SIGA
    # cobrando el viejo, y nadie relacionaba las dos cosas.
    def plan_por_matricula(alumnos)
      datos = Subscription::PLANES.values.find { |p| alumnos <= p[:hasta] }
      return { nombre: "Fuera de plan", precio: nil } if datos.nil?

      { nombre: datos[:etiqueta], precio: datos[:precio] }
    end
    helper_method :plan_por_matricula
  end
end
