import { Controller } from "@hotwired/stimulus"

// Lo que se va, se va suave (23 de septiembre).
//
// Daniel: *«puedes suavizar la entrada y salida de los elementos al agregar o
// quitar (fade-in fade-out)»*.
//
// ## ⚠️ La entrada la hace el CSS; la salida no puede
//
// Lo que APARECE se anima solo: una `animation` corre cuando el elemento entra
// al DOM. Lo que SE VA no tiene ese momento — Turbo reemplaza el bloque y el
// nodo desaparece de golpe, sin pasar por ningún estado intermedio. Así que el
// desvanecido hay que EMPEZARLO ANTES, mientras la petición viaja, y el
// reemplazo llega encima de una fila que ya se apagó.
//
// ⚠️ El momento es `turbo:submit-start` y NO el clic: entre los dos está el
// «¿Borrar…?». Desvaneciendo al hacer clic, decir que no dejaría la fila medio
// borrada en pantalla. Donde no hay confirmación —descartar el alta, que es un
// enlace— el clic SÍ es el momento.
//
//     form: { data: { controller: "se-desvanece",
//                     se_desvanece_de_value: ".plan-evaluacion",
//                     action: "turbo:submit-start->se-desvanece#irse" } }
//
// ⚠️ `de` es el ANCESTRO que se va, no el botón: lo que desaparece es la fila,
// y el botón es solo quien lo pide. Sin `de`, se desvanece el elemento mismo.
export default class extends Controller {
  static values = { de: String }

  irse() {
    const elemento = this.hasDeValue ? this.element.closest(this.deValue) : this.element

    elemento?.classList.add("se-esta-yendo")
  }
}
