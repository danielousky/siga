import { Controller } from "@hotwired/stimulus"

// Copiar el enlace de activación al portapapeles (MOR-143).
//
// La secretaria lo va a pegar en WhatsApp desde su teléfono, y seleccionar a
// mano una URL de 90 caracteres en una pantalla táctil es exactamente donde se
// pierde un pedazo del token — y entonces el enlace no funciona y nadie sabe
// por qué.
//
// `navigator.clipboard` solo existe en contextos seguros. En HTTPS está; en un
// `http://` que no sea localhost, no. Por eso el enlace sigue visible y
// seleccionable: si esto no corre, no se pierde nada.
export default class extends Controller {
  static targets = ["fuente", "boton"]

  async copiar() {
    try {
      await navigator.clipboard.writeText(this.fuenteTarget.textContent.trim())
      this.avisar("Copiado")
    } catch {
      this.avisar("Copie el enlace a mano")
    }
  }

  avisar(texto) {
    const original = this.botonTarget.textContent
    this.botonTarget.textContent = texto
    setTimeout(() => { this.botonTarget.textContent = original }, 2000)
  }
}
