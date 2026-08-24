# Traer la matrícula de un colegio desde una planilla (MOR-126).
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
#     confirmar    escribir                          ← todavía no
class ImportacionesController < ApplicationController
  before_action :require_puede_gestionar!
  before_action :set_importacion, only: [ :show, :update, :destroy ]

  def index
    @pagy, @importaciones = pagy(Importacion.includes(:subido_por).recientes)
  end

  # La planilla en blanco, con su hoja de instrucciones. Se descarga ANTES de
  # que exista ninguna importación, así que no cuelga de ninguna.
  def plantilla
    hoja = PlantillaDeMatricula.new(colegio: Current.school)

    send_data hoja.to_stream.read,
              filename: hoja.nombre_de_archivo,
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def new
    @importacion = Importacion.new
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
      filas_leidas: hoja.filas.size
    )

    return rechazar(@importacion.errors.full_messages.to_sentence) unless @importacion.save

    @importacion.archivo.attach(archivo)

    redirect_to @importacion, notice: "Planilla cargada. Revise cómo quedaron las columnas."
  rescue Planilla::NoSePuedeLeer => e
    rechazar(e.message)
  end

  def show
    @columnas = ColumnasDeMatricula::TODAS
    @mapeo = @importacion.mapeo_efectivo
    @muestra = @importacion.planilla.filas.first
  rescue Planilla::NoSePuedeLeer => e
    redirect_to importaciones_path, alert: e.message
  end

  # Guarda qué columna del archivo es cuál campo nuestro. No escribe nada de la
  # matrícula todavía.
  def update
    @importacion.mapeo = mapeo_desde_el_formulario
    @importacion.estado = :mapeada if @importacion.lista_para_previsualizar?

    if @importacion.save
      redirect_to @importacion, notice: "Mapeo guardado."
    else
      redirect_to @importacion, alert: @importacion.errors.full_messages.to_sentence
    end
  end

  def destroy
    @importacion.archivo.purge_later
    @importacion.update(estado: :descartada)

    redirect_to importaciones_path, notice: "Importación descartada."
  end

  private

  def rechazar(mensaje)
    @importacion ||= Importacion.new
    flash.now[:alert] = mensaje
    render :new, status: :unprocessable_entity
  end

  # El formulario manda `{ "APELLIDOS Y NOMBRES" => "nombre_completo" }`. Las
  # que la persona dejó en "no importar" llegan vacías y se descartan: guardar
  # `=> ""` haría que `mapeo_efectivo` las contara como mapeadas a nada.
  def mapeo_desde_el_formulario
    params.fetch(:mapeo, {}).permit!.to_h.compact_blank
  end

  def set_importacion
    @importacion = Importacion.find(params[:id])
  end

  def require_puede_gestionar!
    return if can_manage_students?

    redirect_to dashboard_path_for_user, alert: "No tienes permiso para importar matrícula."
  end
end
