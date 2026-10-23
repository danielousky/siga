class SectionsController < ApplicationController
  include PreparaLaAsistencia
  include MuestraElPlan
  include EntregaDocumentos
  include MuestraElHorario

  PESTANAS = [ :show, :alumnos, :alumno, :asistencia, :planificar, :areas, :horario ].freeze

  before_action :require_admin_access!, except: PESTANAS
  before_action :require_read_access!, only: PESTANAS
  before_action :set_section, only: PESTANAS + [ :edit, :update, :destroy ]
  before_action :cargar_la_seccion, only: PESTANAS

  # Por el nombre del grado o el de la sección: quien escribe «1er» quiere todas
  # las de primer año, y quien escribe «A» quiere las secciones A.
  CAMPOS_DE_BUSQUEDA = %w[grades.name sections.name].freeze

  def index
    # ⚠️ El año escolar ya NO se elige acá (MOR-165): lo fija el selector de la
    # barra de arriba, y vale para todas las pantallas a la vez. Este tenía su
    # propio desplegable «Todos los períodos» que contradecía al de la barra —dos
    # controles para lo mismo, en la misma pantalla.
    scope = Section.del_anio_de_la_sesion.del_nivel_de_la_sesion
                   .includes(:grade, :academic_period, leader_teacher: :user).joins(:grade, :academic_period)
    scope = scope.where(grade_id: params[:grade_id]) if params[:grade_id].present?
    # El campo de texto se suma al selector de grado, no lo reemplaza: buscar
    # «1er» y además acotar a un grado son dos preguntas distintas.
    scope = scope.where(*BusquedaSinAcentos.condicion(CAMPOS_DE_BUSQUEDA, params[:q])) if params[:q].present?
    # ⚠️ El Excel lleva TODAS las secciones que cumplen el filtro, no la página.
    #
    # Pagy corta de a veinte, y un director que filtró «Primaria» y baja la
    # lista espera los seis grados — no los primeros veinte renglones de la
    # pantalla. El orden sí es el mismo.
    return enviar_el_libro_del_colegio(scope) if request.format.xlsx?

    @pagy, @sections = pagy(scope.order("grades.name, sections.name"))
    # Agrupados por nivel: `order(:name)` intercala las tres escaleras
    # («1er Año · 1er Grado · 1er Nivel · 2do Año…») y no hay quien lo lea.
    @grades_options = helpers.grados_por_nivel
  end

  # `show` es la pestaña CALIFICAR (etapa ③). Las otras tres son
  # `alumnos` acá al lado, `asistencias#show` y `competencies#index`.
  # ⚠️ «Calificar» es DOS pantallas, según cómo califique el grado.
  #
  # En Educación Inicial la calificación es un texto por área —no hay notas, ni
  # escala, ni promedio— así que en vez de la libreta de columnas va la planilla
  # de valoraciones. La pestaña se sigue llamando igual porque es el mismo
  # trabajo: registrar cómo le fue al niño.
  def show
    return preparar_las_valoraciones if @section.grade.califica_con_texto?

    preparar_la_libreta
  end

  # ⚠️ «Alumnos» dejó de ser un panel que alterna con `hidden` y pasó a tener
  # su URL. Las otras tres pestañas son pantallas de verdad, y media fila que
  # navega y media que alterna no se le puede explicar a nadie: el botón de
  # atrás funcionaría en unas y en otras no.
  # La pestaña «Alumnos», y la MISMA lista en Excel.
  #
  # ⚠️ `format.xlsx` sobre la acción que ya existe, y no una ruta aparte: lo que
  # se baja es exactamente lo que se está viendo. Con una ruta propia, el día
  # que la pantalla cambie de criterio —incluir retirados, otro orden— el
  # archivo seguiría diciendo otra cosa y nadie se enteraría.
  def alumnos
    respond_to do |formato|
      formato.html
      formato.xlsx { enviar_la_lista(ListaDeAlumnosXlsx.new(secciones: @section)) }
    end
  end

  # La pestaña «Áreas y profesores»: quién dicta qué en esta sección, y qué
  # área del grado se quedó sin nadie.
  #
  # ⚠️ Es de la DIRECCIÓN, que es quien asigna. Al profesor no se le dibuja la
  # pestaña, y si llega por la URL vuelve a «Alumnos»: no es un secreto —son
  # sus compañeros— pero es una lista que no usa.
  def areas
    redirect_to alumnos_section_path(@section, area: params[:area]) unless can_manage_sections?
  end

  # La pestaña «Horario»: la semana de la sección, la MISMA de Académico ▸
  # Horarios (spec `horarios`, decisión 29). Daniel, el 23 de octubre de 2026:
  # *«la pestaña horario va a la sección»*.
  #
  # Quien administra la arma desde aquí, y lo que toca vuelve aquí
  # (`MuestraElHorario`). El profesor que dicta en la sección la ve publicada y
  # sin botones (decisión 13). Inicial no tiene horario (decisión 14).
  #
  # ⚠️ Con `.pdf`, la hoja para imprimir (decisión 27): lo que se ve. La pared
  # de la suscripción la reconoce por el formato —`sections` es ENTRADA, pero
  # un archivo es salida—, y con la suscripción vencida sale igual: es un GET.
  def horario
    if @section.grade.preescolar?
      return redirect_to(alumnos_section_path(@section), alert: "Educación Inicial no lleva horario de clases.")
    end

    @en_la_seccion = true
    @anio = @section.academic_period
    preparar_el_dia_y_los_bloques
    preparar_la_semana_de(@section, @anio, solo_publicada: !administrador?)

    respond_to do |formato|
      formato.html
      formato.pdf do
        next head(:not_found) unless @rejilla.visible? && @rejilla.carga.ubicadas.positive?

        entregar_el_horario(HorarioPdf::DeLaSeccion.new(@rejilla, colegio: Current.school))
      end
    end
  end

  # La ficha del alumno COMO LA VE SU PROFESOR (etapa ③).
  #
  #     ┌─────────────────────────────────────────────────────────┐
  #     │ ╭────╮ López Medina, Álvaro José        [← Volver]      │
  #     │ │ LA │ 1er Nivel – U · 2025-2026                        │
  #     │ ╰────╯                                                  │
  #     ├─────────────────────────────────────────────────────────┤
  #     │ A QUIÉN LLAMAR                                          │
  #     │ María Pérez · Madre    0414-1234567  [WhatsApp]         │
  #     ├─────────────────────────────────────────────────────────┤
  #     │ CÓMO VA                     ASISTENCIA                  │
  #     │ Comunicación y Repr.        18 de 20 días               │
  #     │ 1er lapso · «Se integró…»   2 inasistencias             │
  #     ├─────────────────────────────────────────────────────────┤
  #     │ DATOS   cédula escolar · nacimiento · sexo              │
  #     └─────────────────────────────────────────────────────────┘
  #
  # ## ⚠️ Por qué no es `StudentsController#show`
  #
  # Esa es la ficha de la DIRECCIÓN: el boletín entero, los documentos
  # oficiales, los enlaces para editar a la familia y para emitir constancias.
  # Un profesor no necesita nada de eso, y varias de esas acciones no debería
  # poder ni verlas.
  #
  # Lo que sí necesita —y hasta hoy no tenía en ninguna pantalla— es **a quién
  # llamar**: el número de la mamá del niño que faltó tres días. Eso estaba
  # solo en la ficha de la dirección.
  #
  # ⚠️ «Cómo va» muestra las áreas que ESTE docente le dicta, no todas. La
  # excepción es el profesor GUÍA, que responde por el niño completo y es quien
  # atiende a la familia.
  def alumno
    @inscripcion = @enrollments.find { |i| i.id.to_s == params[:enrollment_id] }
    return redirect_to(alumnos_section_path(@section), alert: "Ese alumno no está en esta sección.") if @inscripcion.nil?

    @responsables = StudentRepresentative
                    .where(student_id: @inscripcion.student_id)
                    .includes(representative: :user)
                    .order(principal: :desc)

    @areas_del_alumno = areas_que_le_dicto
    @lapsos = EvaluationMoment.where(academic_period_id: @section.academic_period_id).order(:id).to_a
    @lapso  = @lapsos.find { |l| l.id.to_s == params[:lapso] } || lapso_en_curso(@lapsos) || @lapsos.first
    @calificaciones = calificaciones_del_alumno
    @faltas = Attendance.where(enrollment_id: @inscripcion.id)
    @dias_con_registro = @faltas.count
    @inasistencias = @faltas.faltas.count
  end

  # ⚠️ La asistencia DENTRO de la sección, no en otra pantalla.
  #
  # Es la misma planilla de `/asistencia/:seccion_id` —el parcial y la
  # preparación son compartidos (`PreparaLaAsistencia`)— para que las dos no se
  # separen: la de allá ordenaría por apellido y la de acá no, y nadie se
  # enteraría hasta que un profesor comparara las dos.
  def asistencia
    return redirect_to(section_path(@section), alert: "Solo el profesor guía toma asistencia.") unless puede_tomar_asistencia?

    preparar_la_asistencia(@section)
  end

  # Y el plan de evaluación, igual: mismo parcial, misma preparación
  # (`MuestraElPlan`). La diferencia con `/competencias` es que acá la sección y
  # el área ya vienen del árbol del menú, así que la escalera se reduce al lapso.
  # ⚠️ Se entra con el ÁREA, no con la asignación del profesor.
  #
  # Pedía `asignacion`, que sale de `current_user.teacher`, así que la dirección
  # rebotaba de la pestaña con «Elige primero un área» **teniendo el área
  # elegida**. El plan es de la sección; quién lo escribe es otra pregunta, y ya
  # la contesta `profesor?` en cada botón.
  def planificar
    # ⚠️ En Educación Inicial no hay nada que planificar: la calificación es un
    # texto y no se compone de evaluaciones con peso. La pestaña no se ofrece
    # (ver `pestanas_de_la_seccion`), pero la URL se puede escribir a mano o
    # quedar en un marcador, y esa pantalla le pediría a la maestra una
    # ponderación que no existe.
    return redirect_to(section_path(@section, area: area_del_plan&.id)) if @section.grade.califica_con_texto?

    return redirect_to(section_path(@section), alert: "Elija primero un área.") if area_del_plan.nil?

    @competencias = Competency.del_plan(@section.id, area_del_plan.id, lapso&.id)
                              .includes(:indicators, :evaluation_activities)
  end

  def new
    @section = Section.new
  end

  def edit; end

  # ⚠️ Dos puertas: el formulario completo (`/secciones/nueva`) y la ficha del
  # grado, que pregunta solo el identificador y el guía (Daniel, 13 de octubre
  # de 2026). Desde el grado se VUELVE al grado, que es donde se estaban
  # armando las secciones; el cupo sale propuesto (`Section::CUPO_PROPUESTO`).
  def create
    @section = Section.new(section_params)
    if @section.save
      registrar_cambio(:creado, @section, "#{@section.grade.name} – #{@section.name}")
      if desde_el_grado?
        redirect_to grade_path(@section.grade), notice: "Sección #{@section.name} agregada a #{@section.grade.name}."
      else
        redirect_to @section, notice: "Sección creada exitosamente."
      end
    elsif desde_el_grado?
      redirect_to grade_path(params[:grade_id]),
                  alert: "No se agregó la sección: #{@section.errors.full_messages.to_sentence}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @section.update(section_params)
      registrar_cambio(:actualizado, @section, "#{@section.grade.name} – #{@section.name}")
      redirect_to @section, notice: "Sección actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # El nombre, antes de borrar: después el objeto ya no puede
    # resolver sus asociaciones para armar el mensaje.
    nombre = "#{@section.grade.name} – #{@section.name}"

    if @section.destroy
      registrar_cambio(:eliminado, @section, nombre)
      redirect_to sections_url, notice: "Sección eliminada exitosamente."
    else
      redirect_to @section, alert: @section.errors.full_messages.join(", ")
    end
  end

  private

  # La libreta: todas las notas de esta sección en una tabla (MOR-223).
  #
  # Daniel: *«debería tener una vista en la que aparezcan todas las evaluaciones
  # y él pueda ir ajustando durante el lapso… una tabla donde la primera columna
  # es la lista de los estudiantes y las siguientes columnas son las
  # evaluaciones»*.
  #
  # ⚠️ Las áreas que se ofrecen son las que ESTA PERSONA califica, no las de la
  # sección. Daniel, ratificándolo con Cyndi: *«califica el profe de la materia.
  # Incluso el guía… ¿cómo sabes cuáles califica? guía + áreas asignadas»*.
  #
  # La dirección las ve todas: no califica, supervisa.
  # Lo que las dos pestañas de esta pantalla necesitan siempre: quiénes dictan
  # acá y quiénes están inscritos.
  # El libro con TODAS las secciones que se están viendo.
  #
  # ⚠️ Es de la DIRECCIÓN, y quien lo impide es `require_admin_access!` sobre
  # `index` —`administrador? && can_manage_sections?`—, no una guarda acá.
  # Escribí una por las dudas y era letra muerta: nunca llegaba a correr, y una
  # guarda que no dispara da la falsa impresión de ser LA protección el día que
  # alguien afloje el `before_action`.
  #
  # Al profesor le queda la de SU sección, en `alumnos`. Trescientos sesenta
  # alumnos con el teléfono de cada familia es otra cosa.
  def enviar_el_libro_del_colegio(scope)
    secciones = scope.order("grades.name, sections.name").to_a
    return redirect_to(sections_path, alert: "No hay secciones que listar.") if secciones.empty?

    enviar_la_lista(ListaDeAlumnosXlsx.new(secciones: secciones))
  end

  # `:xlsx` lo registra `config/initializers/mime_types.rb`.
  def enviar_la_lista(lista)
    send_data lista.to_stream.read, filename: lista.nombre_de_archivo, type: :xlsx
  end

  # Las áreas de las que este alumno es «mi alumno».
  #
  # ⚠️ El GUÍA las ve todas: es quien responde por el niño ante la familia, y
  # decirle «no puedes ver cómo va en Matemática» del muchacho que él atiende
  # sería un límite que no existe en el colegio. La dirección también, por
  # razones obvias.
  def areas_que_le_dicto
    return @section.grade.subjects.order(:name).to_a if can_manage_sections? || guia_de_la_seccion?

    @teacher_sections.select { |ts| ts.teacher.user_id == current_user.id }
                     .map(&:subject).uniq.sort_by(&:name)
  end

  def guia_de_la_seccion? = @section.leader_teacher&.user_id == current_user.id

  # Lo que el alumno tiene escrito en esas áreas, en el lapso elegido: un número
  # en primaria y bachillerato, un texto en Educación Inicial.
  def calificaciones_del_alumno
    return {} if @lapso.nil?

    MomentGrade.where(enrollment_id: @inscripcion.id, evaluation_moment_id: @lapso.id,
                      subject_id: @areas_del_alumno.map(&:id))
               .index_by(&:subject_id)
  end

  def cargar_la_seccion
    @teacher_sections = @section.teacher_sections.includes(teacher: :user, subject: {})
    @enrollments = Enrollment.en_orden_de_lista(@section.enrollments)

    return unless administrador?

    asignadas = @teacher_sections.pluck(:subject_id)
    @available_subjects = @section.grade.subjects.where.not(id: asignadas).order(:name)
    @available_teachers = Teacher.includes(:user).order("users.last_name")
  end

  # El área por la que entré, que es la que el árbol del menú trajo en la URL.
  # Es lo que decide qué libreta se abre y a qué plan lleva «Planificar».
  # ── Lo que `MuestraElPlan` y `PreparaLaAsistencia` necesitan ──────────────

  # La asignación de la que habla esta pantalla: esta sección, el área que trajo
  # el árbol del menú. ⚠️ Se busca entre las de ESTE profesor, y eso es lo que
  # autoriza: un área que no dicta no está en la lista y devuelve nil.
  # ⚠️ La asignación de ESTA sección, no la primera del profesor con esa área.
  #
  # Buscaba solo por materia, y `mis_asignaciones` son TODAS las del profesor
  # —eso es a propósito: las hermanas viven en otras secciones—. Un profesor de
  # Matemática en doce secciones recibía siempre la primera, 1er Grado A, mirara
  # la sección que mirara.
  #
  # Lo destapó Daniel preguntando dónde quedó el botón de copiar a la hermana:
  # en 6to Grado A —que no tiene hermana— la pantalla decía «la otra sección de
  # **1er Grado** ya tiene su plan», y en 2do Grado A lo mismo. El botón no
  # había desaparecido: estaba mirando el grado equivocado.
  #
  # Cuelgan de acá `otras_secciones`, `hermanas_sin_plan` y el plan del año
  # pasado, así que el error alcanzaba a todo lo que compara grados.
  def asignacion
    return @asignacion if defined?(@asignacion)

    @asignacion = mis_asignaciones.find do |ts|
      ts.section_id == @section&.id && ts.subject_id == area_de_la_pestana&.id
    end
  end
  helper_method :asignacion

  # ⚠️ Acá el plan se ve por la SECCIÓN que se abrió, no por lo que dicta quien
  # mira: la dirección no tiene asignaciones y estaba viendo el plan sin sus
  # evaluaciones, con la ponderación en 0 %.
  def seccion_del_plan = @section

  def area_del_plan = area_de_la_pestana

  # ⚠️ TODAS las del profesor, no solo las de esta sección.
  #
  # Estaba filtrando sobre `@teacher_sections` —las de la sección abierta— y
  # eso dejaba a `otras_secciones` y `hermanas_sin_plan` vacías: **la opción de
  # copiar el plan a las hermanas desapareció de la pestaña sin que nada
  # fallara**. Las hermanas son, por definición, de OTRA sección.
  #
  # Lo destapó un test que contaba el formulario de copiar, no la pantalla.
  def mis_asignaciones
    @mis_asignaciones ||= current_user.teacher&.teacher_sections
                                      &.del_anio_de_la_sesion
                                      &.includes(section: :grade, subject: {})&.to_a || []
  end
  helper_method :mis_asignaciones

  def desde_donde = "seccion"

  # Los formularios del plan vuelven a la pestaña, no a `/competencias`.
  def plan_path
    planificar_section_path(@section, area: area_de_la_pestana&.id, lapso: lapso&.id)
  end
  helper_method :plan_path

  # Quién puede pasar lista: el guía de la sección, o la dirección.
  def puede_tomar_asistencia?
    can_manage_sections? || @section.leader_teacher_id == current_user.teacher&.id
  end

  # ⚠️ Cae en la PRIMERA que califico cuando la URL no la trae.
  #
  # Entrando por «Soy guía de» el enlace va sin área —la asistencia es de la
  # sección entera, sin área— y ahí «Planificar» rebotaba con «Elige primero un
  # área» mientras la libreta de al lado mostraba Matemática tan campante: las
  # dos deducían distinto.
  #
  # Es «no preguntemos lo deducible»: en una sección donde dicto una sola área
  # no hay nada que elegir, y donde dicto dos la primera es tan buena como
  # pedirla — las pestañas la llevan de ahí en adelante.
  def area_de_la_pestana
    return @area_de_la_pestana if defined?(@area_de_la_pestana)

    @area_de_la_pestana = areas_que_califico.find { |s| s.id.to_s == params[:area] } ||
                          areas_que_califico.first
  end
  helper_method :area_de_la_pestana

  def preparar_las_valoraciones
    @lapsos_de_la_libreta = EvaluationMoment.where(academic_period_id: @section.academic_period_id).order(:id)
    @lapso_de_la_libreta = @lapsos_de_la_libreta.find { |l| l.id.to_s == params[:lapso] } || lapso_en_curso || @lapsos_de_la_libreta.first
    @valoraciones = ValoracionesDeLaSeccion.para(seccion: @section, lapso: @lapso_de_la_libreta)
  end

  def preparar_la_libreta
    @areas_que_califico = areas_que_califico
    return if @areas_que_califico.empty?

    @lapsos_de_la_libreta = EvaluationMoment
                            .where(academic_period_id: @section.academic_period_id)
                            .order(:starts_on, :id).to_a
    # ⚠️ La MISMA que las pestañas, no una deducción paralela: cuando eran dos,
    # la libreta abría en Matemática y «Planificar» decía que faltaba elegir.
    @area_de_la_libreta = area_de_la_pestana
    @lapso_de_la_libreta = @lapsos_de_la_libreta.find { |l| l.id.to_s == params[:lapso] } ||
                           lapso_en_curso || @lapsos_de_la_libreta.first
    return if @lapso_de_la_libreta.nil?

    @libreta = LibretaDeLaSeccion.para(seccion: @section, materia: @area_de_la_libreta,
                                       lapso: @lapso_de_la_libreta)
  end

  def areas_que_califico
    return @section.grade.subjects.order(:name).to_a if can_manage_sections?
    return [] unless profesor?

    @teacher_sections.select { |ts| ts.teacher_id == current_user.teacher&.id }
                     .map(&:subject).uniq.sort_by(&:name)
  end

  # ⚠️ El lapso que se está cursando, no el primero.
  #
  # Es la misma trampa que `AcademicPeriod.en_operacion` para el año escolar,
  # cuarta o quinta aparición: abrir en el primero es abrirle a un profesor de
  # marzo la libreta de octubre, que ya cerró.
  # ⚠️ Recibe la lista, y por defecto la de la libreta. La ficha del alumno tiene
  # la suya (`@lapsos`) y sin el argumento leía una variable que ahí es `nil`.
  def lapso_en_curso(lapsos = @lapsos_de_la_libreta)
    hoy = Date.current
    lapsos.to_a.find { |l| l.starts_on && l.ends_on && (l.starts_on..l.ends_on).cover?(hoy) }
  end

  def set_section
    @section = Section.find(params[:id])
  end

  # ⚠️ El año escolar NO viaja en el formulario cuando se puede deducir (MOR-165).
  #
  # Al crear sale de la sesión; al editar no se toca, porque mover una sección de
  # año arrastraría inscripciones, asistencia y notas que son de ese año.
  # El único caso en que se acepta del request es cuando la sesión mira «Todos
  # los años» y no hay nada que deducir — y ahí lo valida el `belongs_to` contra
  # el `default_scope`, no un `if`.
  def section_params
    permitidos = params.require(:section).permit(:name, :grade_id, :capacity, :classroom, :leader_teacher_id)
    return permitidos if @section&.persisted?

    # Desde la ficha del grado, el grado es el de la URL.
    permitidos = permitidos.merge(grade_id: params[:grade_id]) if desde_el_grado?
    permitidos.merge(academic_period_id: Current.academic_period_id ||
                                         params[:section][:academic_period_id])
  end

  def desde_el_grado? = params[:grade_id].present?

  def require_admin_access!
    unless administrador? && can_manage_sections?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end

  # Profesores pueden ver sus propias secciones; admins pueden ver cualquiera
  def require_read_access!
    if administrador?
      # ok
    elsif profesor?
      section = Section.find(params[:id])
      unless current_user.teacher.sections.include?(section)
        redirect_to dashboard_path_for_user, alert: "No tiene acceso a esta sección."
      end
    else
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado."
    end
  end
end
