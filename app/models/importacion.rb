# Una importación de matrícula, de punta a punta (MOR-126).
#
# El nombre va en español —como `Planilla`, `EscalaLiteral` o `BusquedaSinAcentos`—
# porque toda la maquinaria del importador lo está, y mezclar `Import` con
# `Planilla` en la misma línea se lee peor que mezclar `Importacion` con
# `Student`. El plural lo aprende el inflector en `config/initializers/
# inflections.rb`, donde ya viven `solicitud` y `constancia`: con eso la tabla,
# las rutas y los helpers salen bien solos.
class Importacion < ApplicationRecord
  include SchoolScoped

  # ⚠️ El archivo trae los datos personales de 360 menores, así que no vive para
  # siempre. Ver `#purgable?` abajo.
  #
  # Active Storage no lleva RLS —igual que Solid Queue, es maquinaria de la
  # plataforma y no dato de ningún colegio—. Lo que aísla al archivo es la fila
  # que lo referencia: sin poder ver la `Importacion`, no hay cómo llegar al
  # adjunto.
  has_one_attached :archivo

  belongs_to :school
  belongs_to :subido_por, class_name: "User"

  # El año escolar que se está cargando. Se puede cambiar antes de confirmar:
  # un colegio que entra en agosto está subiendo la matrícula del año que
  # empieza, pero uno que llega a mitad de año sube la del que está corriendo.
  belongs_to :academic_period, optional: true

  # `cargada`      el archivo está arriba y ya se leyeron sus encabezados
  # `mapeada`      alguien dijo qué columna es cuál y vio la previsualización
  # `confirmada`   se escribió en la base; `resultado` dice qué pasó
  # `descartada`   se abandonó a mitad, o se subió otra en su lugar
  enum :estado, { cargada: 0, mapeada: 1, confirmada: 2, descartada: 3 }

  # Qué trae la planilla. Cambia qué columnas se esperan y qué se crea; el
  # lector, el mapeo, la previsualización y el reporte son los mismos.
  enum :tipo, { matricula: 0, pensum: 1, historial: 2 }

  TIPOS = {
    "matricula" => "Matrícula de alumnos",
    "pensum" => "Materias y profesores",
    "historial" => "Notas de años anteriores"
  }.freeze

  def etiqueta_de_tipo = TIPOS.fetch(tipo, tipo)

  # Cómo se llama SUBIR cada planilla, en el botón que lleva a hacerlo.
  #
  # ## ⚠️ Por qué esto es una constante y no un texto por vista
  #
  # Lo estaba, y el mismo enlace terminó con tres nombres distintos. Daniel,
  # señalando la pantalla de profesores: *«mismo link, nombres distintos»* — el
  # botón de arriba decía «Subir materias y profesores» y el del estado vacío,
  # dos centímetros abajo, «Subir el pensum». Los dos van a
  # `/importaciones/new?tipo=pensum`.
  #
  #     pensum      "Subir materias y profesores" · "Subir el pensum"
  #     matricula   "Subir la matrícula"          · "Subir matrícula"
  #     historial   "Subir el historial"          · "Subir notas anteriores"
  #
  # No es una molestia estética: quien ve dos nombres busca la diferencia, y
  # cuando la busca en un importador se pregunta cuál de las dos planillas es la
  # suya. `TIPOS` nombra el SUSTANTIVO —qué trae la planilla— y esto nombra la
  # ACCIÓN. Son dos textos y hacen falta los dos: «Materias y profesores» es el
  # encabezado de una columna, no un botón.
  ACCIONES = {
    "matricula" => "Subir la matrícula",
    "pensum" => "Subir materias y profesores",
    "historial" => "Subir las notas anteriores"
  }.freeze

  # `fetch` sin default a propósito: un tipo mal escrito tiene que reventar acá
  # y no pintar un botón sin nombre.
  def self.accion_de(tipo) = ACCIONES.fetch(tipo.to_s)

  # El título del reporte. Va aparte de `TIPOS` porque la concordancia cambia con
  # cada uno —«importada», «importados», «importadas»— y armarlo pegando palabras
  # da «Materias y profesores: importada».
  REPORTES = {
    "matricula" => "Matrícula importada",
    "pensum" => "Materias y profesores importados",
    "historial" => "Notas de años anteriores importadas"
  }.freeze

  def titulo_del_reporte = REPORTES.fetch(tipo, etiqueta_de_tipo)

  DEFINICIONES = {
    "matricula" => ColumnasDeMatricula,
    "pensum" => ColumnasDePensum,
    "historial" => ColumnasDeHistorial
  }.freeze

  # Las columnas que esta importación espera, según su tipo.
  def columnas = DEFINICIONES.fetch(tipo)

  # ⚠️ Subir la planilla equivocada es fácil: son tres botones al lado.
  #
  # `otro_tipo` es aquel cuyas columnas encajan MEJOR que las del tipo declarado.
  # Con dos tipos alcanzaba con «el otro»; con tres hay que elegir, y se elige
  # midiendo, no adivinando.
  def otro_tipo
    (DEFINICIONES.keys - [ tipo ]).max_by { |t| encaje_con(DEFINICIONES.fetch(t)) }
  end

  def columnas_del_otro_tipo = DEFINICIONES.fetch(otro_tipo)

  def etiqueta_del_otro_tipo = TIPOS.fetch(otro_tipo)

  # ⚠️ Subir la planilla equivocada es fácil: son dos botones al lado.
  #
  # Y salió caro de verdad en pruebas: una planilla de MATRÍCULA subida como
  # pensum mapeó «APELLIDOS Y NOMBRES» al PROFESOR, «CEDULA REPRESENTANTE» a su
  # cédula y «CORREO REPRESENTANTE» a su correo. Lo único que la frenó fue que
  # faltaba MATERIA — con una columna más, el colegio habría terminado con sus
  # alumnos cargados como PROFESORES, cada uno con el correo de su mamá de
  # usuario.
  #
  # No se bloquea nada: se avisa y se ofrece cambiar. Quien sube sabe cosas que
  # el sistema no, y una planilla rara pero legítima tiene que poder entrar.
  def parece_del_otro_tipo?
    return false if obligatorias_sin_mapear.empty?

    encaje_con(columnas_del_otro_tipo) > encaje_con(columnas)
  end

  # Cuántas columnas DISTINTAS reconoce cada definición. Distintas y no totales:
  # en una planilla de matrícula, tres columnas de cédula caen todas en
  # `cedula_del_profesor` e inflarían el puntaje del tipo equivocado.
  def encaje_con(definicion)
    planilla.encabezados.filter_map { |e| definicion.para(e)&.clave }.uniq.size
  end

  ETIQUETAS = {
    "cargada" => "Sin mapear", "mapeada" => "Lista para confirmar",
    "confirmada" => "Importada", "descartada" => "Descartada"
  }.freeze

  # Cuánto se conserva el archivo después de importarlo. Treinta días alcanzan
  # para investigar un reclamo —"a mi hijo lo pusieron en la sección
  # equivocada"— y no convierten al servidor en un archivo de datos de menores.
  CONSERVAR_EL_ARCHIVO = 30.days

  validates :nombre_del_archivo, presence: true

  scope :recientes, -> { order(created_at: :desc) }
  scope :en_curso,  -> { where(estado: [ :cargada, :mapeada ]) }

  def etiqueta_de_estado = ETIQUETAS.fetch(estado, estado)

  def terminada? = confirmada? || descartada?

  # El archivo ya no hace falta y tiene datos de menores adentro.
  #
  # Dos casos, un mismo plazo:
  #
  #   confirmada          ya cumplió su función; los 30 días son para poder
  #                       investigar un reclamo —«a mi hijo lo pusieron en la
  #                       sección equivocada»—.
  #   cargada / mapeada   nadie la tocó en un mes: alguien subió una planilla,
  #                       se confundió y se fue. Que quede a medias no la vuelve
  #                       menos sensible, y era el caso que se quedaba para
  #                       siempre.
  #
  # `descartada` no aparece: `#destroy` ya purga el archivo en el momento.
  def purgable? = !descartada? && updated_at < CONSERVAR_EL_ARCHIVO.ago

  # ⚠️ Cruza colegios a propósito: el archivo no es de nadie en particular, es
  # una obligación de la plataforma. Por eso el scope va SIN aislamiento y el
  # job que lo usa se declara `de_toda_la_plataforma`.
  def self.con_archivo_vencido
    Current.sin_aislamiento do
      joins(archivo_attachment: :blob)
        .where.not(estado: estados[:descartada])
        .where(updated_at: ...CONSERVAR_EL_ARCHIVO.ago)
    end
  end

  SIN_ARCHIVO = "El archivo de esta importación ya no está: se borra a los " \
                "#{CONSERVAR_EL_ARCHIVO.inspect}, o al descartarla. El reporte de lo que se " \
                "cargó sigue disponible.".freeze

  # La planilla, leída. Se relee del adjunto en cada paso a propósito: la
  # previsualización tiene que mostrar exactamente lo que después se va a
  # escribir, y eso solo se garantiza leyendo la misma fuente las dos veces.
  #
  # ⚠️ Sin archivo se levanta `NoSePuedeLeer`, que es lo que los controllers ya
  # saben rescatar.
  #
  # `archivo.open` sobre un adjunto purgado no revienta: devuelve `nil` sin
  # llamar al bloque. Así que `@planilla` quedaba en nil y el primer
  # `.encabezados` daba un `NoMethodError` — un 500 pelado, y NO era hipotético:
  # `#destroy` purga el archivo, así que bastaba con descartar una importación y
  # volver a abrirla desde el listado.
  def planilla
    return @planilla if @planilla

    raise Planilla::NoSePuedeLeer, SIN_ARCHIVO unless archivo.attached?

    @planilla = archivo.open do |archivo_local|
      Planilla.new(archivo_local.path, extension: File.extname(nombre_del_archivo))
    end

    raise Planilla::NoSePuedeLeer, SIN_ARCHIVO if @planilla.nil?

    @planilla
  rescue ActiveStorage::FileNotFoundError
    raise Planilla::NoSePuedeLeer, SIN_ARCHIVO
  end

  # El mapeo que propone el sistema, para que la persona solo corrija lo que
  # esté mal en vez de armarlo desde cero.
  def mapeo_sugerido
    planilla.encabezados.index_with { |e| columnas.para(e)&.clave&.to_s }.compact
  end

  def mapeo_efectivo = mapeo.presence || mapeo_sugerido

  # Las columnas obligatorias que nadie mapeó. Mientras haya alguna, la
  # importación no puede avanzar: rellenarlas con un valor por defecto sería
  # inventar datos de un alumno.
  def obligatorias_sin_mapear
    mapeadas = mapeo_efectivo.values.map(&:to_s)

    columnas.obligatorias.reject { |c| mapeadas.include?(c.clave.to_s) }
  end

  def lista_para_previsualizar? = obligatorias_sin_mapear.empty?

  # El año escolar al que va la matrícula.
  #
  # Normalmente viene estampado desde que se subió la planilla —con el año de la
  # sesión (MOR-165)— y quien importa lo puede cambiar en la previsualización.
  # El respaldo es para las importaciones viejas, de antes de que se estampara,
  # y para cuando no hay sesión: primero el año elegido, después el vigente.
  def periodo
    academic_period || Current.academic_period || AcademicPeriod.vigente
  end
end
