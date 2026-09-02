# Los departamentos, gestionados EN UNA SOLA PANTALLA (MOR-205).
#
# Daniel: *«la creación de los dptos es solo el campo nombre; en ese caso podemos
# sustituir el filtro por un campo del new para agregar directamente allí y
# aparezca abajo, con posibilidad de editarlo al hacer clic en el nombre y la
# papelera al final de la fila. Todo con Turbo»*.
#
# ## ⚠️ Sin buscador y sin paginación, a propósito
#
# Las dos existen para listas que no caben en una pantalla. Un colegio tiene
# ocho o diez departamentos —«a lo sumo serán 10», y el que tiene más ya no es
# el colegio al que apunta SIGA—, así que un buscador acá es un control que
# nadie toca y que además ocupa el sitio del que sí se usa.
#
# ## Y por qué se reemplaza la LISTA ENTERA
#
# Agregar cambia dos cosas: la fila nueva y el conteo de arriba («8
# departamentos»). Con un Turbo Stream por elemento serían dos operaciones que
# hay que acordarse de mantener juntas; reemplazar el bloque es una sola y no
# puede quedar a medias. Con diez filas el costo es cero.
class DepartmentsController < ApplicationController
  before_action :set_department, only: [ :edit, :update, :destroy ]

  def index
    @departments = Department.order(:name)
  end

  def new
    # ⚠️ Se conserva por si alguien llega por la URL, pero el camino real es el
    # campo de la propia lista: `PasosDeArranque` y la cabecera apuntan ahí.
    @department = Department.new
  end

  # ⚠️ La edición NO tiene pantalla propia: convierte la fila en un campo.
  #
  # El `format.html` sigue existiendo para quien llegue por la URL sin Turbo —y
  # para que el test de «las pantallas de edición se abren todas» siga
  # midiendo algo—: manda al listado, que es donde se edita.
  def edit
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to departments_path }
    end
  end

  def create
    @department = Department.new(department_params)

    if @department.save
      registrar_cambio(:creado, @department, @department.name)
      responder("Departamento agregado.")
    else
      # ⚠️ La pantalla completa del alta, y no un aviso al vuelo: acá el
      # formulario tiene que volver CON lo escrito y con el error al lado, que es
      # lo que `new.html.haml` ya sabe hacer. El 422 es lo que hace que Turbo lo
      # pinte en vez de descartarlo.
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @department.update(department_params)
      registrar_cambio(:actualizado, @department, @department.name)
      responder("Departamento actualizado.")
    else
      # La fila vuelve en modo edición, con lo escrito y el error al lado.
      render turbo_stream: turbo_stream.replace(helpers.dom_id(@department),
                                                partial: "departments/fila_en_edicion",
                                                locals: { department: @department }),
             status: :unprocessable_entity
    end
  end

  def destroy
    # El nombre, antes de borrar: después el objeto ya no puede resolver sus
    # asociaciones para armar el mensaje.
    nombre = @department.name

    if @department.destroy
      registrar_cambio(:eliminado, @department, nombre)
      responder("#{nombre} eliminado.")
    else
      redirect_to departments_path, alert: @department.errors.full_messages.to_sentence
    end
  end

  private

  # ⚠️ Turbo Stream si vino por Turbo, redirect si no.
  #
  # El `format.html` no es cortesía: es lo que hace que la pantalla siga
  # funcionando con el JavaScript caído —la conexión de un colegio corta un
  # archivo más seguido de lo que uno cree— y lo que permite probar esto sin
  # levantar un navegador.
  def responder(aviso)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = aviso
        render turbo_stream: [
          # ⚠️ `update` y NO `replace`, y la diferencia costó encontrarla.
          #
          # `replace` cambia el elemento ENTERO, o sea que se lleva puesto el
          # propio `<turbo-frame id="departamentos">` y lo sustituye por el
          # contenido del parcial —que no lo incluye—. La primera acción
          # funciona y a partir de la segunda no hay a qué apuntar: agregar
          # andaba, borrar no hacía nada, y sin ningún error.
          #
          # `update` cambia el CONTENIDO y deja el frame en su sitio.
          turbo_stream.update("departamentos", partial: "departments/lista",
                                               locals: { departments: Department.order(:name) }),
          turbo_stream.replace("flash", partial: "shared/flash")
        ]
      end
      format.html { redirect_to departments_path, notice: aviso }
    end
  end

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    # `school_id` NO se permite: el colegio sale de la sesión, nunca del request (MOR-86).
    params.require(:department).permit(:name).merge(school_id: Current.school_id)
  end
end
