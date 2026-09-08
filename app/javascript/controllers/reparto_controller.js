import { Controller } from "@hotwired/stimulus"

// El reparto del lapso, moviéndose como un todo (QA del 8 de septiembre).
//
// Daniel: *«ese porcentaje debería estar directamente aquí y moverse
// dinámicamente unos con otros, de modo que vea cuánto % llevo y cuánto % me
// queda… no ver el porcentaje aislado sino como un todo»*.
//
//     ████████ Taller 30 ██ Part. 5 ███████████ Examen 40 ░░ queda 25 ░░
//        ▲                                                      ▲
//        └── se ensancha al escribir                            └── se encoge
//
// ⚠️ Los otros pesos NO se reajustan solos, y es a propósito. Bajar el taller
// para que quepa el examen es una decisión del profesor: hacerlo por él le
// cambia en silencio el peso de una evaluación que puede tener treinta notas
// cargadas, y con ellas los promedios de la sección entera. Lo que sí se hace
// es que VEA el efecto antes de guardar.
export default class extends Controller {
  static targets = ["peso", "tramo", "hueco", "cuenta", "boton", "exceso", "barra"]
  static values  = { total: Number }

  connect() {
    this.inicial = this.#pesos()
    this.recalcular()
  }

  recalcular() {
    const pesos = this.#pesos()
    const total = pesos.reduce((suma, { valor }) => suma + valor, 0)

    this.#pintarLosTramos(pesos, total)
    this.#pintarLaCuenta(total)
    this.#pintarElBoton(pesos, total)
  }

  // ⚠️ El exceso se recorta al SALIR del campo, no al escribir: recortando
  // mientras se teclea, escribir «40» en un hueco de 25 convierte el 4 en 25 y
  // el resultado es «254».
  ajustar(evento) {
    const campo = evento.target
    const otros = this.#pesos()
      .filter((p) => p.campo !== campo)
      .reduce((suma, { valor }) => suma + valor, 0)
    const tope = Math.max(100 - otros, 0)

    if (Number(campo.value) > tope) campo.value = this.#numero(tope)
    this.recalcular()
  }

  #pesos() {
    return this.pesoTargets.map((campo) => ({
      id: campo.dataset.id,
      campo,
      valor: Number(campo.value) || 0
    }))
  }

  #pintarLosTramos(pesos, total) {
    // Pasado el 100 %, los tramos se dibujan proporcionales a la SUMA y no al
    // 100: si no, la barra se desborda del contenedor y el exceso —que es
    // justo lo que hay que ver— queda fuera de la pantalla.
    const escala = total > 100 ? 100 / total : 1

    pesos.forEach(({ id, valor }) => {
      const tramo = this.tramoTargets.find((t) => t.dataset.id === id)
      if (!tramo) return

      tramo.style.width = `${valor * escala}%`
      tramo.classList.toggle("plan-ponderacion-tramo--excedido", total > 100)
    })

    if (this.hasHuecoTarget) this.huecoTarget.style.width = `${Math.max(100 - total, 0)}%`
    if (this.hasBarraTarget) this.barraTarget.classList.toggle("plan-ponderacion-barra--excedida", total > 100)
  }

  #pintarLaCuenta(total) {
    if (!this.hasCuentaTarget) return

    const resto = 100 - total
    this.cuentaTarget.textContent = `${this.#numero(total)} %`
    this.cuentaTarget.classList.toggle("plan-ponderacion-cuenta--excedida", total > 100)

    if (resto === 0) return this.#agregarResto("· cierra en 100 %", "ok")
    if (resto > 0) return this.#agregarResto(`· ${this.#numero(resto)} % sin repartir`, "resto")

    this.#agregarResto(`· se pasa por ${this.#numero(-resto)} %`, "exceso")
  }

  #agregarResto(texto, tono) {
    const span = document.createElement("span")
    span.className = `plan-ponderacion-resto plan-ponderacion-resto--${tono}`
    span.textContent = texto
    this.cuentaTarget.appendChild(span)
  }

  // El botón aparece solo cuando algo cambió: uno que no tiene nada que
  // guardar invita a apretarlo para averiguar qué hace.
  #pintarElBoton(pesos, total) {
    if (!this.hasBotonTarget) return

    const cambio = pesos.some(({ id, valor }) => valor !== this.#inicialDe(id))
    this.botonTarget.hidden = !cambio || total > 100

    if (!this.hasExcesoTarget) return
    this.excesoTarget.hidden = total <= 100
    this.excesoTarget.textContent = total > 100
      ? `Quita ${this.#numero(total - 100)} % de algún lado para poder guardar.`
      : ""
  }

  #inicialDe(id) {
    return (this.inicial.find((p) => p.id === id) || { valor: 0 }).valor
  }

  #numero(valor) {
    return Number.isInteger(valor) ? valor : Number(valor.toFixed(2))
  }
}
