# Traer los datos de un colegio desde una planilla (MOR-126).
#
# Es la respuesta a la objeción que aparece en la primera conversación con
# cualquier colegio que ya tiene sistema: *"¿y lo que ya tengo?"*. Sin esto, el
# onboarding solo sirve para un colegio que arranca de cero, y ese no es el
# mercado.
#
# El recorrido son cuatro pantallas y cada una tiene que poder abandonarse sin
# dejar nada a medias:
#
#     new/create   subir el archivo
#     show         ver el mapeo propuesto y corregirlo
#     update       guardarlo  →  previsualizar
#     confirmar    escribir
#
# ## Dos planillas, un recorrido
#
# `tipo` decide qué se espera y qué se crea; el lector, el mapeo, la
# previsualización y el reporte son los mismos. Lo que cambia se resuelve en
# `#interpretada` y `#escribir`, y en ningún otro lado:
#
#     matricula   alumnos y representantes  →  MatriculaInterpretada · CargaDeMatricula
#     pensum      materias y profesores     →  PensumInterpretado    · CargaDePensum
class ImportacionesController < ApplicationController
  before_action :require_puede_gestionar!
  before_action :set_importacion,
                only: [ :show, :update, :destroy, :previsualizar,
                        :crear_seccion, :crear_grado, :crear_periodo, :resultado ]

  def index
    @pagy, @importaciones = pagy(Importacion.includes(:subido_por).recientes)
  end

  # La planilla en blanco, con su hoja de instrucciones. Se descarga ANTES de
  # que exista ninguna importación, así que no cuelga de ninguna.
  def plantilla
    hoja = tipo_pedido == "pensum" ? PlantillaDePensum : PlantillaDeMatricula
    hoja = hoja.new(colegio: Current.school)

    send_data hoja.to_stream.read,
              filename: hoja.nombre_de_archivo,
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def new
    @importacion = Importacion.new(tipo: tipo_pedido)
  end

  # ⚠️ El archivo se LEE antes de guardar nada, y del que acaba de llegar.
  #
  # Dos razones, y la segunda me costó dos intentos:
  #
  # 1. Una planilla que no se puede abrir, o sin fila de encabezados, no debería
  #    quedar registrada como una importación en curso: la secretaria vería una
  #    fila rota en el listado sin saber qué hacer con ella. Leyendo primero, se
  #    rechaza con el archivo todavía en su computadora y sin dejar rastro.
  #
  # 2. Leerlo de vuelta desde Active Storage en la MISMA petición no funciona.
  #    `attach` no sube el archivo en el momento —apunta el cambio y lo aplica
  #    después—, así que `archivo.open` daba `ActiveStorage::FileNotFoundError`:
  #    la fila existía y el archivo todavía no. Y no hacía falta bajarlo: lo
  #    tenemos en la mano.
  def create
    archivo = params.dig(:importacion, :archivo)
    return rechazar("Elija una planilla para subir.") if archivo.blank?

    hoja = Planilla.new(archivo.tempfile.path, extension: File.extname(archivo.original_filename))

    @importacion = Importacion.new(
      school: Current.school, subido_por: current_user,
      nombre_del_archivo: archivo.original_filename,
      filas_leidas: hoja.filas.size,
      tipo: tipo_pedido
    )

    return rechazar(@importacion.errors.full_messages.to_sentence) unless @importacion.save

    @importacion.archivo.attach(archivo)

    redirect_to @importacion, notice: "Planilla cargada. Revise cómo quedaron las columnas."
  rescue Planilla::NoSePuedeLeer => e
    rechazar(e.message)
  end

  def show
    @columnas = @importacion.columnas::TODAS
    @mapeo = @importacion.mapeo_efectivo
    @muestra = @importacion.planilla.filas.first
  rescue Planilla::NoSePuedeLeer => e
    redirect_to importaciones_path, alert: e.message
  end

  # Dos cosas por el mismo verbo, y la diferencia la marca `confirmar`:
  # guardar el mapeo, o escribir la matrícula.
  def update
    return confirmar if params[:confirmar].present?
    return cambiar_tipo if params[:cambiar_tipo].present?

    @importacion.mapeo = mapeo_desde_el_formulario
    @importacion.estado = :mapeada if @importacion.lista_para_previsualizar?

    return redirect_to(@importacion, alert: @importacion.errors.full_messages.to_sentence) unless @importacion.save

    # ⚠️ El botón dice «Guardar y continuar», así que tiene que continuar.
    #
    # Antes redirigía siempre a esta misma pantalla con un «Mapeo guardado» y
    # nada más. Con el mapeo completo eso es un callejón: la persona ve que algo
    # pasó, no ve a dónde, y vuelve a apretar el mismo botón.
    #
    # Si falta una columna sí se queda acá, porque acá es donde se arregla.
    if @importacion.lista_para_previsualizar?
      redirect_to previsualizar_importacion_path(@importacion)
    else
      redirect_to @importacion, alert: "Falta decir dónde están algunas columnas."
    end
  end

  # Qué se va a cargar y qué no, ANTES de escribir nada. Es el paso que hace
  # que un import salga bien a la primera en vez de descubrirse roto después.
  def previsualizar
    return redirect_to(@importacion, alert: "Falta decir dónde están algunas columnas.") unless @importacion.lista_para_previsualizar?

    # Cambiar el año escolar desde la propia previsualización: es donde se ve
    # que las secciones no cuadran, así que es donde hay que poder corregirlo.
    @importacion.update!(academic_period_id: params[:periodo_id]) if params[:periodo_id].present?

    @periodos = AcademicPeriod.order(start_date: :desc)
    @planilla = interpretada
  rescue Planilla::NoSePuedeLeer => e
    redirect_to importaciones_path, alert: e.message
  end

  # ⚠️ Crear la sección desde acá, y no mandando a la persona a otra pantalla.
  #
  # Ni se crean solas —un dedazo en la planilla dejaría una sección «1er Año Á»
  # para siempre— ni se rechaza la fila y listo, que obligaría a salir, crear a
  # mano y volver a empezar. Se muestra qué falta, con cuántos alumnos la
  # esperan, y se crea de un clic.
  def crear_seccion
    grado = Grade.find(params[:grade_id])

    # ⚠️ En el año escolar de ESTA importación, no en el «vigente».
    #
    # Con `vigente` a secas, un colegio que sube la matrícula del año que acaba
    # de terminar terminaba con los alumnos de las secciones existentes en un
    # año y los de las secciones nuevas en el siguiente.
    periodo = @importacion.periodo

    return redirect_to(previsualizar_importacion_path(@importacion), alert: "El colegio no tiene ningún año escolar cargado.") if periodo.nil?

    # ⚠️ El conteo de la planilla es capacidad solo en una matrícula.
    #
    # En un pensum ese número son MATERIAS, y usarlo daría un aula para ocho
    # personas. Ahí no hay de dónde deducir la capacidad, así que va la de por
    # defecto y el colegio la corrige si hace falta.
    esperados = @importacion.matricula? ? params[:cuantas].to_i : 0

    seccion = Section.new(grade: grado, academic_period: periodo,
                          name: params[:nombre].to_s.strip.upcase,
                          capacity: [ esperados, 30 ].max)

    if seccion.save
      redirect_to previsualizar_importacion_path(@importacion),
                  notice: "Se creó #{grado.name} #{seccion.name}."
    else
      redirect_to previsualizar_importacion_path(@importacion),
                  alert: seccion.errors.full_messages.to_sentence
    end
  end

  # ⚠️ Crear el GRADO, no solo la sección — y es el caso que faltaba.
  #
  # `crear_seccion` sirve cuando el grado existe. Cuando no existe ninguno que se
  # parezca, la pantalla mandaba a la persona a Configuración a crearlo a mano y
  # volver a empezar: el único callejón que quedaba en todo el recorrido.
  #
  # Se crean los DOS de un golpe, porque quien llega acá está tratando de
  # resolver una sección: crear el grado y dejarlo sin secciones lo dejaría a
  # mitad de camino, mirando la misma pantalla con otro mensaje.
  def crear_grado
    periodo = @importacion.periodo
    return redirect_to(previsualizar_importacion_path(@importacion), alert: "El colegio no tiene ningún año escolar cargado.") if periodo.nil?

    grado = Grade.new(school: Current.school,
                      name: params[:grado].to_s.strip,
                      level: params[:nivel])

    return redirect_to(previsualizar_importacion_path(@importacion), alert: grado.errors.full_messages.to_sentence) unless grado.save

    seccion = crear_la_seccion(grado, periodo)

    redirect_to previsualizar_importacion_path(@importacion),
                notice: "Se creó #{grado.name}#{" #{seccion.name}" if seccion&.persisted?}."
  end

  # El reporte de lo que pasó. Se lee de `resultado`, que quedó guardado al
  # confirmar: el archivo puede cambiar después y el reporte tiene que seguir
  # describiendo lo que de verdad ocurrió.
  def resultado
    return redirect_to(@importacion, alert: "Esta importación todavía no se ha cargado.") unless @importacion.confirmada?

    @resultado = @importacion.resultado
  end

  # ⚠️ Un colegio recién dado de alta nace SIN ningún año escolar, y sin él no
  # se puede crear una sección —`Section` pertenece a uno— así que el importador
  # rechaza todas las filas y el botón de crear sección tampoco funciona.
  #
  # La salida se ofrece acá, donde el problema se ve, en vez de mandar a la
  # persona a Configuración a buscar algo que todavía no sabe que le falta. El
  # alta guiada de un colegio nuevo es otra cosa y va aparte.
  def crear_periodo
    periodo = AcademicPeriod.new(school: Current.school,
                                 name: params[:nombre].to_s.strip,
                                 start_date: params[:desde], end_date: params[:hasta])

    if periodo.save
      @importacion.update(academic_period: periodo)
      redirect_to previsualizar_importacion_path(@importacion),
                  notice: "Se creó el año escolar #{periodo.name}."
    else
      redirect_to previsualizar_importacion_path(@importacion),
                  alert: periodo.errors.full_messages.to_sentence
    end
  end

  def destroy
    @importacion.archivo.purge_later
    @importacion.update(estado: :descartada)

    redirect_to importaciones_path, notice: "Importación descartada."
  end

  private

  # ⚠️ Conservando el TIPO, que es lo que se estaba subiendo.
  #
  # `Planilla.new` revienta ANTES de que exista `@importacion`, así que acá se
  # armaba una nueva con el tipo por defecto: alguien subía un pensum, el archivo
  # fallaba, y el formulario volvía a decir «Subir matrícula de alumnos» con la
  # URL todavía en `?tipo=pensum`. Reintentando desde ahí, el pensum entraba como
  # matrícula.
  # La sección del grado recién creado. Devuelve `nil` si la planilla no nombraba
  # ninguna —«5to Año» a secas es un grado sin sección, y es válido—.
  def crear_la_seccion(grado, periodo)
    nombre = params[:seccion].to_s.strip.upcase
    return nil if nombre.blank?

    Section.create(grade: grado, academic_period: periodo, name: nombre,
                   capacity: [ (@importacion.matricula? ? params[:cuantas].to_i : 0), 30 ].max)
  end

  def rechazar(mensaje)
    @importacion ||= Importacion.new(tipo: tipo_pedido)
    flash.now[:alert] = mensaje
    render :new, status: :unprocessable_entity
  end

  # El formulario manda `{ "APELLIDOS Y NOMBRES" => "nombre_completo" }`. Las
  # que la persona dejó en "no importar" llegan vacías y se descartan: guardar
  # `=> ""` haría que `mapeo_efectivo` las contara como mapeadas a nada.
  def mapeo_desde_el_formulario
    params.fetch(:mapeo, {}).permit!.to_h.compact_blank
  end

  # Subió la planilla en el lugar equivocado — son dos botones al lado— y el
  # sistema se dio cuenta. Cambiar el tipo sin volver a subir nada.
  #
  # ⚠️ El mapeo guardado se BORRA: apunta a las columnas del tipo anterior, y
  # conservarlo dejaría «APELLIDOS Y NOMBRES» apuntando al profesor en una
  # planilla de alumnos.
  def cambiar_tipo
    @importacion.update!(tipo: @importacion.otro_tipo, mapeo: {}, estado: :cargada)

    redirect_to @importacion,
                notice: "Ahora se lee como #{@importacion.etiqueta_de_tipo.downcase}."
  end

  # ⚠️ Se vuelve a interpretar la planilla acá, en vez de confiar en lo que se
  # mostró en la pantalla anterior.
  #
  # Entre que alguien miró la previsualización y apretó el botón pudo pasar de
  # todo: crearon una sección desde otra pestaña, otro usuario cargó un alumno,
  # pasaron veinte minutos. Escribir contra una foto vieja es cómo se cargan
  # datos que ya no corresponden.
  def confirmar
    if @importacion.confirmada?
      return redirect_to resultado_importacion_path(@importacion),
                         alert: "Esta importación ya se cargó."
    end

    planilla = interpretada
    return redirect_to(previsualizar_importacion_path(@importacion), alert: "Todavía hay secciones que no existen.") if planilla.secciones_que_faltan.any?

    resultado = escribir(planilla)
    @importacion.update!(estado: :confirmada, resultado: resultado.to_h_para_guardar)

    log_activity(action: "#{@importacion.tipo}_importada",
                 message: "#{current_user.nombre_completo} importó #{resumen(resultado)} desde #{@importacion.nombre_del_archivo}",
                 subject: @importacion)

    redirect_to resultado_importacion_path(@importacion),
                notice: "Se cargaron #{resumen(resultado)}."
  rescue Planilla::NoSePuedeLeer => e
    redirect_to importaciones_path, alert: e.message
  end

  def interpretada
    clase = @importacion.pensum? ? PensumInterpretado : MatriculaInterpretada

    clase.new(planilla: @importacion.planilla,
              mapeo: @importacion.mapeo_efectivo,
              colegio: Current.school,
              periodo: @importacion.periodo)
  end

  def escribir(planilla)
    if @importacion.pensum?
      CargaDePensum.new(pensum: planilla, colegio: Current.school).ejecutar
    else
      CargaDeMatricula.new(matricula: planilla, colegio: Current.school).ejecutar
    end
  end

  # Qué contar al terminar. Un import de matrícula se mide en alumnos y uno de
  # pensum en asignaciones: «12 materias» no dice nada si son las mismas cuatro
  # repartidas en tres secciones.
  def resumen(resultado)
    if @importacion.pensum?
      helpers.pluralize(resultado.asignaciones, "materia asignada", plural: "materias asignadas")
    else
      helpers.pluralize(resultado.total_cargado, "alumno")
    end
  end

  # El tipo llega por la URL al abrir el formulario (`?tipo=pensum`) y por el
  # campo oculto al enviarlo. Cualquier cosa que no sea un tipo conocido es
  # matrícula: es lo que un colegio sube primero, y lo que sube siempre.
  def tipo_pedido
    pedido = params[:tipo].presence || params.dig(:importacion, :tipo)

    Importacion.tipos.key?(pedido) ? pedido : "matricula"
  end

  def set_importacion
    @importacion = Importacion.find(params[:id])
  end

  def require_puede_gestionar!
    return if can_manage_students?

    redirect_to dashboard_path_for_user, alert: "No tienes permiso para importar datos."
  end
end
