import { Controller } from "@hotwired/stimulus"

// Un formulario largo, de a un paso por vez.
//
//     ●━━━━━━━━━━━○━━━━━━━━━━━○
//     ① El colegio  ② Dónde queda  ③ Quién lo dirige
//
// ## ⚠️ Los pasos son del NAVEGADOR, no del servidor
//
// Todos los campos están en la página y el formulario se envía UNA vez. Un
// asistente por peticiones tendría que guardar el colegio a medias entre paso y
// paso —o inventar una sesión con datos sueltos— y ahí es donde aparecen los
// registros incompletos que nadie termina. Acá, o se crea entero o no se crea.
//
// ⚠️ Y por eso la validación de cada paso es la NATIVA: `checkValidity()` sobre
// los campos de ese paso. Avanzar con el nombre vacío y descubrirlo en el paso
// tres es exactamente lo que un asistente viene a evitar.
export default class extends Controller {
  static targets = ["paso", "punto", "atras", "siguiente", "enviar", "cuenta"]

  connect() {
    this.actual = 0
    this.#pintar()
  }

  siguiente() {
    // ⚠️ `reportValidity` y no `checkValidity` a secas: el primero además
    // MUESTRA el globo del navegador sobre el campo que falta. Sin eso, el
    // botón «Siguiente» simplemente no hace nada y parece roto.
    if (!this.#valido(this.pasoTargets[this.actual])) return

    this.actual = Math.min(this.actual + 1, this.pasoTargets.length - 1)
    this.#pintar()
  }

  atras() {
    this.actual = Math.max(this.actual - 1, 0)
    this.#pintar()
  }

  #valido(paso) {
    const campos = [ ...paso.querySelectorAll("input, select, textarea") ]

    return campos.every((campo) => campo.reportValidity())
  }

  #pintar() {
    this.pasoTargets.forEach((paso, i) => { paso.hidden = i !== this.actual })
    this.puntoTargets.forEach((punto, i) => {
      punto.classList.toggle("pasos-punto--actual", i === this.actual)
      punto.classList.toggle("pasos-punto--hecho", i < this.actual)
    })

    const ultimo = this.actual === this.pasoTargets.length - 1
    this.atrasTarget.hidden = this.actual === 0
    this.siguienteTarget.hidden = ultimo
    this.enviarTarget.hidden = !ultimo
    this.cuentaTarget.textContent = `Paso ${this.actual + 1} de ${this.pasoTargets.length}`

    // ⚠️ El foco al primer campo del paso: sin esto, quien navega con teclado
    // se queda en el botón «Siguiente» mientras la pantalla ya cambió.
    this.pasoTargets[this.actual].querySelector("input, select, textarea")?.focus()
  }
}
