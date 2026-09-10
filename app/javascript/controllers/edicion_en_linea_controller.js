import { Controller } from "@hotwired/stimulus"

// Editar donde se lee, sin botón de guardar (QA del 9 de septiembre).
//
// Daniel: *«al hacer clic en el elemento que deseo editar, como lo hace
// Linear»*. Y con eso el lápiz se retiró — era justamente él lo que hacía
// pensar que había que pasar por otra pantalla.
//
//     Enter        guarda y suelta el foco
//     Escape       descarta y deja el valor que había
//     salir        guarda, si algo cambió
//
// ⚠️ Se guarda al SALIR y no en cada tecla. Escribiendo «Taller de mapas», un
// guardado por tecla son quince peticiones, quince recálculos de promedios y
// quince entradas en la auditoría — que es la bitácora de quién cambió qué.
//
// ⚠️ Y solo si CAMBIÓ. Entrar a un campo, mirarlo y salir no es editar; sin
// esa comprobación, tabular por la fila deja tres guardados y tres líneas en la
// auditoría de una evaluación que nadie tocó.
export default class extends Controller {
  static targets = ["campo"]

  connect() {
    this.guardado = this.campoTarget.value
  }

  tecla(evento) {
    if (evento.key === "Enter") {
      evento.preventDefault()
      // El `blur` dispara `salir`, que es quien guarda: así hay UN camino de
      // guardado y no dos que puedan separarse.
      return this.campoTarget.blur()
    }

    if (evento.key !== "Escape") return

    evento.preventDefault()
    this.campoTarget.value = this.guardado
    this.campoTarget.blur()
  }

  salir() {
    const valor = this.campoTarget.value.trim()

    // Vaciar el nombre no es «borrarlo»: es un dedazo. Se restaura y ya —
    // borrar la evaluación tiene su propio botón, con su confirmación.
    if (valor === "") {
      this.campoTarget.value = this.guardado
      return
    }
    if (valor === this.guardado) return

    this.guardado = valor
    this.element.requestSubmit()
  }
}
