class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # El MPPE acepta cuatro documentos, no uno. `cedula_e` es la cédula de un
  # extranjero residente, no un tipo de documento distinto: por eso la
  # nacionalidad NO es un campo aparte — ya está acá, y duplicarla sería invitar
  # a que se contradigan.
  enum :document_type, { cedula_v: 0, cedula_e: 1, pasaporte: 2, carne_diplomatico: 3 }

  DOCUMENT_TYPE_LABELS = {
    "cedula_v"          => "Cédula de identidad (V)",
    "cedula_e"          => "Cédula de identidad (E)",
    "pasaporte"         => "Pasaporte",
    "carne_diplomatico" => "Carné diplomático"
  }.freeze

  # ⚠️ Qué tipos de documento se OFRECEN en un formulario (MOR-177).
  #
  # Daniel: «podemos ocultar pasaporte o carné diplomático; el día que aparezcan
  # se los agregamos». En un colegio venezolano el 99,9 % es V o E, y cuatro
  # opciones para eso es una lista que hay que leer cada vez.
  #
  # ⚠️ El enum NO se toca: los cuatro siguen siendo válidos, y una persona que ya
  # tiene pasaporte cargado —por importación, o de antes— tiene que poder editar
  # su ficha sin que el select le cambie el tipo en silencio. Por eso el suyo se
  # agrega a la lista cuando es el caso.
  def self.tipos_de_documento_ofrecidos(persona = nil)
    ofrecidos = %w[cedula_v cedula_e]
    actual = persona&.document_type
    ofrecidos << actual if actual.present? && ofrecidos.exclude?(actual)

    ofrecidos.map { |tipo| [ SIGLA_DE_DOCUMENTO.fetch(tipo, DOCUMENT_TYPE_LABELS[tipo]), tipo ] }
  end

  # ⚠️ En el formulario el tipo va PEGADO al número, como una cédula escrita:
  # «V | 12345678». Ahí «Cédula de identidad (V)» no cabe ni hace falta — Daniel:
  # «con colocar la V y la E se entiende».
  #
  # Los raros conservan su nombre completo: aparecen una vez cada mil altas y
  # ahí sí hay que poder leer cuál es.
  SIGLA_DE_DOCUMENTO = { "cedula_v" => "V", "cedula_e" => "E" }.freeze

  enum :sex, { female: 0, male: 1 }

  SEX_LABELS = { "female" => "Femenino", "male" => "Masculino" }.freeze

  has_one :address, dependent: :destroy

  # `has_many` y no `has_one`: una persona puede tener el mismo rol en varios
  # colegios —un alumno que se cambia de plantel, un profesor que dicta en dos—.
  # Es el caso normal en Venezuela, y con `has_one` no se podía ni representar.
  #
  # `student` / `teacher` / `admin` en singular siguen existiendo abajo: devuelven
  # el rol EN EL COLEGIO ACTUAL, que es lo que casi todo el código necesita.
  has_many :students, dependent: :destroy
  has_many :teachers, dependent: :destroy
  has_many :admins,   dependent: :destroy

  # El rol en el colegio de la sesión. `Current.school` lo pone el `around_action`
  # a partir del rol del usuario autenticado, nunca de un parámetro.
  def student = students.find_by(school_id: Current.school_id) || students.first
  def teacher = teachers.find_by(school_id: Current.school_id) || teachers.first
  def admin   = admins.find_by(school_id: Current.school_id)   || admins.first

  # El documento se guarda normalizado SIEMPRE, venga de un formulario, de los
  # seeds o del importador. Si la regla viviera en el importador, el formulario
  # seguiría creando `V-12.345.678` y `12345678` como dos personas distintas.
  before_validation :normalizar_identificadores
  before_validation :normalizar_el_nombre
  before_validation :descartar_credenciales_en_blanco

  validates :document,       uniqueness: true, allow_nil: true
  validates :cedula_escolar, uniqueness: true, allow_nil: true
  validates :first_name, :last_name, presence: true
  validate  :tiene_algun_identificador
  validate  :con_contrasena_hace_falta_correo

  # ⚠️ La foto es OPCIONAL y va a seguir siéndolo (MOR-149).
  #
  # Se agrega porque reconocer una cara es más rápido que leer un nombre, y en una
  # lista de 360 alumnos con apellidos repetidos eso importa. Pero un colegio
  # venezolano que carga su matrícula desde una planilla **no tiene 360 fotos**, y
  # un sistema que se ve incompleto sin ellas presiona a subir cualquier cosa.
  #
  # Por eso el caso normal es SIN foto: `AvataresHelper` dibuja las iniciales con
  # un color estable, y eso no es un marcador de posición — es el avatar. La foto,
  # cuando existe, lo reemplaza.
  has_one_attached :foto

  FORMATOS_DE_FOTO = %w[image/png image/jpeg image/webp].freeze
  # 2 MB es lo que sale de un teléfono sin editar. Más que eso es una foto que
  # nadie miró antes de subirla.
  PESO_MAXIMO_DE_FOTO = 2.megabytes

  # El RIF del SENIAT: una letra y nueve dígitos. Las cinco letras son las que
  # el SENIAT emite —V y E para personas, J para empresas, G para entes del
  # Estado, P para el pasaporte— y el noveno dígito es el verificador.
  #
  # ⚠️ Se valida el FORMATO, no el dígito verificador. El algoritmo existe y es
  # público, pero un RIF correcto que el algoritmo rechace deja a un docente
  # fuera de la nómina, y equivocarse por ese lado es mucho peor que guardar un
  # número mal tecleado que el colegio corrige al primer pago.
  FORMATO_DE_RIF = /\A[VEJPG]\d{9}\z/

  validates :rif, format: { with: FORMATO_DE_RIF, message: "va con una letra y nueve dígitos, así: V123456789" },
                  allow_blank: true
  validates :rif, uniqueness: true, allow_blank: true

  # El RIF como se escribe en un recibo: «V-12345678-9».
  def rif_con_guiones
    return nil if rif.blank?
    return rif unless rif.match?(FORMATO_DE_RIF)

    "#{rif[0]}-#{rif[1, 8]}-#{rif[9]}"
  end

  validate :la_foto_es_una_foto

  # ⚠️ Quitar la foto es un CAMPO del formulario, no un botón aparte.
  #
  # Un `DELETE /personas/:id/foto` borraría la foto en el acto, incluso si la
  # persona después cancela la edición — y no hay manera de deshacerlo. Acá la
  # decisión viaja con el resto del formulario y se aplica al guardar, que es
  # cuando quien edita dijo que sí.
  attr_reader :quitar_foto

  def quitar_foto=(valor)
    @quitar_foto = ActiveModel::Type::Boolean.new.cast(valor)

    # ⚠️ Y hay que ENSUCIAR la ficha, o quitar la foto sin corregir ningún otro
    # campo no guarda nada: `quitar_foto` no es una columna, así que el registro
    # no queda sucio, `autosave` se salta al usuario anidado y el `after_save`
    # no llega a correr. Se ve como que el botón no hace nada.
    #
    # `updated_at` además es verdad: la ficha cambió.
    self.updated_at = Time.current if @quitar_foto && persisted?
  end

  # Los campos de una persona que un formulario puede escribir.
  #
  # ⚠️ Vive acá y no en cada controller porque estaba escrita TRES veces
  # —alumno, profesor, administrador— idéntica, y es la misma deuda que
  # `shared/_datos_de_la_persona` saldó para la vista (`MOR-177`): agregar un
  # campo eran tres ediciones y la garantía de olvidar una. La foto lo demostró:
  # el modelo la aceptaba desde MOR-149 y ningún formulario la mandaba.
  CAMPOS_DEL_FORMULARIO = %i[
    first_name last_name second_last_name
    document document_type cedula_escolar rif
    birth_date sex birth_place
    foto quitar_foto
  ].freeze

  # Y lo que agrega el formulario ANIDADO de un rol (`user_attributes`).
  #
  # ⚠️ `id` va acá y NO arriba, y la diferencia no es cosmética:
  #
  #     user_attributes: [:id, …]   ← sin `id`, cada guardado CREA otra persona
  #     params[:user].permit(…)     ← con `id`, se puede cambiar la clave primaria
  #
  # El representante es el segundo caso —su formulario escribe el `User`
  # directo— así que su lista no lo lleva.
  CAMPOS_ANIDADOS = [ :id, *CAMPOS_DEL_FORMULARIO, :email, :password, :password_confirmation ].freeze

  after_save :quitar_la_foto_si_lo_pidieron

  # Nombre completo con los dos apellidos: "Álvaro José López Medina".
  #
  # Vive acá y no en cada vista porque el segundo apellido es opcional, y
  # `"#{first_name} #{last_name} #{second_last_name}"` deja un espacio colgando
  # cuando falta. Se veía en pantalla.
  #
  # ⚠️ Devuelve **Tipo Título**, no lo que hay en la columna. En la base los
  # nombres viven en MAYÚSCULA —la forma de la cédula, de la partida y de las
  # planillas del MPPE— y estos tres métodos son los que la app usa para
  # mostrarlos. Quien necesite la forma canónica lee los atributos directo.
  def nombre_completo
    Normaliza.titulo([ first_name, apellidos_crudos ].compact_blank.join(" "))
  end

  def apellidos
    Normaliza.titulo(apellidos_crudos)
  end

  def apellidos_crudos
    [ last_name, second_last_name ].compact_blank.join(" ")
  end

  # "López Medina, Álvaro José" — el orden de los listados y las planillas
  # oficiales. Los DOS apellidos: el primero es el que valida el SAIME, pero el
  # segundo es parte del nombre de la persona y omitirlo la identifica peor.
  def apellidos_y_nombres
    [ apellidos, Normaliza.titulo(first_name) ].compact_blank.join(", ")
  end

  # La cédula como se escribe y como se dice: «V-12345678».
  #
  # ⚠️ En la base vive SOLO el número. La nacionalidad es `document_type` y
  # `normalizar_documento` le quita todo lo demás para poder buscarla, así que
  # mostrar la columna cruda deja «17078125» — que no es una cédula venezolana,
  # es un número suelto.
  #
  # ⚠️ El pasaporte y el carné NO llevan sigla: su valor ya es alfanumérico y
  # la letra sería inventada.
  def documento_a_la_vista
    return nil if document.blank?

    sigla = SIGLA_DE_DOCUMENTO[document_type]
    sigla ? "#{sigla}-#{document}" : document
  end

  # Y lo mismo con la salida del MPPE: quien no tiene cédula se identifica con
  # la escolar (ver `#identificador`).
  def identificador_a_la_vista = documento_a_la_vista || cedula_escolar

  # La clave con que se ORDENA una lista de personas.
  #
  # ⚠️ `sort_by` compara punto de código por punto de código, y «Á» (U+00C1) es
  # MAYOR que «Z» (U+005A): Álvarez quedaba después de Zambrano en las cinco
  # listas de clase del sistema. No es un caso raro —Álvarez, Ángel, Ávila,
  # Óscar son apellidos y nombres venezolanos corrientes— y en una lista
  # impresa se lee como un error del colegio.
  #
  # ⚠️ Son TRES elementos y el tercero no sobra. `para_comparar` aplana la Ñ,
  # así que «Peña» y «Pena» dan la misma clave; y `sort_by` en Ruby **no es
  # estable**, así que dos personas empatadas saldrían en distinto orden en
  # cada consulta — que es justo la inestabilidad que esto vino a arreglar. El
  # id desempata siempre igual.
  def clave_alfabetica
    nombre = apellidos_y_nombres
    [ Normaliza.para_comparar(nombre).to_s, nombre, id.to_i ]
  end

  # Cómo se identifica esta persona, con lo que tenga.
  #
  # El MPPE resuelve esto igual: en sus planillas, "en el espacio correspondiente
  # a la Cédula de Identidad se registrará el Número de la Cédula Escolar" cuando
  # el alumno no tiene la primera.
  def identificador
    document.presence || cedula_escolar
  end

  def identificador_etiqueta
    return DOCUMENT_TYPE_LABELS[document_type] if document.present?
    "Cédula escolar" if cedula_escolar.present?
  end

  # Una persona sin contraseña no puede entrar, y no hace falta un flag para
  # saberlo: `Devise::Encryptor.compare` arranca con
  # `return false if hashed_password.blank?`.
  #
  # Existe como método porque las vistas necesitan decirlo en palabras
  # —"todavía no ha activado su acceso"—, no porque cambie el comportamiento.
  def puede_entrar? = encrypted_password.present?

  # --- activar el acceso (MOR-143) ----------------------------------------

  # Genera el código de un solo uso con el que esta persona entra por primera
  # vez, y devuelve el valor EN CLARO.
  #
  # Es `reset_password_token` de Devise, sin disfraz: genera, digiere, guarda el
  # hash y caduca. Reimplementarlo sería escribir de nuevo, peor, código que ya
  # está probado por miles de aplicaciones. Lo único que cambia es de dónde sale
  # el disparo —la secretaria, no el usuario— y qué dice el mensaje.
  #
  # ⚠️ El valor devuelto existe UNA sola vez, acá, en memoria. En la columna
  # queda el digest, así que no se puede volver a mostrar: si se perdió, se
  # regenera. Eso no es una limitación que haya que sortear — es la propiedad
  # que se quiere. Una pantalla que muestre el código vigente de cualquier
  # representante es una lista de llaves de todas las casas.
  def generar_codigo_de_acceso!
    set_reset_password_token
  end

  # Un código de ACTIVACIÓN vive 72 horas; uno de recuperación, las 6 de Devise.
  #
  # No son el mismo riesgo ni el mismo apuro. Quien pidió recuperar su
  # contraseña está sentado frente a la pantalla esperando el correo. A quien lo
  # activan no pidió nada: la secretaria carga la matrícula un jueves y la mamá
  # abre el mensaje el domingo.
  #
  # La diferencia se deduce del estado, sin guardar ninguna bandera: quien
  # todavía no tiene contraseña está activando, no recuperando.
  ACTIVACION_VALIDA_POR = 72.hours

  def reset_password_period_valid?
    return super if puede_entrar?

    reset_password_sent_at && reset_password_sent_at.utc >= ACTIVACION_VALIDA_POR.ago.utc
  end

  # --- Devise -------------------------------------------------------------

  # Un alumno de 2do grado no tiene correo y no lo necesita: no es una cuenta,
  # es un registro. Quién SÍ necesita correo lo decide el rol —`Teacher` y
  # `Admin` lo exigen— porque es ahí donde se sabe.
  def email_required? = false

  # Devise exige contraseña en toda alta (`!persisted?`). Acá una persona puede
  # nacer sin credenciales y recibirlas después, cuando active su acceso.
  #
  # Se sigue exigiendo —longitud, confirmación— en cuanto alguien esté PONIENDO
  # una: eso es lo que devuelve `super`.
  def password_required?
    return false if password.nil? && password_confirmation.nil?

    super
  end

  # --- normalización de identificadores -----------------------------------
  #
  # Son métodos de CLASE porque no solo hace falta al guardar: quien BUSCA los
  # necesita igual. Para encontrar a la persona `12345678` hay que normalizar
  # `V-12.345.678` ANTES de preguntar, o la consulta no devuelve nada y el
  # importador crea a la misma persona por segunda vez.

  # Tener contraseña obliga a tener correo, y es un invariante del MODELO y no
  # una regla de un formulario a propósito.
  #
  # `MOR-143` lo exige en la pantalla de activación… y el MISMO token abre el
  # formulario estándar de Devise —`/users/password/edit`—, que no pregunta por
  # el correo. Medido: quedaba una persona con contraseña y sin correo, o sea
  # **sin ninguna forma de recuperarla nunca**, que es exactamente el estado que
  # ese issue dice que no puede existir.
  #
  # Puesto acá, se cierra por cualquier puerta: la de Devise, la de activación,
  # la consola y el importador que todavía no existe.
  #
  # Al revés SÍ se puede: correo sin contraseña es una persona a la que todavía
  # no le activaron el acceso, y es el caso normal.
  def con_contrasena_hace_falta_correo
    return if email.present? || encrypted_password.blank?

    errors.add(:base, "Hace falta un correo electrónico para poder tener contraseña: " \
                      "es el único lugar donde el sistema puede escribirle si la olvida.")
  end

  # Cada tipo de documento se limpia distinto, y confundirlos destruye datos:
  #
  #   cédula (V/E) ......  solo dígitos, sin ceros a la izquierda
  #                        "V-12.345.678" → "12345678"
  #   pasaporte / carné .  alfanumérico en mayúscula
  #                        "a1234567b" → "A1234567B"
  #
  # La regla de la cédula aplicada a un pasaporte se come las letras y lo deja
  # identificando a otra persona. Por eso el caso DESCONOCIDO cae en la regla
  # conservadora, no en la destructiva.
  #
  # La nacionalidad no se guarda en el número: ya está en `document_type`.
  def self.normalizar_documento(valor, tipo)
    case tipo_de_documento(tipo)
    when "cedula_v", "cedula_e" then valor&.gsub(/\D/, "")&.sub(/\A0+/, "").presence
    else                             valor&.gsub(/[^A-Za-z0-9]/, "")&.upcase.presence
    end
  end

  # La cédula escolar NO se normaliza como un documento: su formato lo define el
  # MPPE —12 caracteres que empiezan por la nacionalidad— y los guiones son
  # parte del dato. Solo se quitan espacios y se sube a mayúscula.
  def self.normalizar_cedula_escolar(valor)
    valor&.gsub(/\s/, "")&.upcase.presence
  end

  # El RIF se guarda SIN guiones y en mayúscula: «V-12.345.678-9» y «V123456789»
  # son el mismo número, y la forma canónica es la que permite buscarlo.
  #
  # ⚠️ Lo que se GUARDA y lo que se MUESTRA no son lo mismo: en el recibo de
  # pago va con sus guiones, y de eso se encarga `#rif_con_guiones`.
  def self.normalizar_rif(valor)
    valor&.gsub(/[^A-Za-z0-9]/, "")&.upcase.presence
  end

  # El tipo llega de tres formas según quién pregunte: el símbolo del enum
  # (modelo), su nombre en cadena —lo que manda el `<select>` del formulario— o
  # el entero crudo, que es como vive en la base y como sale de la exportación
  # de otro sistema. El importador va a ver las tres.
  def self.tipo_de_documento(tipo)
    return document_types.key(tipo.to_i) if tipo.to_s.match?(/\A\d+\z/)

    tipo.to_s.presence
  end

  private

  # Una persona sin ningún identificador no puede aparecer en una planilla del
  # MPPE, así que tampoco debería poder existir acá.
  #
  # No es `presence` sobre ninguno de los dos por separado: un alumno de primaria
  # normalmente NO tiene cédula, y un profesor NUNCA tiene cédula escolar.
  #
  # ⚠️ Y NO se aplica a una fila que ya existía sin identificador.
  #
  # Esta validación nació con `MOR-138`, sobre una tabla que ya tenía datos. En
  # producción **298 de 313 usuarios** no la cumplían —todos los alumnos, los
  # tres administradores y el equipo de SIGA— y el efecto no fue un error al
  # crear: fue dejarlos CONGELADOS. Cualquier `save` fallaba, incluido el de
  # Devise al cambiar la contraseña. O sea que la fila no se podía ni arreglar.
  #
  # Una validación nueva sobre datos que ya existen es una migración de datos
  # disfrazada, y `bin/ci` no lo ve porque los seeds regeneran todo desde cero.
  #
  # Lo que sí se sigue impidiendo, que es lo que la regla quería decir:
  #
  #     nacer sin identificador          → rechazado
  #     borrar el que ya tenía           → rechazado
  #     guardar otra cosa de una fila
  #     que nunca tuvo uno               → permitido, para poder arreglarla
  def tiene_algun_identificador
    return if document.present? || cedula_escolar.present?
    return if se_registro_solo?
    return if fila_vieja_sin_identificador?

    errors.add(:base, "Hace falta la cédula de identidad o la cédula escolar")
  end

  # ⚠️ Quien abre su propia cuenta se identifica con su CORREO (MOR-196).
  #
  # Daniel, mirando el formulario de registro: *«no debería pedirse la CI en
  # este momento; además, al director (o asistente) ese dato es irrelevante»*.
  #
  # Y es coherente con el porqué de la regla, que está escrito arriba: hace
  # falta un identificador porque *«una persona sin ninguno no puede aparecer en
  # una planilla del MPPE»*. Quien acaba de registrarse para PROBAR el producto
  # no aparece todavía en ninguna planilla — no tiene colegio, ni alumnos, ni
  # documentos que firmar. Se le pide la cédula el día que haga falta, que es
  # justo lo que la propia pantalla de registro ya prometía.
  #
  # Y no queda sin identificar: `users.email` es único en toda la plataforma y
  # es con lo que entra.
  #
  # ⚠️ La condición es tener CONTRASEÑA, no tener correo, y la diferencia es
  # todo el punto. Un alumno puede tener correo y ser un registro que cargó el
  # colegio (`MOR-142`); ése sí necesita su cédula escolar, porque va a salir en
  # un boletín. Contraseña propia = cuenta propia = alguien que se registró.
  def se_registro_solo?
    new_record? && encrypted_password.present?
  end

  # La foto tiene que ser una foto, y de un tamaño que una conexión de colegio
  # pueda con ella. Mismo criterio que el escudo en `School`.
  def la_foto_es_una_foto
    return unless foto.attached?

    unless FORMATOS_DE_FOTO.include?(foto.blob.content_type)
      errors.add(:foto, "tiene que ser PNG, JPG o WEBP")
    end

    return unless foto.blob.byte_size > PESO_MAXIMO_DE_FOTO

    errors.add(:foto, "no puede pesar más de 2 MB — una foto de carnet no lo necesita, " \
                      "y la conexión del colegio sí")
  end

  # ⚠️ `purge_later` y no `purge`: borrar el archivo del almacenamiento es una
  # llamada a disco —o a S3— dentro de la transacción que guarda la ficha.
  def quitar_la_foto_si_lo_pidieron
    return unless quitar_foto
    return unless foto.attached?

    foto.purge_later
  end

  def fila_vieja_sin_identificador?
    persisted? && !will_save_change_to_document? && !will_save_change_to_cedula_escolar?
  end

  # Se guarda en MAYÚSCULA, que es la forma de los documentos. Lo que se ve en
  # pantalla lo deciden `nombre_completo` y compañía.
  def normalizar_el_nombre
    self.first_name       = Normaliza.mayuscula(first_name)
    self.last_name        = Normaliza.mayuscula(last_name)
    self.second_last_name = Normaliza.mayuscula(second_last_name)
  end

  def normalizar_identificadores
    self.document       = self.class.normalizar_documento(document, document_type)
    self.cedula_escolar = self.class.normalizar_cedula_escolar(cedula_escolar)
    self.rif            = self.class.normalizar_rif(rif)
  end

  # Un campo de formulario vacío llega como `""`, nunca como `nil`. Y para este
  # par de columnas la diferencia es todo (MOR-142):
  #
  #   email ....  `''` SÍ choca contra el índice único. PostgreSQL admite muchos
  #               NULL porque cada uno es distinto, pero `''` es un valor como
  #               cualquier otro: sin esta línea, el SEGUNDO alumno sin correo
  #               revienta la carga.
  #
  #   password .  `""` no es `nil`, así que Devise entiende "está poniendo una
  #               contraseña" y exige presencia. Guardar un alumno dejando el
  #               campo en blanco fallaba con "no puede estar en blanco", que es
  #               justamente lo que este issue vino a permitir.
  #
  # Corre DESPUÉS de `strip_whitespace` de Devise —que se registra al llamar a
  # `devise` arriba—, así que un correo de puros espacios ya llegó como `""`.
  def descartar_credenciales_en_blanco
    self.email = email.presence

    self.password              = nil if password.blank?
    self.password_confirmation = nil if password_confirmation.blank?
  end
end
