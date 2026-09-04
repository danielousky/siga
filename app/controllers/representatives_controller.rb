# Alta y mantenimiento de representantes, desde el colegio (MOR-110).
#
# Los carga la secretaría, no se registran solos: `/users/sign_up` está cerrado
# desde `MOR-101` y eso no cambia acá. Un representante que se auto-registra
# tendría que demostrar de algún modo que ese alumno es su hijo, y el único que
# puede saberlo es el colegio.
class RepresentativesController < ApplicationController
  el_nivel_no_aplica "un representante puede tener hijos en varios niveles"
  include GeneraCodigosDeAcceso

  genera_codigos_de_acceso_para :representative
  before_action :require_puede_gestionar!
  before_action :set_representative, only: [:show, :edit, :update, :destroy, :generar_codigo]

  def index
    scope = Representative.includes(:user, students: :user)
    if params[:q].present?
      ids = User.where(*BusquedaSinAcentos.condicion(CAMPOS_DE_BUSQUEDA, params[:q])).pluck(:id)
      scope = scope.where(user_id: ids)
    end
    @pagy, @representatives = pagy(scope.joins(:user).order("users.last_name, users.first_name"))
  end

  # Buscar por los datos de la persona, no de la fila: quien busca tiene el
  # nombre o el teléfono, nunca el id.
  CAMPOS_DE_BUSQUEDA = %w[first_name last_name second_last_name email document cedula_escolar].freeze

  def show
    @vinculos = @representative.student_representatives.includes(student: :user)
    # El seguimiento de lo que se le escribió (MOR-186). Del más nuevo al más
    # viejo, que es como se lee: la pregunta suele ser «¿ya le avisamos?».
    @mensajes = Mensaje.para(@representative.user).recientes.includes(:remitente)
  end

  # ⚠️ Se puede llegar acá CON un alumno ya elegido (MOR-180).
  #
  # Daniel: «en el detalle del estudiante, si no tiene representante, debería
  # poder emparejarlo rápidamente o un enlace a registrar representante que
  # tenga como parámetro el id del estudiante y precargarlo... NO PREGUNTEMOS LO
  # DEDUCIBLE».
  #
  # Quien viene de la ficha de Eduardo ya dijo de quién habla. Llegar a un
  # formulario con doscientas casillas sin marcar y tener que buscarlo otra vez
  # es preguntarle lo que acaba de responder.
  #
  # El id se busca con el `default_scope`: uno de otro colegio simplemente no
  # aparece, y el formulario se abre vacío como si no lo hubieran mandado.
  def new
    @representative = Representative.new
    @usuario = User.new
    @alumno_elegido = Student.find_by(id: params[:alumno_id])
  end

  # Crea la persona y su rol de una vez. Separarlo en dos pasos —"primero cree el
  # usuario, después asígnele el rol"— es pedirle a la secretaría que entienda el
  # modelo de datos para hacer su trabajo.
  def create
    @usuario = usuario_existente || User.new(user_params)

    # Sin contraseña, a propósito: antes se le ponía una aleatoria de 12
    # caracteres que NADIE conocía —ni el representante ni la secretaria—, así
    # que la cuenta nacía inutilizable igual, pero pareciendo utilizable.
    # Ahora nace sin credenciales y el acceso se activa aparte (`MOR-143`).
    if @usuario.new_record?
      unless @usuario.save
        @representative = Representative.new
        return render :new, status: :unprocessable_entity
      end
    end

    @representative = Representative.new(user: @usuario, phone: params[:representative][:phone])

    if @representative.save
      vincular_alumnos(@representative)
      redirect_to @representative, notice: "Representante registrado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @usuario = @representative.user
  end

  def update
    if @representative.update(phone: params[:representative][:phone]) && @representative.user.update(user_params)
      vincular_alumnos(@representative)
      redirect_to @representative, notice: "Representante actualizado."
    else
      @usuario = @representative.user
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @representative.destroy
    redirect_to representatives_path, notice: "Representante eliminado."
  end

  # El código con el que el representante entra por primera vez (MOR-143).
  #
  # Se muestra en pantalla SIEMPRE, y además se manda por correo si lo hay. No
  # es redundante: sin correo, la pantalla es el único canal —la secretaria lo
  # pega en WhatsApp desde su teléfono, se lo dicta o lo imprime—.
  #
  # ⚠️ Viaja en el flash porque solo se puede mostrar UNA vez: Devise guarda el
  # token digerido, así que ni esta pantalla ni ninguna otra puede volver a
  # leerlo. Si se perdió, se genera otro y el anterior deja de servir.

  private

  # Si la persona ya tiene cuenta —porque es profesora del colegio, o ya
  # representa a otro alumno— se reutiliza, para que una persona siga siendo una
  # sola cuenta (MOR-84, MOR-138).
  #
  # ⚠️ Se busca por DOCUMENTO primero, no por correo. Buscar por un campo que
  # desde `MOR-142` puede venir vacío no falla ruidosamente: DUPLICA. La misma
  # mamá, cargada para su segundo hijo sin correo, nacía como una persona nueva
  # — justo lo contrario de lo que construyó `MOR-138`.
  #
  # ⚠️ NUNCA por correo, y esto costó un incidente (MOR-200).
  #
  # Daniel: *«accidentalmente coloqué el mismo correo para un director y un
  # representante. En primer lugar, nunca dio error y debió darlo; segundo, al
  # cambiárselo al director también lo hizo con el representante»*.
  #
  # Las dos mitades son el MISMO hecho: buscar por correo encontró al director,
  # así que el «representante nuevo» no fue una persona nueva — fue un rol más
  # colgado de la fila del director. Una sola fila con dos roles: editar el
  # correo de uno editaba el del otro, porque son el mismo `User`.
  #
  # `CLAUDE.md § 6.2` ya lo decía —*«buscar a una persona por correo DUPLICA o
  # BLOQUEA»*— y el código hacía justo eso. Un correo identifica un BUZÓN, y un
  # buzón cambia de dueño: la casilla de la familia, la del colegio, la que la
  # secretaria escribió mal.
  #
  # Sin el respaldo por correo, el caso de Daniel termina donde tenía que
  # terminar: se intenta crear una persona nueva, el índice único de
  # `users.email` la rechaza y la pantalla dice que ese correo ya es de alguien.
  # Un error visible en vez de dos registros fusionados en silencio.
  #
  # El orden es el de confiabilidad: el documento identifica a la PERSONA, y la
  # cédula escolar la acompaña mientras no lo tenga.
  #
  # Los valores se normalizan antes de preguntar: en la base vive `12345678`, y
  # `WHERE document = 'V-12.345.678'` no devuelve nada.
  def usuario_existente
    documento = User.normalizar_documento(params.dig(:user, :document),
                                          params.dig(:user, :document_type))
    cedula    = User.normalizar_cedula_escolar(params.dig(:user, :cedula_escolar))
    correo    = params.dig(:user, :email).to_s.strip.downcase.presence

    Current.sin_aislamiento do
      (documento && User.find_by(document: documento)) ||
        (cedula && User.find_by(cedula_escolar: cedula))
    end
  end

  def vincular_alumnos(representante)
    ids = Array(params[:student_ids]).reject(&:blank?).map(&:to_i)

    representante.student_representatives.where.not(student_id: ids).destroy_all

    ids.each do |student_id|
      vinculo = representante.student_representatives.find_or_initialize_by(student_id: student_id)
      # ⚠️ Tres niveles, del más específico al más general (MOR-199): el
      # parentesco de ESE alumno si vino, el que eligió el formulario para
      # todos, y «representante legal» como último recurso —que es el que sirve
      # siempre y no afirma un vínculo que nadie declaró.
      vinculo.parentesco = params.dig(:parentesco, student_id.to_s).presence ||
                           params[:parentesco_general].presence ||
                           :representante
      vinculo.save
    end
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :second_last_name, :email,
                                :document, :document_type, :cedula_escolar,
                                :birth_date, :sex)
  end

  def set_representative
    @representative = Representative.find(params[:id])
  end

  def require_puede_gestionar!
    return if can_manage_students?

    redirect_to dashboard_path_for_user, alert: "No tienes permiso para gestionar representantes."
  end
end
