# La puesta en marcha de un colegio, deducida del estado (MOR-154).
#
# ## ⚠️ No hay una sola bandera acá, y es la decisión que sostiene todo
#
# Lo natural sería una columna `pasos_completados` o un `wizard_step`. Se rompe
# el primer día: la secretaria entra por el menú a Materias, carga las
# veintidós, y el tablero sigue diciendo «paso 4, pendiente». Peor todavía —se
# rompe **en silencio**, y quien lo ve concluye que el sistema no se entera de
# lo que hace.
#
# Este proyecto ya tomó esta decisión una vez y la dejó escrita: `AcademicPeriod`
# no tiene bandera `activo` porque *«una bandera se queda vieja el día que nadie
# se acuerda de moverla — justo el día que la pantalla la muestra»*.
#
# Acá el estado ES la base de datos. De ahí salen tres cosas gratis:
#
#   1. Retomar después de días no existe como problema: no hay nada guardado
#      que retomar. Abrir el panel el jueves muestra la verdad del jueves.
#   2. Da igual por qué puerta entró: importador, menú, formulario a mano o
#      seeds. El paso se pone en verde solo.
#   3. Borrar la única sección devuelve el paso a pendiente, que es correcto.
#
# ## La única cosa que sí se guarda
#
# «No aplica». Que un colegio no use departamentos no se deduce de que no tenga
# ninguno — se ve idéntico a «todavía no los cargué». Eso vive en
# `school.pasos_omitidos`, y conviene que sea lo único: cada cosa que se guarde
# acá es una que se puede quedar vieja.
class PasosDeArranque
  # `contar` ya vive en `ApplicationHelper` y resuelve el plural en español
  # —«secciónes» con tilde fue un bug real—. Se incluye en vez de copiarse: dos
  # copias del mismo plural son dos lugares donde volver a equivocarse.
  include ApplicationHelper
  # `listo?` no se guarda: es una pregunta contra los datos, evaluada cada vez.
  # `vacio` es el titular del estado vacío de la pantalla correspondiente. Va
  # acá y no en cada vista para que la pantalla y el mapa digan lo MISMO: si el
  # paso se renombra, el estado vacío lo sigue.
  # `pendiente` es lo que FALTA aunque el paso esté listo (MOR-208).
  #
  # Daniel: *«podemos indicarle en algún lugar del panel que deben completar la
  # firma, el logo y la dirección de la escuela para que los documentos salgan
  # con esa info, pero que lo pueden hacer luego»*.
  #
  # ⚠️ No es un paso aparte ni convierte el paso en pendiente, y eso es todo el
  # punto: el colegio PUEDE trabajar sin logo y sin firma. Volverlo obligatorio
  # sería mentirle; callarlo, dejar que se entere el día que emita su primera
  # constancia y salga sin escudo.
  Paso = Data.define(:clave, :titulo, :explicacion, :verbo, :ruta, :icono, :vacio,
                     :listo, :resultado, :pendiente, :necesita, :opcional, :omitido) do
    def initialize(clave:, titulo:, explicacion:, verbo:, ruta:, icono:, vacio: nil,
                   listo: false, resultado: nil, pendiente: nil, necesita: nil,
                   opcional: false, omitido: false)
      super
    end

    def listo? = listo
    def opcional? = opcional
    def omitido? = omitido
    def bloqueado? = !listo && necesita.present?

    # Cuatro estados, y el orden de las preguntas importa: un paso omitido ya no
    # es opcional-pendiente, y uno listo ya no está bloqueado.
    def estado
      return :listo if listo?
      return :omitido if omitido?
      return :bloqueado if bloqueado?

      opcional? ? :opcional : :pendiente
    end
  end

  ETIQUETAS_DE_ESTADO = {
    listo: "Listo", pendiente: "Pendiente", bloqueado: "Falta algo antes",
    opcional: "Opcional", omitido: "Omitido"
  }.freeze

  def self.para(colegio) = new(colegio).pasos

  # El paso que corresponde a una pantalla. Es lo que permite que el estado
  # vacío de `/subjects` diga lo mismo que el mapa del panel sin repetirlo.
  def self.paso(colegio, clave) = para(colegio).find { |p| p.clave == clave.to_sym }

  def initialize(colegio)
    @colegio = colegio
  end

  # ¿Sigue en la puesta en marcha? Cuando lo obligatorio está listo, el tablero
  # desaparece solo: un colegio ya configurado no lo ve nunca.
  def self.en_marcha?(colegio)
    para(colegio).any? { |p| !p.listo? && !p.opcional? }
  end

  def pasos
    # ⚠️ El orden separa lo que es DEL COLEGIO de lo que es DEL AÑO (MOR-197).
    #
    # Daniel, sobre el orden: *«el año escolar debe ir después de materias. El
    # orden es: después de los grados, departamentos, materias y profesores, año
    # escolar, secciones y matrícula»*.
    #
    #     DEL COLEGIO — se cargan una vez        DEL AÑO — se rehacen cada año
    #     ───────────────────────────────        ────────────────────────────
    #     los grados que dicta                   el año escolar y sus lapsos
    #     su identidad (DEA, dirección)          las secciones de cada grado
    #     los departamentos                      la matrícula
    #     las materias y los profesores
    #
    # El año escolar estaba tercero y arrastraba la confusión: hacía parecer que
    # las materias y los profesores eran de ese año, cuando cuelgan del colegio
    # y sobreviven a todos. Lo que sí es del año son las secciones —por eso van
    # después— y la matrícula.
    #
    # Lo que se conserva de la versión anterior:
    #
    # - `departamentos` antes de `materias`. Daniel: «primero deberían estar
    #   creados los departamentos (si los hubiera) y luego se agregan las
    #   materias». Es opcional —un colegio chico no los tiene— pero el que SÍ
    #   los quiere necesita crearlos antes: una materia se agrupa al crearla, y
    #   volver a editar cuarenta después es trabajo que el orden evita.
    #
    # ⚠️ Lo que se PIERDE, y hay que tenerlo presente: `secciones` estaba antes
    # de `materias` porque `CargaDePensum` usa la sección de cada fila. Ya no lo
    # está, así que quien suba el pensum antes de armar las secciones va a verlas
    # listadas como faltantes. No es un callejón —la previsualización ofrece
    # crearlas de un clic, con su conteo— pero es un paso más que antes no había.
    [ niveles, identidad, departamentos, materias, ano_escolar, secciones, alumnos, historial ]
  end

  private

  attr_reader :colegio

  # ⚠️ El paso 1 es el corazón del arranque: tres casillas en vez de catorce
  # formularios. Ver `SembrarGrados`.
  def niveles
    cargados = Grade.count

    Paso.new(
      clave: :niveles, vacio: "Este colegio todavía no tiene grados cargados", icono: :grados,
      titulo: "Qué niveles dicta el colegio",
      explicacion: "Los grados de Venezuela los fija el ministerio: son catorce y " \
                   "siempre los mismos. Marque los niveles que dicta y quedan creados de una vez.",
      verbo: "Elegir los niveles", ruta: :niveles_del_colegio,
      listo: cargados.positive?,
      resultado: cargados.positive? ? "#{nombres_de_niveles} · #{contar(cargados, 'grado', 'grados')}" : nil
    )
  end

  def identidad
    listo = colegio.dea_code.present?

    Paso.new(
      clave: :identidad, vacio: "Falta la identidad del colegio", icono: :colegio,
      titulo: "La identidad del colegio",
      explicacion: "El código DEA, el escudo y la firma del director. Salen impresos en " \
                   "cada boletín y en cada constancia, así que conviene dejarlos listos " \
                   "antes de que haga falta el primero.",
      verbo: "Completar la identidad", ruta: :colegio,
      listo: listo,
      resultado: listo ? "DEA #{colegio.dea_code}" : nil,
      pendiente: (lo_que_falta_para_los_documentos if listo)
    )
  end

  # Lo que un documento va a echar de menos si nadie lo carga.
  #
  # ⚠️ Se nombra POR SU CONSECUENCIA y no como una lista de campos vacíos: a un
  # director no le importa que `firma` sea nil, le importa que la constancia
  # salga sin firmar.
  def lo_que_falta_para_los_documentos
    falta = []
    falta << "el escudo" unless colegio.logo.attached?
    falta << "la firma del director" unless colegio.firma.attached?
    falta << "la dirección" if colegio.direccion.blank?
    return nil if falta.empty?

    "Sus boletines y constancias van a salir sin #{falta.to_sentence}. " \
    "Puede cargarlos cuando quiera."
  end

  # ⚠️ Los lapsos van JUNTO con el año, no aparte.
  #
  # Sin lapsos no se puede crear una evaluación, así que un colegio que termina
  # el arranque sin ellos recibió un tablero que le mintió: dice «listo» y no
  # puede calificar.
  def ano_escolar
    periodo = AcademicPeriod.order(start_date: :desc).first
    lapsos = periodo ? EvaluationMoment.where(academic_period_id: periodo.id).count : 0

    Paso.new(
      clave: :ano_escolar, vacio: "Este colegio todavía no tiene ningún año escolar", icono: :calendario,
      titulo: "El año escolar y sus lapsos",
      explicacion: "El lapso es cada corte de notas del año: lo que en la libreta va " \
                   "como I, II y III Lapso. Casi todos los colegios del país usan tres.",
      # ⚠️ El destino cambia con el estado, y el botón lo decía sin cumplirlo:
      # «Revisar los lapsos» llevaba al listado de AÑOS ESCOLARES. Si el año ya
      # existe, lo que falta mirar son sus lapsos.
      # ⚠️ «Agregar» y directo al ALTA cuando no existe (MOR-205).
      #
      # Daniel: *«en el caso de las entidades que no tengan import, como
      # departamento, el botón debería redirigir directo a new, no a index. Igual
      # año escolar»*. Mandar al listado de un colegio que no tiene ninguno es
      # mandar a un estado vacío para que desde ahí toque otro botón.
      #
      # Y el verbo es «Agregar», el mismo que en la cabecera de todos los
      # listados: *«en esos casos debería ser Agregar en lugar de Crear, para
      # mantener consistencia»*.
      verbo: periodo ? "Revisar los lapsos" : "Agregar el año escolar",
      ruta: periodo ? :evaluation_moments : :academic_period_nuevo,
      listo: periodo.present? && lapsos.positive?,
      resultado: periodo && lapsos.positive? ? "#{periodo.name} · #{contar(lapsos, 'lapso', 'lapsos')}" : nil
    )
  end

  # ⚠️ UN paso, no dos, y el QA de Daniel lo señaló: «en el plan separas en dos
  # pasos la importación de materias y la de profesores, y en el importador
  # están juntas. Allí hay un choque».
  #
  # El choque era real y el importador tiene razón: **una planilla de pensum es
  # exactamente eso** —qué materias hay, y quién dicta cada una en cada
  # sección—. `CargaDePensum` crea `Subject`, `GradeSubject`, `Teacher` y
  # `TeacherSection` de una sola pasada. Con dos pasos en el plan, subir el
  # pensum ponía dos en verde a la vez y el segundo mandaba a una pantalla que ya
  # estaba hecha.
  #
  # Cargar a mano sigue siendo dos pantallas, y por eso el paso enlaza a las dos.
  def materias
    materias_cargadas = Subject.count
    profesores_cargados = Teacher.count

    Paso.new(
      clave: :materias, vacio: "Todavía no hay materias cargadas", icono: :materias,
      titulo: "Las materias y quién las dicta",
      # ⚠️ El paso CAMBIA DE TEXTO según lo que ya haya (MOR-208).
      #
      # Daniel: *«ya las materias están cargadas; en todo caso queda es
      # cambiarlas»*. Y tenía razón: desde que el pensum se siembra al
      # registrarse, un colegio abre el panel con diecisiete materias puestas y
      # lee «Cargar las materias». El paso le pedía algo que el sistema ya hizo.
      #
      # Lo que de verdad falta en ese momento es la otra mitad —quién las
      # dicta—, así que el paso lo dice y lleva a los profesores.
      explicacion: explicacion_del_pensum(materias_cargadas, profesores_cargados),
      verbo: materias_cargadas.positive? ? "Cargar los profesores" : "Cargar las materias",
      ruta: materias_cargadas.positive? ? :teachers : :subjects,
      # Las dos mitades: una materia sin nadie que la dicte no deja cargar una
      # nota, así que el paso no está hecho hasta que hay quien la dé.
      listo: materias_cargadas.positive? && profesores_cargados.positive?,
      resultado: resultado_del_pensum(materias_cargadas, profesores_cargados)
    )
  end

  # Qué contarle a un colegio según lo que ya tiene.
  #
  # ⚠️ Son tres situaciones distintas y con dos textos no alcanzaba: el pensum
  # sembrado, el pensum a medias y el colegio en blanco no necesitan que se les
  # diga lo mismo.
  def explicacion_del_pensum(materias, profesores)
    if materias.positive? && profesores.zero?
      "Sus materias ya están, con el plan de estudio del ministerio repartido por año. " \
      "Falta la otra mitad: quién dicta cada una. Si tiene el pensum en un Excel, súbalo " \
      "y salen los profesores y sus asignaciones de una vez."
    elsif materias.positive?
      "Las materias y los profesores ya están. Revise que cada sección tenga quién le dicte: " \
      "una materia sin profesor no deja cargar una nota."
    else
      "Si ya tiene el pensum en un Excel, súbalo: de una sola planilla salen las materias, " \
      "los profesores y quién dicta qué en cada sección. El código (MAT, CAS, FIS) es suyo: " \
      "si la planilla no lo trae, SIGA propone uno y usted lo corrige."
    end
  end

  # «8 materias · 12 profesores», o solo la mitad que ya está — que es lo que
  # dice qué falta sin tener que abrir la pantalla.
  def resultado_del_pensum(materias, profesores)
    partes = []
    partes << contar(materias, "materia", "materias") if materias.positive?
    partes << contar(profesores, "profesor", "profesores") if profesores.positive?

    partes.join(" · ").presence
  end

  # ⚠️ El paso bloqueado NO lleva su botón apagado: lleva OTRO botón, que va a
  # lo que lo desbloquea. Un control deshabilitado es una pregunta sin respuesta,
  # y quien navega con teclado ni siquiera lo puede enfocar para averiguar.
  def secciones
    cargadas = Section.count
    falta = if !Grade.exists? then :niveles
            elsif !AcademicPeriod.exists? then :ano_escolar
            end

    Paso.new(
      clave: :secciones, vacio: "Todavía no hay secciones", icono: :secciones,
      titulo: "Las secciones de cada grado",
      explicacion: "Cuántas secciones tiene cada grado. Se llaman A, B, C — no lo manda " \
                   "ningún reglamento, pero es lo que hace todo el mundo, así que SIGA se " \
                   "lo propone.",
      verbo: "Armar las secciones", ruta: :sections,
      listo: cargadas.positive?, necesita: falta,
      resultado: cargadas.positive? ? contar(cargadas, "sección", "secciones") : nil
    )
  end

  def alumnos
    cargados = Student.count

    Paso.new(
      clave: :alumnos, vacio: "Todavía no hay alumnos", icono: :alumnos,
      titulo: "La matrícula",
      explicacion: "Nadie va a tipear trescientos sesenta alumnos. Suba la planilla que " \
                   "ya tiene —el Excel, la nómina, lo que use— y antes de escribir nada " \
                   "le mostramos qué entendió.",
      # ⚠️ Directo al ALTA de la planilla que corresponde, no al importador
      # general (QA de Daniel: *«enlace directo a importar matrícula, no al
      # import general, confunde»*).
      #
      # Llevaba a `/importaciones`, que es la BITÁCORA de lo importado más tres
      # botones. O sea que el paso «La matrícula» desembocaba en una pantalla
      # que vuelve a preguntar cuál de las tres planillas es, cuando el paso ya
      # lo dijo. El nombre lo pone `Importacion::ACCIONES`, como el resto.
      verbo: Importacion.accion_de(:matricula), ruta: :importar_matricula,
      # ⚠️ NO se bloquea por las secciones, y antes sí (MOR-198).
      #
      # Daniel: *«en matrícula no me está dando la opción de importar»*. Y no se
      # la daba: sin secciones, el paso mostraba «Antes hace falta las secciones
      # de cada grado» y cambiaba su botón por «Armar las secciones».
      #
      # Está mal porque el importador ES la manera de resolverlo: la
      # previsualización LISTA las secciones que faltan, con cuántas filas
      # esperan cada una, y las crea de un clic (`ImportacionesController
      # #crear_seccion`). Bloquear acá escondía exactamente la herramienta que
      # soluciona el bloqueo, y mandaba a armar a mano diez secciones que la
      # planilla ya nombra.
      #
      # El resto de los pasos sí se bloquean, y está bien: no hay ninguna
      # pantalla que arme un año escolar desde el alta de una sección.
      listo: cargados.positive?,
      resultado: cargados.positive? ? contar(cargados, "alumno", "alumnos") : nil
    )
  end

  # Las notas de los años anteriores (MOR-203).
  #
  # Daniel: *«en la puesta en marcha falta el paso de cargar las notas
  # históricas la primera vez; el enlace está muy oculto»*. Y estaba: el
  # importador de historial existe desde `MOR-126` y se llegaba a él por
  # Configuración → Importar datos → elegir el tipo. Tres clics para el paso que
  # decide si un colegio puede emitir una constancia el primer día.
  #
  # ⚠️ Va ÚLTIMO y es OPCIONAL, las dos cosas a propósito:
  #
  #   - último, porque el historial cuelga de alumnos que tienen que existir;
  #   - opcional, porque un colegio que abre este año no tiene historial que
  #     cargar, y un paso que no puede completar nunca deja la lista en «7 de 8»
  #     para siempre.
  #
  # ⚠️ Y se marca listo con `FinalGradeBook` importado, no con cualquier nota:
  # las notas del año en curso las carga el profesor y no dicen nada sobre si el
  # colegio trajo su historia.
  def historial
    importadas = FinalGradeBook.unscoped.where(school_id: Current.school_id, origen: :importada).count

    Paso.new(
      clave: :historial, vacio: "Todavía no hay historial cargado", icono: :subir, opcional: true,
      titulo: "Las notas de los años anteriores",
      explicacion: "Solo la primera vez. Si el colegio ya venía funcionando, suba las notas " \
                   "de los años pasados: son las que hacen falta para emitir una constancia " \
                   "o la certificación de un egresado. Cada fila trae su propio año.",
      verbo: Importacion.accion_de(:historial), ruta: :importar_historial,
      listo: importadas.positive?,
      omitido: colegio.omitio_paso?(:historial),
      resultado: importadas.positive? ? contar(importadas, "nota importada", "notas importadas") : nil
    )
  end

  # Un colegio de 150 alumnos no tiene departamentos; los tiene uno de 800, y
  # ese ya sabe pedirlos. Por eso es opcional y se puede omitir para siempre.
  def departamentos
    cargados = Department.count

    Paso.new(
      clave: :departamentos, vacio: "Todavía no hay departamentos", icono: :colegio, opcional: true,
      titulo: "Departamentos",
      explicacion: "Agrupan las materias por área —Ciencias, Letras— y sirven para ver " \
                   "el rendimiento por departamento. Un colegio chico puede vivir sin ellos.",
      verbo: "Agregar un departamento", ruta: :departments,
      listo: cargados.positive?,
      omitido: colegio.omitio_paso?(:departamentos),
      resultado: cargados.positive? ? contar(cargados, "departamento", "departamentos") : nil
    )
  end

  def nombres_de_niveles
    colegio.niveles.map { |n| GradoOficial.etiqueta(n) }.to_sentence(two_words_connector: " y ",
                                                                      last_word_connector: " y ")
  end
end
