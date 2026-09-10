import { Controller } from "@hotwired/stimulus"

// Un `<details>` que se cierra como un menú (QA del 9 de septiembre).
//
// Daniel, con una captura del panel abierto encima de la fila siguiente: *«clic
// fuera del elemento destruye la acción»*.
//
// ⚠️ Un `<details>` nativo NO se cierra al hacer clic fuera — solo con su
// propio `<summary>`. Como su panel es `position: absolute`, quedaba flotando
// sobre lo que hubiera debajo: quien se iba con el ratón lo dejaba puesto
// tapando la evaluación de abajo, y el tooltip del botón encima.
//
// Es el mismo cierre que ya tiene el calendario escolar, y por la misma razón:
// un panel que solo se cierra con su propio botón atrapa a quien ya se fue.
export default class extends Controller {
  connect() {
    this.fuera = (evento) => {
      // `composedPath()` y no `contains(target)`: si el clic cayó sobre algo que
      // el propio panel reemplaza, ese nodo ya no está en el árbol cuando este
      // listener corre, y `contains` diría que el clic vino de fuera.
      if (!evento.composedPath().includes(this.element)) this.cerrar()
    }
    this.escape = (evento) => {
      if (evento.key === "Escape") this.cerrar()
    }

    document.addEventListener("click", this.fuera)
    document.addEventListener("keydown", this.escape)
  }

  disconnect() {
    document.removeEventListener("click", this.fuera)
    document.removeEventListener("keydown", this.escape)
  }

  cerrar() {
    if (this.element.open) this.element.open = false
  }
}
