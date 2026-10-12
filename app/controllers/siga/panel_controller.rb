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
  end
end
