import { Controller } from "@hotwired/stimulus"

// Mostrar/ocultar la contraseña.
//
// Antes esto alternaba las clases `fa-eye` / `fa-eye-slash` de Font Awesome, que
// era la única razón por la que TODA la app cargaba esa hoja desde un CDN en
// cada página. Ahora hay dos SVG en línea y se alterna cuál está oculto
// (MOR-134).
export default class extends Controller {
  static targets = ["input", "button", "iconoMostrar", "iconoOcultar"]

  toggle() {
    const mostrar = this.inputTarget.type === "password"

    this.inputTarget.type = mostrar ? "text" : "password"

    // Se ve el ojo tachado cuando la contraseña está a la vista: el ícono
    // anuncia lo que va a pasar al hacer clic, no el estado actual.
    this.iconoMostrarTarget.hidden = mostrar
    this.iconoOcultarTarget.hidden = !mostrar

    this.buttonTarget.setAttribute("aria-label", mostrar ? "Ocultar contraseña" : "Mostrar contraseña")
    this.buttonTarget.setAttribute("aria-pressed", mostrar ? "true" : "false")
  }
}
