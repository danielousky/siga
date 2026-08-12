import { Controller } from "@hotwired/stimulus"

// Envía el formulario apenas cambia un campo, sin botón de por medio.
//
// Para los selectores que solo sirven para recargar la pantalla con otro
// recorte —elegir la sección de la que se van a emitir boletines, por ejemplo—.
// Un botón "Aplicar" al lado de un `select` es un clic que no aporta nada.
export default class extends Controller {
  enviar() {
    this.element.requestSubmit()
  }
}
