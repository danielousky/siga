import { Controller } from "@hotwired/stimulus"

// Los paneles de una misma pantalla (MOR-223).
//
// Daniel: *«esos dos paneles van en pestañas o pills, un clic vale más que
// muchos scroll hacia abajo… si no lo hago me pierdo de lo que está allí que no
// me aparece al cargar la vista»*.
//
// ## ⚠️ Se degrada, no se rompe
//
// Todos los paneles vienen en el HTML y se esconden con `hidden`, que el
// navegador respeta sin CSS ni JavaScript. Si este controlador no carga —y una
// aplicación Stimulus entera ya murió una vez en este proyecto, por un import
// roto— la pantalla vuelve a ser lo que era: todo apilado, con scroll. Nunca
// una pantalla vacía.
//
// Por eso `connect` empieza MOSTRANDO todo y después esconde: si el JS no llega
// a correr, el `hidden` del servidor deja solo el primero, que es la mitad de
// la información. Al revés —servidor muestra todo, JS esconde— el fallo deja
// todo visible, que es exactamente el estado anterior.
export default class extends Controller {
  static targets = ["pestana", "panel"]

  connect() {
    // El que ya venía marcado, o el primero.
    const activa = this.pestanaTargets.find((p) => p.classList.contains("activa")) ||
                   this.pestanaTargets[0]
    if (activa) this.#activar(activa.dataset.panel)
  }

  mostrar(evento) {
    this.#activar(evento.currentTarget.dataset.panel)
  }

  // Ir a un panel por su nombre, desde fuera: lo usa el enlace que lleva
  // directo a lo que falta calificar.
  irA(clave) {
    this.#activar(clave)
  }

  // ── interno ───────────────────────────────────────────────────────────────

  #activar(clave) {
    this.pestanaTargets.forEach((pestana) => {
      const suya = pestana.dataset.panel === clave
      pestana.classList.toggle("activa", suya)
      pestana.setAttribute("aria-selected", suya ? "true" : "false")
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.panel !== clave
    })
  }
}
