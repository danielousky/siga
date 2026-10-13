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
// ⚠️ Se marcan COMPETENCIAS. Los indicadores se escriben en el PLAN, dentro de
// su evaluación, y acá van de contexto — ayudan a reconocer cuál competencia es
// cuál cuando dos se parecen.
//
// Llegaron a marcarse acá también, y duró dos días: Daniel, 23 de septiembre,
// *«¿te parece bien que haya 2 maneras distintas de hacer lo mismo?»*. Un
// indicador cuelga de la evaluación que lo mide, y esta pantalla la está
// creando: la manera de escribirlos es la fila del plan, una sola.
export default class extends Controller {
  static targets = ["asignacion", "lapso", "lista", "vacio", "nueva"]
  static values  = { planes: Object, marcadas: Array, rutaNueva: String }

  connect() {
    this.actualizar()
  }

  actualizar() {
    const plan = this.#planActual()

    // ⚠️ El bloque YA NO se esconde desde acá.
    //
    // Escondía el bloque entero cuando el plan del lapso venía vacío, y eso
    // ahora se lleva puesto el botón [+] que crea la primera competencia —
    // justo cuando más hace falta. Quién ve este bloque lo decide el SERVIDOR,
    // por el grado: un profesor de bachillerato no lo recibe en el HTML.
    //
    // Con el plan vacío se escribe el mensaje que lo explica, y el [+] queda al
    // lado para resolverlo.
    this.#apuntarElBotonDeNueva()

    if (this.#faltaElegir()) return this.#pedirQueElija()
    if (plan.length === 0) return this.#planVacio()

    this.#dibujar(plan)
  }

  // ── privados ──────────────────────────────────────────────────────────────

  // El botón [+] lleva a registrar una competencia CON el contexto puesto.
  //
  // Daniel: *«nueva competencia (con los datos, directo a la competencia
  // específica de la sección)»*. El profesor que está armando su evaluación y
  // descubre que le falta una competencia tenía que abandonar el formulario, ir
  // al plan y elegir grado – área – sección – lapso otra vez.
  //
  // ⚠️ Sin `href` mientras falte elegir, y no `disabled`: un `<a>` no tiene
  // `disabled`, y un enlace que navega a `/competencias/new` sin contexto abre
  // un formulario que no sabe a qué plan pertenece. El CSS lo pinta apagado.
  #apuntarElBotonDeNueva() {
    if (!this.hasNuevaTarget) return

    if (this.#faltaElegir()) {
      this.nuevaTarget.removeAttribute("href")
      this.nuevaTarget.setAttribute("aria-disabled", "true")
      return
    }

    const parametros = new URLSearchParams({
      asignacion: this.asignacionTarget.value,
      lapso: this.lapsoTarget.value
    })
    this.nuevaTarget.href = `${this.rutaNuevaValue}?${parametros}`
    this.nuevaTarget.removeAttribute("aria-disabled")
  }


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
    this.#decir("Elija la sección y el lapso para ver su plan.")
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

    // ⚠️ De CONTEXTO, sin casilla: dos competencias de la misma área se
    // parecen, y sus indicadores son lo que las distingue. Marcarlos acá sería
    // una segunda manera de hacer lo que la fila del plan ya hace.
    if (indicadores.length > 0) {
      const lista = document.createElement("ul")
      lista.className = "que-evalua-indicadores"
      indicadores.forEach(({ texto }) => {
        const li = document.createElement("li")
        li.textContent = texto
        lista.appendChild(li)
      })
      item.appendChild(lista)
    }

    return item
  }
}
