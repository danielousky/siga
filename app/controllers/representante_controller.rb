# El portal del representante (MOR-110).
#
# ## Es la superficie más visible del producto
#
# Los demás usuarios son personal del colegio: unos pocos administrativos y
# quince profesores. **Los representantes son cientos por colegio** — dos por
# alumno, ~700 en uno de 350—, y son quienes le dan al director la sensación de
# que el sistema vale la pena. Cuando una madre le dice a la directora "qué bueno
# que ahora veo las notas desde el teléfono", eso es lo que renueva la
# suscripción.
#
# ## Entra a UNA cosa, tres veces al año, desde un teléfono
#
# No es un tablero: es una respuesta. La pantalla abre directamente en el hijo
# —si hay uno solo, que es el caso más común— con la nota del lapso arriba de
# todo. Nada de menús, nada de configurar.
#
# ## Estrictamente de lectura
#
# No hay una sola acción que escriba. Y no alcanza con no poner botones: el
# controller no expone ningún verbo que no sea GET, así que aunque alguien
# construya la petición a mano no hay nada que llamar.
class RepresentanteController < ApplicationController
  include ExigeEstarAlDia

  before_action :require_representante!
  before_action :set_representante

  # Los hijos. Con uno solo —el caso común— se entra directo a su detalle: un
  # paso menos para quien entra tres veces al año.
  #
  # ⚠️ Pero **solo si además tiene un solo colegio.** Una madre con un hijo en
  # cada colegio tiene un hijo por pantalla, y saltear esta vista la dejaría
  # encerrada en el primero sin forma de llegar al otro: el selector de colegio
  # vive acá. Lo encontré probando exactamente ese caso con los seeds.
  def index
    @hijos = hijos_con_datos

    redirect_to hijo_representante_path(@hijos.first[:student]) if @hijos.one? && colegios_del_representante.one?
  end

  def hijo
    @hijo = hijos_con_datos.find { |h| h[:student].id == params[:id].to_i }
    raise ActiveRecord::RecordNotFound if @hijo.nil?

    @inscripcion = @hijo[:inscripcion]
    return if @inscripcion.nil?

    # ⚠️ Acá viven las TRES cosas que Daniel mandó bloquear —las notas, la
    # asistencia y los boletines— así que el corte va en una sola puerta.
    #
    # ⚠️ Y es por INSCRIPCIÓN: una madre con dos hijos puede estar al día con
    # uno y deber por el otro, y `/representante` sigue mostrándole los dos.
    return if exigir_estar_al_dia!(@inscripcion)

    @lapsos  = EvaluationMoment.where(academic_period_id: @inscripcion.section.academic_period_id).order(:id).to_a
    @lapso   = @lapsos.find { |l| l.id == params[:lapso].to_i } || @lapsos.first
    @anual   = params[:lapso] == "anual"

    @materias    = materias_con_notas(@inscripcion, @lapso)
    # El informe descriptivo del lapso (MOR-216). Solo del lapso: el anual
    # cruza tres y ponerle el del primero sería mentir sobre los otros dos.
    @informe     = (Informe.para(@inscripcion.id, @lapso&.id) unless @anual)
    @asistencia  = resumen_de_asistencia(@inscripcion)
    # ⚠️ Solo los LIBERADOS. Un boletín emitido y sin revisar existe pero
    # todavía no es de la familia: la oficina tiene que darle el vistazo final
    # antes de que alguien lo lea (ver `RevisionDeBoletinesController`).
    @boletines   = boletines_del_alumno(@hijo[:student])
  end

  # Cambiar de colegio cuando se tienen hijos en más de uno.
  #
  # Guarda el id en la sesión y nada más: quien decide si ese id vale es
  # `colegio_del_representante`, contrastándolo contra los colegios donde esta
  # persona verificadamente representa a alguien. Mandar un id ajeno no hace nada.
  def cambiar_colegio
    session[:colegio_elegido_id] = params[:colegio_id].to_i

    redirect_to representante_path
  end

  private

  def hijos_con_datos
    @hijos_con_datos ||= @representante.students.includes(:user).map do |alumno|
      # ⚠️ Por el AÑO ESCOLAR, no por `enrollment_date` (MOR-165).
      #
      # La fecha de inscripción es cuándo se hizo el trámite, y una inscripción
      # tardía del año pasado tiene fecha posterior a una temprana de este.
      # El representante no elige año: ve el más reciente de su hijo.
      inscripcion = Enrollment.includes(section: [:grade, :academic_period])
                              .where(student_id: alumno.id)
                              .recientes_primero.first
      { student: alumno, inscripcion: inscripcion }
    end.sort_by { |h| h[:student].user.first_name }
  end

  # Las notas del lapso, o las definitivas del año. Es la misma pregunta que
  # responde el panel del alumno, hecha por otra persona (MOR-97).
  def materias_con_notas(inscripcion, lapso)
    grado = inscripcion.section.grade
    notas = MomentGrade.where(enrollment_id: inscripcion.id).index_by { |m| [m.subject_id, m.evaluation_moment_id] }
    libros = FinalGradeBook.where(enrollment_id: inscripcion.id).index_by(&:subject_id)

    grado.subjects.order(:name).map do |materia|
      nota_del_lapso = (notas[[materia.id, lapso&.id]] unless @anual)
      del_lapso = nota_del_lapso&.final_moment_score&.to_i
      {
        materia: materia,
        lapso: del_lapso,
        # ⚠️ Educación Inicial no pone número: describe (`MOR-218`). Sin esto la
        # familia leía «Pendiente» en las tres áreas de su hija aunque la
        # maestra las hubiera escrito todas: el texto vive en la misma fila que
        # la nota, y esta pantalla solo le preguntaba por el número.
        valoracion: nota_del_lapso&.descripcion.presence,
        definitiva: libros[materia.id]&.final_score&.to_i,
        escala: grado.escala,
        # El nivel de la rúbrica del colegio y el plan que se trabajó (MOR-136).
        # Es lo que la madre lee: no un 17, sino «PA» y qué se evaluó.
        # ⚠️ Solo donde la nota se LEE como nivel. Daniel: *«la calificación de
        # los de Media es únicamente numérica, no lleva el PD - NP»*. Un
        # muchacho de 1er Año salía con «PD (10)» en la pantalla de su mamá.
        nivel: nivel_de_rubrica(grado, del_lapso),
        competencias: competencias_de(inscripcion, materia, lapso)
      }
    end
  end

  # Los boletines que la familia puede descargar: los LIBERADOS de este alumno,
  # de este año y de los anteriores.
  #
  # ⚠️ Solo se listaban los de la inscripción vigente, así que en octubre la
  # lista estaba vacía —el primer lapso cierra en diciembre— aunque el boletín
  # final de julio estuviera emitido y `BoletinesController` lo dejara
  # descargar: existía, y no había por dónde llegar a él. Es justo cuando una
  # familia lo busca: para inscribir al hermano, o para el pasaporte.
  def boletines_del_alumno(alumno)
    ReportCard.where(enrollment_id: Enrollment.where(student_id: alumno.id).select(:id))
              .liberados
              .includes(:evaluation_moment, enrollment: { section: :academic_period })
              .order(created_at: :desc)
              .limit(8)
  end

  def rubricas_del_colegio
    @rubricas_del_colegio ||= Rubric.en_orden.to_a
  end

  # ⚠️ Se pregunta por el GRADO, no por el colegio.
  #
  # `rubricas_del_colegio` tiene filas siempre que el colegio haya definido su
  # rúbrica —y la trae sembrada— así que preguntarle a ella si hay nivel que
  # mostrar responde «sí» para bachillerato. Quien lo decide es el grado.
  def nivel_de_rubrica(grado, nota)
    return nil unless grado&.califica_con_rubrica?

    Rubric.para(nota, rubricas_del_colegio)&.code
  end
  helper_method :rubricas_del_colegio

  # El plan del lapso, con el nivel que alcanzó ESTE alumno en cada competencia.
  #
  # ⚠️ Se lee del boletín EMITIDO cuando lo hay, y del estado de hoy cuando no.
  # No es un capricho: el boletín está congelado y es lo que el colegio entregó.
  # Si la maestra corrige una nota en marzo, la pantalla muestra lo de hoy y el
  # papel sigue diciendo lo de diciembre — las dos cosas son correctas, y
  # mezclarlas es lo que hace que una familia crea que le cambiaron algo.
  #
  # Acá se muestra lo de HOY: es la pantalla, no el documento.
  def competencias_de(inscripcion, materia, lapso)
    return [] if @anual || lapso.nil? || rubricas_del_colegio.empty?
    return [] unless inscripcion.section.grade.califica_con_rubrica?

    PlanEvaluado.de(section_id: inscripcion.section_id, subject_id: materia.id,
                    evaluation_moment_id: lapso.id, student_id: inscripcion.student_id,
                    rubricas: rubricas_del_colegio)
  end

  def resumen_de_asistencia(inscripcion)
    registros = Attendance.where(enrollment_id: inscripcion.id)
    {
      presente: registros.presente.count,
      ausente:  registros.ausente.count,
      tarde:    registros.tarde.count,
      sin_justificar: registros.sin_justificar.count,
      ultimas: registros.faltas.order(date: :desc).limit(5)
    }
  end

  def set_representante
    @representante = Representative.find_by(user_id: current_user.id)
    raise ActiveRecord::RecordNotFound if @representante.nil?
  end

  def require_representante!
    return if representante?

    redirect_to dashboard_path_for_user, alert: "Esta sección es para representantes."
  end
end
