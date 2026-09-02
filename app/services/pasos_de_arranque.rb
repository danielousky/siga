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
  Paso = Data.define(:clave, :titulo, :explicacion, :verbo, :ruta, :icono, :vacio,
                     :listo, :resultado, :necesita, :opcional, :omitido) do
    def initialize(clave:, titulo:, explicacion:, verbo:, ruta:, icono:, vacio: nil,
                   listo: false, resultado: nil, necesita: nil, opcional: false, omitido: false)
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
    [ niveles, identidad, departamentos, materias, ano_escolar, secciones, alumnos ]
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
      resultado: listo ? "DEA #{colegio.dea_code}" : nil
    )
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
      verbo: periodo ? "Revisar los lapsos" : "Crear el año escolar",
      ruta: periodo ? :evaluation_moments : :academic_periods,
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
      explicacion: "Si ya tiene el pensum en un Excel, súbalo: de una sola planilla salen " \
                   "las materias, los profesores y quién dicta qué en cada sección. El " \
                   "código (MAT, CAS, FIS) es suyo: si la planilla no lo trae, SIGA propone " \
                   "uno y usted lo corrige.",
      verbo: "Cargar las materias", ruta: :subjects,
      # Las dos mitades: una materia sin nadie que la dicte no deja cargar una
      # nota, así que el paso no está hecho hasta que hay quien la dé.
      listo: materias_cargadas.positive? && profesores_cargados.positive?,
      resultado: resultado_del_pensum(materias_cargadas, profesores_cargados)
    )
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
      verbo: "Subir la matrícula", ruta: :importaciones,
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

  # Un colegio de 150 alumnos no tiene departamentos; los tiene uno de 800, y
  # ese ya sabe pedirlos. Por eso es opcional y se puede omitir para siempre.
  def departamentos
    cargados = Department.count

    Paso.new(
      clave: :departamentos, vacio: "Todavía no hay departamentos", icono: :colegio, opcional: true,
      titulo: "Departamentos",
      explicacion: "Agrupan las materias por área —Ciencias, Letras— y sirven para ver " \
                   "el rendimiento por departamento. Un colegio chico puede vivir sin ellos.",
      verbo: "Crear los departamentos", ruta: :departments,
      listo: cargados.positive?,
      omitido: colegio.omitio_paso?(:departamentos),
      resultado: cargados.positive? ? contar(cargados, "departamento", "departamentos") : nil
    )
  end

  def nombres_de_niveles
    colegio.niveles.map { |n| GradoOficial::ETIQUETAS[n] }.to_sentence(two_words_connector: " y ",
                                                                      last_word_connector: " y ")
  end
end
