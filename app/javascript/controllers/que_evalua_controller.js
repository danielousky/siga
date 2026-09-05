import { Controller } from "@hotwired/stimulus"

// Qué competencias del plan evalúa esta evaluación (MOR-136).
//
// La sección y el lapso se eligen en el MISMO formulario, así que la lista de
// competencias tiene que cambiar mientras la persona elige. Es el mismo
// problema que resuelve `ponderacion`, y por eso la misma solución: el plan
// entero viaja embebido en el formulario en vez de pedirse al servidor.
//
// Cabe porque solo trae PRIMARIA: un maestro tiene dos o tres secciones, no
// diecinueve. Un profesor de bachillerato recibe un mapa vacío y el bloque ni
// se dibuja.
//
// ⚠️ Se marcan COMPETENCIAS, no indicadores. Los indicadores se muestran como
// contexto —ayudan a reconocer cuál es cuál— y no se guardan: su nivel en la
// boleta es el de su competencia. Marcarlos prometería una precisión que el
// modelo no tiene.
export default class extends Controller {
  static targets = ["asignacion", "lapso", "lista", "vacio", "bloque"]
  static values  = { planes: Object, marcadas: Array }

  connect() {
    this.actualizar()
  }

  actualizar() {
    const plan = this.#planActual()

    // Todo el bloque desaparece cuando no hay nada que ofrecer: un titulito
    // «Qué evalúa» sobre un vacío permanente le enseña al profesor a ignorar
    // esa zona del formulario.
    if (this.hasBloqueTarget) this.bloqueTarget.hidden = plan.length === 0 && !this.#faltaElegir()

    if (this.#faltaElegir()) return this.#pedirQueElija()
    if (plan.length === 0) return this.#planVacio()

    this.#dibujar(plan)
  }

  // ── privados ──────────────────────────────────────────────────────────────

  #planActual() {
    const seccion = (this.asignacionTarget.value || "").split(":")[0]
    const materia = (this.asignacionTarget.value || "").split(":")[1]
    const lapso   = this.lapsoTarget.value

    if (!seccion || !materia || !lapso) return []
    return this.planesValue[`${seccion}:${materia}:${lapso}`] || []
  }

  #faltaElegir() {
    return !this.asignacionTarget.value || !this.lapsoTarget.value
  }

  #pedirQueElija() {
    this.listaTarget.innerHTML = ""
    this.#decir("Elige la sección y el lapso para ver su plan.")
  }

  #planVacio() {
    this.listaTarget.innerHTML = ""
    this.#decir("Este lapso todavía no tiene competencias en su plan. La evaluación se guarda igual.")
  }

  #decir(texto) {
    if (!this.hasVacioTarget) return
    this.vacioTarget.textContent = texto
    this.vacioTarget.hidden = false
  }

  #dibujar(plan) {
    if (this.hasVacioTarget) this.vacioTarget.hidden = true

    // ⚠️ Se lee lo marcado del DOM antes de rehacerlo: cambiar de lapso y
    // volver no puede perder lo que la persona ya había marcado.
    const marcadas = new Set([...this.#marcadasEnPantalla(), ...this.marcadasValue.map(String)])

    this.listaTarget.innerHTML = ""
    plan.forEach(({ id, texto, indicadores }) => {
      this.listaTarget.appendChild(this.#fila(id, texto, indicadores, marcadas.has(String(id))))
    })
  }

  #marcadasEnPantalla() {
    return [...this.listaTarget.querySelectorAll("input:checked")].map((c) => c.value)
  }

  #fila(id, texto, indicadores, marcada) {
    const item = document.createElement("li")
    item.className = "que-evalua-item"

    const etiqueta = document.createElement("label")
    etiqueta.className = "que-evalua-competencia"

    const casilla = document.createElement("input")
    casilla.type = "checkbox"
    casilla.name = "evaluation_activity[competency_ids][]"
    casilla.value = id
    casilla.checked = marcada

    const nombre = document.createElement("span")
    nombre.textContent = texto

    etiqueta.append(casilla, nombre)
    item.appendChild(etiqueta)

    if (indicadores.length > 0) {
      const lista = document.createElement("ul")
      lista.className = "que-evalua-indicadores"
      indicadores.forEach((indicador) => {
        const li = document.createElement("li")
        li.textContent = indicador
        lista.appendChild(li)
      })
      item.appendChild(lista)
    }

    return item
  }
}
