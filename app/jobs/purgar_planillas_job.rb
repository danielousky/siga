# Borra los archivos de las importaciones viejas (MOR-126).
#
# ⚠️ Se borra el ARCHIVO, no la importación.
#
# La fila es la bitácora —quién importó qué, cuándo y con qué resultado— y eso
# se conserva. Lo que no puede quedarse para siempre es el adjunto: trae nombre,
# cédula, fecha de nacimiento y dirección de 360 menores, y treinta días después
# de cargarlo ya no le sirve a nadie.
#
# Venezuela no tiene ley de protección de datos, así que esto no lo exige
# ninguna norma. Lo exige que un servidor con el padrón de treinta colegios
# adentro es un objetivo, y que el daño de una filtración así no se repara.
#
# `de_toda_la_plataforma` porque la obligación es de SIGA, no de un colegio: un
# worker con contexto de uno solo dejaría los archivos de los otros veintinueve.
class PurgarPlanillasJob < ApplicationJob
  queue_as :default
  de_toda_la_plataforma

  def perform
    vencidas = Importacion.con_archivo_vencido.to_a
    return 0 if vencidas.empty?

    vencidas.each do |importacion|
      # `purge_later` y no `purge`: son archivos en disco y borrarlos en línea
      # deja el job esperando por E/S que no tiene por qué esperar.
      importacion.archivo.purge_later

      # ⚠️ Una importación a medias que se queda sin archivo deja de ser «lista
      # para confirmar»: ya no se puede confirmar nada. Decir la verdad en el
      # listado es parte de borrarla, no un adorno.
      importacion.update_column(:estado, Importacion.estados[:descartada]) unless importacion.confirmada?
    end

    Rails.logger.info("[PurgarPlanillasJob] #{vencidas.size} planillas encoladas para borrar")
    vencidas.size
  end
end
