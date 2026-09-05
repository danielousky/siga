import { Controller } from "@hotwired/stimulus"

// El panel de «sobre qué estás trabajando» (MOR-223).
//
// ⚠️ El control es un `<details>` NATIVO, y este controlador solo agrega lo que
// el nativo no trae: cerrar con Escape y cerrar al tocar afuera.
//
// Esa división importa. Si el JavaScript no carga —o si un import roto mata la
// aplicación Stimulus entera, que ya pasó— el panel sigue abriendo, cerrando y
// respondiendo al teclado, y los formularios de adentro siguen enviando. Lo
// único que se pierde son dos comodidades. Con un menú hecho a mano se habría
// perdido el control de elegir año y nivel, que es el pivote de la app.
export default class extends Controller {
  static targets = ["panel"]

  // ⚠️ Los listeners se ponen en `connect`, NO al abrir el panel.
  //
  // Estuvieron colgados del evento `toggle`, y el `toggle` es ASÍNCRONO: el
  // navegador lo dispara después de actualizar el estado, así que entre abrir
  // el panel y tener el listener puesto hay una ventana. Un Escape que llegue
  // ahí no cierra nada.
  //
  // Un humano no presiona Escape en veinte milisegundos, pero un test sí — y
  // fallaba una de cada cinco corridas. Que el test lo destape no lo vuelve un
  // problema del test: es una ventana real, y la forma de no tenerla es no
  // depender de cuándo se registró el oyente.
  //
  // El costo es un par de listeners por página, sobre un solo elemento. Cada
  // uno sale en la primera línea si el panel está cerrado.
  connect() {
    this._alTocarAfuera = this._alTocarAfuera.bind(this)
    this._alPresionar = this._alPresionar.bind(this)

    // `click` y no `mousedown`: con `mousedown` el panel se cerraría antes de
    // que el botón de adentro reciba su clic, y elegir un año no haría nada.
    document.addEventListener("click", this._alTocarAfuera)
    document.addEventListener("keydown", this._alPresionar)
  }

  disconnect() {
    document.removeEventListener("click", this._alTocarAfuera)
    document.removeEventListener("keydown", this._alPresionar)
  }

  _alTocarAfuera(evento) {
    if (!this.element.open) return
    if (this.element.contains(evento.target)) return

    this.element.open = false
  }

  _alPresionar(evento) {
    if (!this.element.open || evento.key !== "Escape") return

    this.element.open = false
    // El foco vuelve a la pastilla: cerrar con Escape y quedarse sin foco deja
    // a quien navega con teclado al principio del documento.
    this.element.querySelector("summary")?.focus()
  }
}
