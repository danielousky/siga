import { Controller } from "@hotwired/stimulus"

// Un formulario de VARIOS campos que se corrige en su sitio, como el texto de
// Linear (26 de octubre de 2026).
//
// Daniel, ese día: *«formularios? Asíncronos (Stimulus) y que se modifiquen en
// el lugar tipo los textos de Linear»*. Es lo que `edicion-en-linea` hace con
// UN campo en el plan de evaluación; esto es lo mismo para un formulario que
// lleva varios, como una hora del timbre —«desde» y «hasta»—:
//
//     Enter     guarda
//     Escape    cierra y deja todo como estaba
//     salir     guarda, si algo cambió; si no, cierra
//
// ⚠️ «Salir» es que el foco deje el FORMULARIO, no un campo. Pasar de «desde»
// a «hasta» no guarda nada: guardaría la mitad, y una hora con el inicio nuevo
// y el final viejo puede no existir. Por eso el formulario lleva
// `tabindex="-1"`: tocar su fondo lo enfoca a él, y eso no es salir.
//
// ⚠️ Cerrar es el enlace `cerrar` —escondido—, no otro camino: la puerta por
// donde se entró la decide el servidor (`ruta_del_horario`), no el navegador.
//
//     = form_with …, tabindex: -1,
//         data: { controller: "en-su-sitio",
//                 action: "keydown->en-su-sitio#tecla focusout->en-su-sitio#salir" }
//       = link_to "…", ruta, hidden: true, data: { en_su_sitio_target: "cerrar" }
export default class extends Controller {
  static targets = ["cerrar"]

  connect() {
    this.original = this.valores()
    this.terminado = false
  }

  tecla(evento) {
    if (evento.key === "Enter") {
      evento.preventDefault()
      this.terminar()
    } else if (evento.key === "Escape") {
      evento.preventDefault()
      this.cerrar()
    }
  }

  salir(evento) {
    if (this.element.contains(evento.relatedTarget)) return

    this.terminar()
  }

  // Una sola vez: al guardar, Turbo cambia el marco y el campo enfocado
  // desaparece, que también es un `focusout`.
  terminar() {
    if (this.terminado) return
    if (this.valores() === this.original) return this.cerrar()

    // Un campo a medio escribir no se manda: se dice cuál, y sigue abierto.
    if (!this.element.checkValidity()) return this.element.reportValidity()

    this.terminado = true
    this.element.requestSubmit()
  }

  cerrar() {
    if (this.terminado) return

    this.terminado = true
    this.cerrarTarget.click()
  }

  valores() {
    return new URLSearchParams(new FormData(this.element)).toString()
  }
}
