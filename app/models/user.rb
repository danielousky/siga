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
  before_validation :descartar_credenciales_en_blanco

  validates :document,       uniqueness: true, allow_nil: true
  validates :cedula_escolar, uniqueness: true, allow_nil: true
  validates :first_name, :last_name, presence: true
  validate  :tiene_algun_identificador
  validate  :con_contrasena_hace_falta_correo

  # Nombre completo con los dos apellidos: "Álvaro José López Medina".
  #
  # Vive acá y no en cada vista porque el segundo apellido es opcional, y
  # `"#{first_name} #{last_name} #{second_last_name}"` deja un espacio colgando
  # cuando falta. Se veía en pantalla.
  def nombre_completo
    [ first_name, apellidos ].compact_blank.join(" ")
  end

  def apellidos
    [ last_name, second_last_name ].compact_blank.join(" ")
  end

  # "López Medina, Álvaro José" — el orden de los listados y las planillas
  # oficiales. Los DOS apellidos: el primero es el que valida el SAIME, pero el
  # segundo es parte del nombre de la persona y omitirlo la identifica peor.
  def apellidos_y_nombres
    [ apellidos, first_name ].compact_blank.join(", ")
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
    return if fila_vieja_sin_identificador?

    errors.add(:base, "Hace falta la cédula de identidad o la cédula escolar")
  end

  def fila_vieja_sin_identificador?
    persisted? && !will_save_change_to_document? && !will_save_change_to_cedula_escolar?
  end

  def normalizar_identificadores
    self.document       = self.class.normalizar_documento(document, document_type)
    self.cedula_escolar = self.class.normalizar_cedula_escolar(cedula_escolar)
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
