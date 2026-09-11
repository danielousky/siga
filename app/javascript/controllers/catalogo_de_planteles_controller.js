import { Controller } from "@hotwired/stimulus"

// Sugerir el colegio mientras se escribe su nombre.
//
//     [ san jose                          ]
//     ┌──────────────────────────────────────┐
//     │ U.E.P. COLEGIO SAN JOSÉ  PD01234567  │
//     │ Distrito Capital · privado           │
//     └──────────────────────────────────────┘
//              ↓ al elegir
//     se rellenan nombre y código, Y SE PUEDEN CAMBIAR
//
// ## ⚠️ Sugiere, no decide
//
// Daniel: *«es sugerencia, no verdad»*. Lo elegido llena los campos y ahí
// termina: lo que se envía es lo que quede escrito. Por eso el código DEA
// aparece como un campo de texto normal y no como un dato fijo — y por eso no
// hay ningún «id del plantel» viajando por detrás.
//
// ⚠️ El catálogo está incompleto a propósito y eso no puede costarle el
// registro a nadie: no encontrar el colegio no bloquea nada, se sigue con lo
// que se escribió. Es la misma regla de `DivisionPolitica::OTRO`.
export default class extends Controller {
  static targets = ["nombre", "dea", "campoDelDea", "marca"]
  static values = { url: String, espera: { type: Number, default: 250 } }

  // ⚠️ Se espera a que deje de teclear. Sin esto son ocho peticiones para
  // escribir «san jose» —una por letra— y las respuestas llegan desordenadas:
  // la de «san j» puede pisar a la de «san jose».
  buscar() {
    clearTimeout(this.reloj)
    this.reloj = setTimeout(() => this.#pedir(), this.esperaValue)
  }

  elegir(evento) {
    const { nombre, dea } = evento.params

    this.nombreTarget.value = nombre
    if (dea) {
      this.deaTarget.value = dea
      this.campoDelDeaTarget.hidden = false
    }

    // Lo elegido se anuncia, y se dice que se puede cambiar: es la diferencia
    // entre rellenar y decidir.
    this.marcaTarget.hidden = false
    this.#limpiarSugerencias()
  }

  // Escribir a mano después de elegir apaga la marca: ya no es lo del catálogo.
  escribir() {
    this.marcaTarget.hidden = true
  }

  #pedir() {
    const frame = document.getElementById("sugerencias_de_planteles")
    if (!frame) return

    frame.src = `${this.urlValue}?q=${encodeURIComponent(this.nombreTarget.value.trim())}`
  }

  #limpiarSugerencias() {
    const frame = document.getElementById("sugerencias_de_planteles")
    if (frame) frame.innerHTML = ""
  }
}
