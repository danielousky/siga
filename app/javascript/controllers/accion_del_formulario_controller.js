import { Controller } from "@hotwired/stimulus"

// Un `select` que decide A DÓNDE va el formulario (MOR-198).
//
// Hace falta cuando lo que se elige es parte de la RUTA y no del cuerpo. En la
// ficha de una materia se asigna a un grado con el mismo endpoint que usa la
// ficha del grado —`POST /grados/:grade_id/materias`—, así que el grado elegido
// tiene que viajar en la URL.
//
// Sin esto, elegir «3er Grado» mandaba igual al primero de la lista: el
// formulario nace con la URL del primero y el `select` no la toca. Es un error
// silencioso de los peores, porque la operación SÍ se completa —con un mensaje
// de éxito— sobre el grado equivocado.
//
//     = select_tag :grade_id, options_for_select(rutas),
//         data: { accion_del_formulario_target: "select",
//                 action: "change->accion-del-formulario#cambiar" }
//
// ⚠️ El valor de cada opción ES la ruta. Podría ser el id y armarse la URL acá,
// pero eso pondría la forma de las rutas de Rails dentro de un JavaScript, y el
// día que cambie el `path:` de un `resources` nadie se acordaría de este
// archivo. Con la ruta ya escrita por el helper, el cambio se propaga solo.
export default class extends Controller {
  static targets = ["select"]

  connect() {
    this.cambiar()
  }

  cambiar() {
    // El primer `select` de la lista es el que manda: en «asignar un profesor»
    // hay dos —la sección y el profesor— y solo la sección está en la ruta.
    const destino = this.selectTargets[0]?.value
    if (destino) this.element.action = destino
  }
}
