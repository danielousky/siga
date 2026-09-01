# Promover a los alumnos al año siguiente (MOR-169).
#
# Es el paso 3 de septiembre y el hermano de `CopiasDelAnioController`: aquella
# arma el año nuevo, esta lo llena. Por eso la ruta cuelga del año DESTINO —el
# que está vacío— y el origen viaja en el cuerpo.
#
# ## ⚠️ Exige que la estructura esté copiada
#
# Sin secciones en el año nuevo no hay dónde inscribir a nadie, y la pantalla lo
# dice con el camino de salida en vez de una lista vacía sin explicación.
class PromocionesController < ApplicationController
  before_action :require_admin_access!
  before_action :set_destino

  def new
    @origenes = candidatos
    @origen = elegido || @origenes.first
    return if @origen.nil?

    @hay_notas = PromocionDeAlumnos.hay_notas?(@origen)
    @promocion = PromocionDeAlumnos.new(@origen, @destino, promover_sin_datos: promover_sin_datos?)
    @conteo = @promocion.conteo
    @por_seccion = @promocion.propuesta.group_by(&:seccion_actual)
  end

  def create
    origen = elegido
    if origen.nil?
      return redirect_to promover_al_academic_period_path(@destino),
                         alert: "Elija de qué año escolar promover."
    end

    resultado = PromocionDeAlumnos.aplicar(origen, al: @destino, promover_sin_datos: promover_sin_datos?)
    auditar(origen, resultado)

    redirect_to enrollments_path, notice: resumen(resultado, origen)
  end

  private

  def set_destino
    @destino = AcademicPeriod.find(params[:id])
    @tiene_secciones = Section.where(academic_period_id: @destino.id).exists?
  end

  def candidatos
    AcademicPeriod.where.not(id: @destino.id).order(start_date: :desc).to_a
  end

  def elegido
    id = params[:origen_id]
    return candidatos.first if id.blank?

    candidatos.find { |a| a.id.to_s == id.to_s }
  end

  # ⚠️ Solo cuenta si viene explícito. Promover sin notas es una decisión del
  # director, no un valor por defecto: es exactamente lo que no se puede
  # deducir.
  def promover_sin_datos? = params[:sin_datos].to_s == "1"

  # ⚠️ Token propio y no `enrollment_created` treinta veces: en la pantalla que
  # contesta «¿por qué mi hijo quedó en 2do Año B?», la promoción es UN hecho —
  # quién la corrió, desde qué año, y con qué criterio— y no trescientas filas.
  def auditar(origen, resultado)
    log_activity(
      action:  "alumnos_promovidos",
      subject: @destino,
      message: "#{current_user.nombre_completo} promovió de #{origen.name} a #{@destino.name}: " \
               "#{resultado.inscritos} inscritos, #{resultado.egresados} egresados" \
               "#{' (incluyendo a los que no tenían notas cargadas)' if promover_sin_datos?}"
    )
  end

  def resumen(resultado, origen)
    return "No había a quién promover de #{origen.name}." unless resultado.hizo_algo?

    partes = []
    partes << helpers.contar(resultado.inscritos, "alumno inscrito", "alumnos inscritos") if resultado.inscritos.positive?
    partes << helpers.contar(resultado.egresados, "egresado", "egresados") if resultado.egresados.positive?

    texto = "Promovidos de #{origen.name} a #{@destino.name}: #{partes.to_sentence}."
    if resultado.salteados.positive?
      texto += " #{helpers.contar(resultado.salteados, 'alumno', 'alumnos')} sin mover."
    end
    texto
  end

  def require_admin_access!
    return if administrador? && can_manage_students?

    redirect_to dashboard_path_for_user,
                alert: "Acceso no autorizado. Esta función es solo para administradores."
  end
end
