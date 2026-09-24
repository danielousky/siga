import { Controller } from "@hotwired/stimulus"

// Un calendario que solo conoce el año escolar (QA del 9 de septiembre).
//
// Daniel: *«el año es un elemento distractor — no se va a hacer una evaluación
// fuera del año y meses escolares»*.
//
//     SEP  oct  nov  dic  ene  feb  mar  abr  may  jun  jul
//     ───
//      L   M   M   J   V   S   D
//      1   2   3  ...                    ← apagados hasta el 15 de septiembre
//
// ⚠️ No se usa `<input type="date">`: su calendario es el del sistema
// operativo, trae selector de año y no hay forma de acotarle los meses. `min` y
// `max` grisan los días pero el año sigue ahí, invitando a irse a 2031.
export default class extends Controller {
  static targets = ["boton", "panel", "meses", "dias", "campo", "formulario", "hoy"]
  static values  = { desde: String, hasta: String, valor: String }

  // ⚠️ Los meses en MINÚSCULA y el CSS los pone en versalita. Escritos en
  // mayúscula, un lector de pantalla deletrea «S-E-P».
  static MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
                  "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

  connect() {
    this.desde = this.#fecha(this.desdeValue)
    this.hasta = this.#fecha(this.hastaValue)
    this.elegida = this.valorValue ? this.#fecha(this.valorValue) : null
    // Se abre por donde el profesor está trabajando: la fecha que ya tiene, o
    // el mes de hoy si cae dentro del año escolar, o el primero.
    this.mirando = this.elegida || this.#dentro(new Date()) || this.desde
    this.#cerrarAlHacerClicFuera()
  }

  disconnect() {
    document.removeEventListener("click", this.escucha)
    document.removeEventListener("keydown", this.escape)
  }

  alternar(evento) {
    evento.stopPropagation()
    this.panelTarget.hidden ? this.#abrir() : this.#cerrar()
  }

  hoy() {
    const dentro = this.#dentro(new Date())
    if (dentro) this.#elegir(dentro)
  }

  // ── Pintar ────────────────────────────────────────────────────────────────

