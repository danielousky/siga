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
  static targets = ["peso", "tramo", "hueco", "cuenta", "barra"]

  connect() {
    this.recalcular()
  }

  recalcular() {
    const pesos = this.#pesos()
    const total = pesos.reduce((suma, { valor }) => suma + valor, 0)

    this.#sincronizarLasCopias()
    this.#pintarLosTramos(pesos, total)
    this.#pintarLaCuenta(total)
    this.#toparLosCampos(pesos)
  }

  // ⚠️ Escribir en una copia mueve la otra: son el MISMO dato.
  //
  // Con la evaluación bajo dos competencias, cambiar su peso arriba dejaba el
  // campo de abajo con el valor viejo —27 y 22 en la misma pantalla— y ninguno
  // de los dos era mentira por sí solo: los dos decían lo que tenían escrito.
  #sincronizarLasCopias() {
    const activo = document.activeElement

    this.#todosLosCampos().forEach(({ id, campo }) => {
      if (campo === activo) return

      const fuente = this.#todosLosCampos().find((otro) => otro.id === id && otro.campo === activo)
      if (fuente) campo.value = fuente.campo.value
    })
  }

  // ⚠️ El `max` de cada campo es lo que QUEDA contando a los otros, no 100.
  //
  // Daniel: «el % editable con atributos step=1, min=1 y max=100 (o el valor
  // máximo que corresponda)». El que corresponde depende de lo que valgan las
  // demás en este momento, así que se recalcula al escribir: el error no se
  // rechaza al guardar, se vuelve imposible de teclear.
  #toparLosCampos(pesos) {
    pesos.forEach(({ campo, valor }) => {
      const otros = pesos.reduce((suma, p) => suma + (p.campo === campo ? 0 : p.valor), 0)
      campo.max = Math.max(100 - otros, valor, 1)
    })
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

  // ⚠️ Una evaluación cuenta UNA VEZ, aunque tenga varios campos.
  //
  // Una que mide dos competencias se dibuja dos veces —a propósito— y con ella
  // su campo de peso. Sumando los campos, su 28 % contaba 56 y la barra decía
  // 128 % con el lapso cerrado en 100. Lo encontró Daniel el 9 de septiembre.
  //
  // Se agrupa por el id de la EVALUACIÓN, que es de lo que el 100 % está hecho:
  // los campos son cuántas veces se ve, no cuántas evaluaciones hay.
  #pesos() {
    const vistos = new Set()

    return this.#todosLosCampos().filter(({ id }) => {
      if (vistos.has(id)) return false

      vistos.add(id)
      return true
    })
  }

  // Todas las apariciones, sin agrupar: lo que hay que MOVER al pintar, porque
  // cada copia tiene su propio tramo y su propio tope.
  #todosLosCampos() {
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
      // Un tramo por EVALUACIÓN, no por campo: la barra mide el reparto del
      // lapso, no cuántas veces se ve cada evaluación en la lista.
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

  #numero(valor) {
    return Number.isInteger(valor) ? valor : Number(valor.toFixed(2))
  }
}
