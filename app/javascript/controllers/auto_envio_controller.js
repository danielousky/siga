import { Controller } from "@hotwired/stimulus"

// Envía el formulario apenas cambia un campo, sin botón de por medio.
//
// Para los selectores que solo sirven para recargar la pantalla con otro
// recorte —elegir la sección de la que se van a emitir boletines, por ejemplo—.
// Un botón "Aplicar" al lado de un `select` es un clic que no aporta nada.
//
// ⚠️ `con` es el botón con el que se envía, cuando NO es el principal del
// formulario. El alta de un turno lo usa para pedir la vista previa —«Así
// queda»— con el botón que la pide a `new` por GET y solo para su marco, en vez
// de registrar el turno a mitad de escribirlo (ver `bell_schedules/_form`).
// Sin `con`, se envía como siempre.
export default class extends Controller {
  static targets = ["con"]

  enviar() {
    if (this.hasConTarget) {
      this.element.requestSubmit(this.conTarget)
    } else {
      this.element.requestSubmit()
    }
  }
}
