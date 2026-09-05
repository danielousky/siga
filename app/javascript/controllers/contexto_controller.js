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

  connect() {
    this._alTocarAfuera = this._alTocarAfuera.bind(this)
    this._alPresionar = this._alPresionar.bind(this)
  }

  disconnect() {
    this.#dejarDeEscuchar()
  }

  alTogglear() {
    if (this.element.open) {
      // `click` y no `mousedown`: con `mousedown` el panel se cierra antes de
      // que el botón de adentro reciba su clic, y elegir un año no hacía nada.
      document.addEventListener("click", this._alTocarAfuera)
      document.addEventListener("keydown", this._alPresionar)
    } else {
      this.#dejarDeEscuchar()
    }
  }

  _alTocarAfuera(evento) {
    if (this.element.contains(evento.target)) return
    this.#cerrar()
  }

  _alPresionar(evento) {
    if (evento.key !== "Escape") return
    this.#cerrar()
    // El foco vuelve a la pastilla: cerrar con Escape y quedarse sin foco deja
    // a quien navega con teclado al principio del documento.
    this.element.querySelector("summary")?.focus()
  }

  #cerrar() {
    this.element.open = false
    this.#dejarDeEscuchar()
  }

  #dejarDeEscuchar() {
    document.removeEventListener("click", this._alTocarAfuera)
    document.removeEventListener("keydown", this._alPresionar)
  }
}
