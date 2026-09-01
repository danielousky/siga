# Copiar la estructura de un año escolar al siguiente (MOR-166).
#
# ## Por qué es un controller aparte y no una acción de `AcademicPeriodsController`
#
# Porque no es una operación sobre el año: es una operación **entre dos años**,
# con su propia previsualización y su propia confirmación. Meterla adentro
# obligaba a `AcademicPeriodsController` a tener un `new` que no crea un año y un
# `create` que no crea un año.
#
# ## El año DESTINO manda
#
# La ruta cuelga del año que recibe (`/academic_periods/:id/copiar`) porque es el
# que está vacío y es donde está parado el director. El origen se elige en la
# pantalla y viaja en el cuerpo.
#
# ⚠️ El origen se busca CON el `default_scope` de `SchoolScoped`: un id de otro
# colegio simplemente no encuentra nada. La comprobación la hace el aislamiento,
# no un `if` — y `CopiarLaEstructura` la repite por su cuenta, porque un servicio
# se puede llamar desde una consola o una tarea.
class CopiasDelAnioController < ApplicationController
  before_action :require_admin_access!
  before_action :set_destino

  def new
    @origenes = candidatos
    @origen = elegido || @origenes.first
    @cuanto = @origen ? CopiarLaEstructura.cuanto_hay(@origen) : nil
  end

  def create
    origen = elegido
    if origen.nil?
      return redirect_to copiar_al_academic_period_path(@destino),
                         alert: "Elija de qué año escolar copiar la estructura."
    end

    resultado = CopiarLaEstructura.de(origen, al: @destino)

    # ⚠️ `log_activity` y no `registrar_cambio`: el atajo escribe «Fulano
    # actualizó el año escolar 2026-2027», que es falso. Nadie editó el año — se
    # trajeron secciones y asignaciones de otro. En la auditoría, que es donde
    # se contesta «¿quién hizo esto?», la diferencia es todo.
    log_activity(
      action:  "estructura_copiada",
      subject: @destino,
      message: "#{current_user.nombre_completo} copió a #{@destino.name} la estructura de " \
               "#{origen.name}: #{resultado.secciones.size} secciones y " \
               "#{resultado.asignaciones} asignaciones de profesor"
    )

    redirect_to sections_path, notice: resumen(resultado, origen)
  end

  private

  # El mismo permiso que crear o editar un año escolar: copiar la estructura es
  # configuración académica.
  def require_admin_access!
    return if administrador? && can_manage_academic_config?

    redirect_to dashboard_path_for_user,
                alert: "Acceso no autorizado. Esta función es solo para administradores."
  end

  def set_destino
    @destino = AcademicPeriod.find(params[:id])
  end

  # Los años de los que se puede copiar: cualquiera menos él mismo, del más
  # nuevo al más viejo — el de al lado es el que casi siempre se quiere.
  def candidatos
    AcademicPeriod.where.not(id: @destino.id).order(start_date: :desc).to_a
  end

  def elegido
    id = params[:origen_id]
    candidatos.find { |a| a.id.to_s == id.to_s } if id.present?
  end

  # ⚠️ El aviso dice lo que PASÓ, con números, no «listo».
  #
  # Copiar crea decenas de filas que nadie va a contar a mano; si el mensaje no
  # las nombra, la única manera de saber si funcionó es recorrer las secciones.
  def resumen(resultado, origen)
    # ⚠️ `contar` y no `pluralize`: el inflector de Rails es INGLÉS y acá acierta
    # por casualidad. `"sección".pluralize` da «sección» —ni la pluraliza— y
    # `"estaba".pluralize(2)` da «estabas». El helper con las dos formas escritas
    # ya existía en `ApplicationHelper`; ver su comentario.
    ya = resultado.ya_estaban.size

    partes = []
    partes << helpers.contar(resultado.secciones.size, "sección nueva", "secciones nuevas") if resultado.secciones.any?
    partes << "#{helpers.contar(ya, 'sección', 'secciones')} que ya #{helpers.pluralizar(ya, 'estaba', 'estaban')}" if ya.positive?
    partes << helpers.contar(resultado.asignaciones, "asignación de profesor", "asignaciones de profesor") if resultado.asignaciones.positive?

    return "No había nada que copiar de #{origen.name}." if partes.empty?

    texto = "Copiado de #{origen.name}: #{partes.to_sentence}."
    if resultado.avisos.any?
      cuantos = resultado.avisos.size
      texto += " #{helpers.contar(cuantos, 'asignación', 'asignaciones')} no se " \
               "#{helpers.pluralizar(cuantos, 'pudo', 'pudieron')} recrear."
    end
    texto
  end
end
