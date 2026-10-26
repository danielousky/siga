# El turno de un año escolar (spec `horarios`, decisión 20): ningún colegio
# arranca en blanco.
#
#     TurnoDelAnio.de(anio)          # el turno, o nil si todavía no nació
#     TurnoDelAnio.de_la_foto(anio)  # el de la foto, SIN guardar: para dibujar
#     TurnoDelAnio.asegurar!(anio)   # lo crea si falta y se lo pone a las secciones sin turno
#
# ## ⚠️ Mirar no escribe
#
# Quien abre «Horarios» en un año sin turno ve la rejilla con el timbre de la
# foto, dibujado y sin guardar. El turno nace con la primera escritura —tocar
# «Armar»—, así que un GET no cambia nada, y un colegio en solo lectura mira
# sin crear filas.
module TurnoDelAnio
  NOMBRE = "Turno de la mañana"

  # El cuaderno que mandó Daniel (IMG_3975): de 7:10 a 1:00, horas de 40
  # minutos de dos en dos, y el receso de 9:50 a 10:20.
  FOTO = { entrada: "07:10", minutos_por_hora: 40, horas_al_dia: 8, receso_minutos: 30, receso_tras: 4 }.freeze

  module_function

  def de(anio)
    return unless anio

    BellSchedule.where(academic_period: anio).includes(:time_slots).order(:id).first
  end

  def de_la_foto(anio = nil)
    BellSchedule.new(name: NOMBRE, academic_period: anio).tap do |turno|
      turno.time_slots.build(HorasDelTurno.new(**FOTO).filas.map(&:to_h))
    end
  end

  # Inicial no tiene horario (decisión 14). Mientras haya un solo turno por año
  # —el segundo llega en la tanda 4—, toda sección con áreas usa ese.
  def asegurar!(anio)
    turno = de(anio) || de_la_foto(anio).tap(&:save!)
    Section.where(academic_period: anio, bell_schedule_id: nil)
           .where(grade_id: Grade.where.not(level: :preescolar).select(:id))
           .update_all(bell_schedule_id: turno.id)
    turno
  end
end
