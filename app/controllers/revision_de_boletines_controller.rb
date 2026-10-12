# El vistazo final antes de que la familia vea su boletín.
#
#     GET   /boletines/revisar   ?seccion=&lapso=&alumno=
#     PATCH /boletines/liberar   ?seccion=&lapso=
#     PATCH /boletines/esconder  ?seccion=&lapso=
#
# Daniel: *«las boletas deberán pasar por una revisión por parte de Admin antes
# de ser mostradas al representante, por si algo no está bien. Una especie de
# vistazo final. Debería poder ver una por una y cuando considere que todo está
# OK, liberar… con un solo clic»*.
#
# ## ⚠️ Por SECCIÓN y lapso, no por lapso de todo el colegio
#
# Un colegio de diecinueve secciones no revisa las diecinueve de una sentada, y
# la coordinadora de primaria no libera bachillerato. El «un solo clic» es sobre
# lo que se acaba de revisar.
class RevisionDeBoletinesController < ApplicationController
  before_action :require_emisor!
  before_action :set_seccion_y_lapso

  def show
    @boletines = BoletinesDelLapso.de(@seccion, @lapso)
    @fichas = @boletines.fichas
    @elegida = @fichas.find { |f| f.inscripcion.id == params[:alumno].to_i } || @fichas.first
    @posicion = @fichas.index(@elegida)
  end

  # ⚠️ CERRAR el lapso: el visto bueno de Control de Estudio, y todo lo que
  # cuelga de él.
  #
  # Daniel, 18 de septiembre: *«CE mira las boletas y da por "cerrado" el
  # proceso de carga y completación de la calificación. Al dar el visto bueno se
  # envía el correo al representante y ya puede entrar a ver sus notas, y a su
  # vez el profe ya no puede modificar las notas»*.
  #
  #     1 · se EMITEN los boletines que falten
  #     2 · se LIBERAN todos                     → la familia los ve
  #     3 · sale el correo a cada representante
  #     4 · el profesor deja de poder tocar las notas del lapso
  #
  # ⚠️ Y esto REEMPLAZA a «liberar», que dejaba salir lo emitido aunque
  # faltaran notas en otros boletines. El argumento de entonces —no perseguir a
  # un profesor para poder entregar los otros veinte— lo revirtió Daniel:
  # *«Admin debe validar que TODAS las boletas están completas y dar el visto
  # bueno antes de que sean liberadas»*. Cerrar no es entregar veinte
  # boletines: es declarar terminado el lapso, y un lapso con una materia en
  # blanco no está terminado.
  def cerrar
    boletines = BoletinesDelLapso.de(@seccion, @lapso)

    unless boletines.se_puede_cerrar?
      return redirect_to(revisar_boletines_path(contexto),
                         alert: motivo_por_el_que_no_se_puede_cerrar(boletines))
    end

    # Emitir, liberar y dejar el cierre viven en `BoletinesDelLapso#cerrar!`:
    # es lo mismo que hace la siembra para armar un año ya terminado.
    cierre = boletines.cerrar!(por: current_user)

    avisar_a_las_familias(cierre.boletines)
    registrar("lapso_cerrado",
              "#{current_user.nombre_completo} cerró #{@lapso.name} de " \
              "#{@seccion.grade.name} – #{@seccion.name}: " \
              "#{helpers.contar(cierre.boletines.size, 'boletín liberado', 'boletines liberados')}")

    redirect_to revisar_boletines_path(contexto), notice: aviso_del_cierre(boletines, cierre.emitidos)
  end

  # ⚠️ Reabrir existe, y no es una concesión: un error en una nota se descubre
  # DESPUÉS de cerrar, y sin esta puerta la única salida sería tocar la base.
  #
  # Deshace las tres cosas: esconde los boletines, borra el cierre y el profesor
  # vuelve a poder cargar. Lo que NO deshace es el correo que ya salió — por eso
  # el aviso lo dice.
  def reabrir
    liberados = BoletinesDelLapso.de(@seccion, @lapso).liberados.filter_map(&:boletin)
    ReportCard.where(id: liberados.map(&:id)).update_all(liberado_el: nil, liberado_por_id: nil)
    SectionClosure.where(section_id: @seccion.id, evaluation_moment_id: @lapso.id).destroy_all

    registrar("lapso_reabierto",
              "#{current_user.nombre_completo} reabrió #{@lapso.name} de " \
              "#{@seccion.grade.name} – #{@seccion.name}")

    redirect_to revisar_boletines_path(contexto),
                notice: "Lapso reabierto. Las familias dejan de ver los boletines y el profesor " \
                        "vuelve a poder cargar notas. El correo que ya salió no se puede deshacer."
  end

  private

  def set_seccion_y_lapso
    @seccion = Section.find(params[:seccion])
    @lapso = EvaluationMoment.where(academic_period_id: @seccion.academic_period_id)
                             .find_by(id: params[:lapso]) ||
             EvaluationMoment.where(academic_period_id: @seccion.academic_period_id).order(:id).first
    raise ActiveRecord::RecordNotFound if @lapso.nil?

    @lapsos = EvaluationMoment.where(academic_period_id: @seccion.academic_period_id).order(:id)
  end

  # ⚠️ Dice CUÁL de las dos cosas falta, y las notas van primero: sin notas no
  # tiene sentido mandar a escribir informes de un lapso a medio calificar.
  def motivo_por_el_que_no_se_puede_cerrar(boletines)
    return "Esta sección no tiene alumnos inscritos." if boletines.fichas.empty?
    return "Este lapso ya está cerrado." if boletines.cerrada?

    if boletines.incompletos.any?
      faltan = boletines.incompletos.size
      return "Todavía #{helpers.contar(faltan, 'alumno tiene', 'alumnos tienen')} áreas sin nota. " \
             "El lapso se cierra cuando están todas."
    end

    sin_informe = boletines.sin_informe.size
    "Todavía #{helpers.contar(sin_informe, 'alumno está', 'alumnos están')} sin informe descriptivo. " \
      "El lapso se cierra cuando todos lo tienen."
  end

  # ⚠️ Dice lo que PASÓ, no «listo»: cerrar dispara cuatro cosas y tres de
  # ellas no se ven en la pantalla que queda.
  def aviso_del_cierre(boletines, emitidos)
    partes = [ "#{@lapso.name} cerrado." ]
    partes << "Se emitieron #{helpers.contar(emitidos.size, 'boletín', 'boletines')}." if emitidos.any?
    partes << "Las familias ya pueden verlos y les salió el aviso por correo."
    partes << "El profesor no puede cambiar más las notas de este lapso."
    partes.join(" ")
  end

  def contexto = { seccion: @seccion.id, lapso: @lapso.id }

  # ⚠️ El aviso va DESPUÉS de escribir, y uno por familia.
  #
  # Y dice dos cosas distintas según la deuda: a quien está al día, que ya puede
  # descargarlo; a quien no, que está listo y qué falta para verlo. Mandarle a
  # una familia en mora «ya puede descargarlo» es prometerle una pantalla que la
  # va a rebotar.
  def avisar_a_las_familias(boletines)
    boletines.each { |boletin| BoletinMailer.liberado(boletin).deliver_later }
  end

  def registrar(accion, mensaje) = log_activity(action: accion, message: mensaje)

  # ⚠️ `emitir_documentos`, no `manage_students`: son dos permisos distintos y
  # compartían uno. El día que un colegio quiera que la secretaria cargue
  # alumnos pero no emita boletines, la tabla de `ApplicationController` cambia
  # en una línea en vez de desenredar tres controllers.
  def require_emisor!
    return if puede?(:emitir_documentos)

    redirect_to dashboard_path_for_user, alert: "No tienes permiso para revisar boletines."
  end
end
