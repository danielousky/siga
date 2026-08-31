# La ayuda que aparece SOLO cuando alguien la pide (MOR-161).
#
# ## El problema
#
# Cada campo llevaba dos renglones de gris debajo, siempre visibles. Ciento dos
# en cincuenta y tres pantallas. Eso no es guiar: es ruido permanente, y tiene
# el mismo modo de fallar que ya está escrito en el panel del director —*«un
# panel que siempre dice lo mismo se deja de leer, y el día que dice otra cosa
# tampoco se lee»*—. Un formulario donde todo grita, no dice nada.
#
# Daniel lo puso como principio: **guiar cuando el usuario lo demande, solo
# cuando sea necesario.**
#
# ## Las tres cosas que se confundían bajo un mismo `.nota-ayuda`
#
#     QUÉ ES ESTO      «El código DEA lo asigna el ministerio»
#                      → `pista`: un «?» al lado de la etiqueta
#
#     QUÉ PASA SI…     «Sin guía, la asistencia solo la toma la dirección»
#                      → se queda visible: es una CONSECUENCIA, no una
#                        definición, y quien no la lea toma una decisión a ciegas
#
#     CÓMO SE ESCRIBE  «0212-555-1234»
#                      → `placeholder`, no un párrafo
#
# ## Por qué `popover` nativo y no un controlador de Stimulus
#
# El navegador ya sabe hacer esto, y lo hace mejor: cerrar al tocar afuera,
# cerrar con `esc`, y dibujarse en la capa superior —o sea que **no lo recorta
# ningún `overflow`**, que es exactamente lo que rompe a un tooltip metido en un
# formulario—. Todo eso son cero líneas de JavaScript.
#
# El anclaje al botón necesita `anchor-positioning`, que todavía no está en
# todos los navegadores; donde no está, la tarjeta se centra. Es un degradado
# aceptable: se sigue leyendo, se sigue cerrando.
module PistasHelper
  # Un «?» junto a la etiqueta. El texto aparece al tocarlo y se va solo.
  #
  # El id sale del texto y no de un aleatorio: así una misma pista renderizada
  # dos veces no cambia de id entre peticiones, que rompería cualquier test que
  # la busque por selector.
  def pista(texto, etiqueta: "Qué es esto")
    id = "pista-#{Digest::SHA256.hexdigest(texto.to_s)[0, 10]}"

    tag.span class: "pista" do
      safe_join([
        tag.button(icono(:info, tamano: 14), type: "button", class: "pista-boton",
                                             popovertarget: id, "aria-label": etiqueta),
        tag.div(texto, id: id, popover: "auto", class: "pista-texto")
      ])
    end
  end

  # Un bloque de «por qué el sistema funciona así», plegado (MOR-161).
  #
  # Es el hermano de `pista` para el texto que NO cuelga de un campo: la sección
  # que explica por qué la constancia no se archiva como el boletín, o por qué
  # una falta justificada no cuenta igual. Son explicaciones buenas y **se leen
  # una vez** — la número treinta que abre esa pantalla ya sabe la respuesta.
  #
  # ⚠️ `<details>` nativo, como los grupos del menú: anda sin JavaScript,
  # responde al teclado solo, y no hay un estado paralelo que se pueda
  # desincronizar con lo que se ve.
  #
  #     = mas_detalle "Por qué esta no se guarda como el boletín" do
  #       %p El boletín certifica calificaciones…
  def mas_detalle(resumen, &bloque)
    tag.details class: "mas-detalle" do
      safe_join([ tag.summary(resumen, class: "mas-detalle-resumen"),
                  tag.div(capture(&bloque), class: "mas-detalle-cuerpo") ])
    end
  end

  # Le pone el «?» a CUALQUIER etiqueta, venga de donde venga.
  #
  #     = con_pista "El profesor entra con este correo" do
  #       = f.label :email, class: "form-label"
  #
  # Es la forma general porque en este proyecto conviven las dos maneras de
  # escribir una etiqueta —`f.label` en los formularios con modelo, `label_tag`
  # en los que crean dos cosas a la vez— y un helper que solo sirva para una
  # obliga a reescribir el formulario para poder explicar un campo.
  #
  # ⚠️ El «?» va junto a la ETIQUETA y no al campo: quien no sabe qué es algo lo
  # descubre leyendo su nombre, y ahí es donde busca la explicación.
  def con_pista(texto, &bloque)
    tag.div safe_join([ capture(&bloque), pista(texto) ]), class: "form-etiqueta"
  end

  # El atajo para `label_tag`, que es como se escriben los formularios sin
  # modelo. Se apoya en `con_pista`: un solo motor, dos maneras de llamarlo.
  def etiqueta_con_pista(nombre, texto, pista:, **opciones)
    con_pista(pista) { label_tag(nombre, texto, class: "form-label", **opciones) }
  end
end