  #abrir() {
    this.#pintarLosMeses()
    this.#pintarLosDias()
    this.#pintarElAtajoDeHoy()
    this.panelTarget.hidden = false
  }

  #cerrar() {
    this.panelTarget.hidden = true
  }

  // Los meses del año escolar en fila, de septiembre a julio. Se recorren desde
  // el mes de inicio hasta el de fin, así que un colegio con otro calendario
  // —o un año partido -- sale bien sin tocar nada.
  #pintarLosMeses() {
    this.mesesTarget.innerHTML = ""

    for (let f = this.#primeroDelMes(this.desde); f <= this.hasta; f.setMonth(f.getMonth() + 1)) {
      const mes = new Date(f)
      const boton = document.createElement("button")
      boton.type = "button"
      boton.className = "plan-calendario-mes"
      boton.textContent = this.constructor.MESES[mes.getMonth()].slice(0, 3)
      boton.setAttribute("aria-label", this.constructor.MESES[mes.getMonth()])
      boton.classList.toggle("plan-calendario-mes--activo", this.#mismoMes(mes, this.mirando))
      // ⚠️ Se actualiza la clase activa, NO se repintan los meses.
      //
      // Repintándolos, el botón que se acaba de tocar se DESTRUYE antes de que
      // el listener global de «clic fuera» lo mire — y `element.contains()`
      // sobre un nodo que ya no está en el árbol da false. Resultado: elegir un
      // mes cerraba el calendario.
      boton.addEventListener("click", () => {
        this.mirando = mes
        this.mesesTarget.querySelectorAll(".plan-calendario-mes--activo")
            .forEach((otro) => otro.classList.remove("plan-calendario-mes--activo"))
        boton.classList.add("plan-calendario-mes--activo")
        this.#pintarLosDias()
      })
      this.mesesTarget.appendChild(boton)
    }
  }

  #pintarLosDias() {
    this.diasTarget.innerHTML = ""

    const primero = this.#primeroDelMes(this.mirando)
    const ultimo = new Date(primero.getFullYear(), primero.getMonth() + 1, 0)

    // ⚠️ La semana empieza en LUNES, no en domingo: es como se lee un calendario
    // en Venezuela, y el fin de semana queda junto al final de la fila.
    const hueco = (primero.getDay() + 6) % 7
    for (let i = 0; i < hueco; i++) this.diasTarget.appendChild(document.createElement("span"))

    for (let d = 1; d <= ultimo.getDate(); d++) {
      const dia = new Date(primero.getFullYear(), primero.getMonth(), d)
      this.diasTarget.appendChild(this.#botonDelDia(dia, d))
    }
  }

  #botonDelDia(dia, numero) {
    const boton = document.createElement("button")
    boton.type = "button"
    boton.className = "plan-calendario-dia"
    boton.textContent = numero

    // Fuera del año escolar: se ve, pero no se toca. Esconderlo dejaría un mes
    // con un agujero, que se lee como un error de la pantalla.
    if (dia < this.desde || dia > this.hasta) {
      boton.disabled = true
      boton.classList.add("plan-calendario-dia--fuera")
      // ⚠️ `data-tooltip`, nunca `title` (MOR-173): el nativo no se puede
      // estilar, tarda un segundo en salir y en el teléfono no existe.
      boton.dataset.tooltip = "Fuera del año escolar"
      return boton
    }

    boton.classList.toggle("plan-calendario-dia--elegido", this.elegida && this.#mismoDia(dia, this.elegida))
    boton.classList.toggle("plan-calendario-dia--hoy", this.#mismoDia(dia, new Date()))
    boton.addEventListener("click", () => this.#elegir(dia))
    return boton
  }

  #pintarElAtajoDeHoy() {
    if (!this.hasHoyTarget) return

    const dentro = this.#dentro(new Date())
    this.hoyTarget.hidden = !dentro
    if (dentro) {
      this.hoyTarget.textContent =
        `Hoy · ${dentro.getDate()} ${this.constructor.MESES[dentro.getMonth()].slice(0, 3)}`
    }
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  #elegir(dia) {
    this.elegida = dia
    this.campoTarget.value = this.#iso(dia)
    this.#guardar()
  }

  // ⚠️ Sin `formulario`, solo escribe el campo y cierra.
  //
  // En la fila de EDICIÓN cada dato es su propio formulario y elegir un día
  // guarda solo: la fecha no tiene «Enter». En la fila de ALTA la evaluación
  // todavía no existe, así que el campo viaja con el resto y quien envía es el
  // ✓ de la fila. Sin esta guarda, `requestSubmit` sobre un target que no está
  // reventaba con «Missing target element» — y el panel quedaba abierto.
  #guardar() {
    this.#cerrar()
    if (this.hasFormularioTarget) this.formularioTarget.requestSubmit()
  }

  // ── Fechas, sin husos horarios ────────────────────────────────────────────
  //
  // ⚠️ `new Date("2026-09-07")` es MEDIANOCHE UTC, y en Venezuela (UTC-4) eso
  // es el 6 a las 20:00: la fecha se corre un día hacia atrás sola. Por eso se
  // parte la cadena y se construye en hora local.
  #fecha(iso) {
    const [ a, m, d ] = iso.split("-").map(Number)
    return new Date(a, m - 1, d)
  }

  #iso(fecha) {
    const dos = (n) => String(n).padStart(2, "0")
    return `${fecha.getFullYear()}-${dos(fecha.getMonth() + 1)}-${dos(fecha.getDate())}`
  }

  #primeroDelMes(fecha) { return new Date(fecha.getFullYear(), fecha.getMonth(), 1) }

  #mismoDia(a, b)  { return this.#iso(a) === this.#iso(b) }
  #mismoMes(a, b)  { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() }

  #dentro(fecha) {
    const limpia = new Date(fecha.getFullYear(), fecha.getMonth(), fecha.getDate())
    return limpia >= this.desde && limpia <= this.hasta ? limpia : null
  }

  // Se cierra al hacer clic afuera y con Escape, como cualquier menú: un panel
  // que solo se cierra con su propio botón atrapa a quien ya se fue con el ratón.
  #cerrarAlHacerClicFuera() {
    // ⚠️ `composedPath()` y no `contains(target)`: si el clic cayó sobre algo
    // que el propio calendario reemplaza —un día al repintar el mes— ese nodo
    // ya no está en el árbol cuando este listener corre, y `contains` diría
    // que el clic vino de fuera. El camino del evento se calcula al dispararse.
    this.escucha = (evento) => {
      if (!evento.composedPath().includes(this.element)) this.#cerrar()
    }
    this.escape = (evento) => {
      if (evento.key === "Escape" && !this.panelTarget.hidden) {
        this.#cerrar()
        this.botonTarget.focus()
      }
    }
    document.addEventListener("click", this.escucha)
    document.addEventListener("keydown", this.escape)
  }
}
