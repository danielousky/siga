# La franja que mantiene el hilo de la puesta en marcha (MOR-154).
#
# ## El problema que resuelve
#
# El mapa vive en el panel y cada paso enlaza a la pantalla real —`/subjects`,
# `/sections`—. Sin nada más, esa pantalla no tiene idea de que la persona venía
# de un recorrido: carga las veintidós materias y queda parada en una lista
# genérica, sin salida. Es el mismo callejón que el importador ya había
# identificado como su peor error.
#
# La franja es una línea de 44 px que dice dónde está y cómo vuelve.
#
# ## ⚠️ El parámetro se CONSUME y la URL queda limpia
#
# El paso entra como `?recorrido=materias`, se guarda en una cookie y se
# redirige a `/subjects` a secas. Dos razones:
#
#   · la URL que la secretaria copia y manda por WhatsApp es `/subjects`, no una
#     con basura pegada;
#   · el recorrido sobrevive a navegar por dentro —`/subjects/new`, editar,
#     volver— sin arrastrar query strings por toda la app.
#
# ## Y por qué una cookie y no la sesión
#
# Por lo mismo que el menú plegado: el servidor dibuja la franja, así que tiene
# que saberlo antes de renderizar. Dura 30 días y si se pierde no pasa nada —el
# panel deduce el siguiente pendiente y sigue—. No es estado del arranque: es
# «por dónde ibas», que es de la persona y de su navegador.
module LlevaElRecorrido
  extend ActiveSupport::Concern

  CLAVE = :recorrido_de_arranque
  DURACION = 30.days

  included do
    before_action :consumir_el_recorrido
    helper_method :recorrido_activo?, :paso_del_recorrido, :pasos_del_recorrido,
                  :siguiente_paso_del_recorrido
  end

  private

  def consumir_el_recorrido
    return unless request.get?

    pedido = params[:recorrido].presence
    return if pedido.nil?

    if pedido == "salir"
      cookies.delete(CLAVE)
    else
      cookies[CLAVE] = { value: pedido, expires: DURACION.from_now, same_site: :lax }
    end

    redirect_to url_for(request.query_parameters.except("recorrido").merge(only_path: true))
  end

  # La franja se muestra solo si hay un recorrido guardado Y el colegio sigue
  # arrancando: cuando termina, desaparece sola sin que nadie la apague.
  def recorrido_activo?
    return false unless respond_to?(:current_user) && Current.school && administrador?
    return false if cookies[CLAVE].blank?
    # ⚠️ En el panel NO: el mapa completo ya está ahí abajo, así que «Volver al
    # plan» apuntaría a la página en la que ya estás. Un enlace que no lleva a
    # ningún lado enseña que los enlaces de este sistema a veces no funcionan.
    return false if controller_path == "dashboards/administrador"

    pasos_del_recorrido.any? { |p| !p.listo? && !p.opcional? }
  end

  def pasos_del_recorrido
    @pasos_del_recorrido ||= PasosDeArranque.para(Current.school)
  end

  # El paso por el que iba. `nil` si la cookie quedó con una clave que ya no
  # existe —se renombró un paso— y ahí la franja muestra el recorrido sin
  # nombrar ninguno, en vez de reventar.
  def paso_del_recorrido
    pasos_del_recorrido.find { |p| p.clave.to_s == cookies[CLAVE] }
  end

  # A dónde lleva «Listo, seguir». ⚠️ NO marca nada: es navegación. Si alguien
  # lo presiona sin hacer el trabajo, el paso queda pendiente y el panel lo dice
  # — que es la forma honesta de dejar saltar adelante sin mentir sobre el estado.
  def siguiente_paso_del_recorrido
    pendientes = pasos_del_recorrido.reject { |p| p.listo? || p.opcional? }
    actual = paso_del_recorrido

    pendientes.find { |p| p.clave != actual&.clave } || pendientes.first
  end
end
