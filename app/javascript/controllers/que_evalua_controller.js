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
// ⚠️ Se marcan la COMPETENCIA y sus INDICADORES (MOR-136, segunda mitad).
//
// Acá decía que los indicadores eran solo contexto. Dejó de ser cierto: Daniel
// pidió que una evaluación nueva pueda tomar competencias ya creadas «y a su vez
// agregar también otros indicadores», con la regla que decide la forma — «los
// indicadores no se repiten entre evaluaciones».
//
// Lo que NO cambió es el nivel: el indicador sigue sin calificarse aparte. Se
// marca cuál MIDE esta evaluación, para poder imprimirlo debajo en la boleta.
export default class extends Controller {
  static targets = ["asignacion", "lapso", "lista", "vacio", "nueva"]
  static values  = { planes: Object, marcadas: Array, marcados: Array, rutaNueva: String }

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

  // ⚠️ Acotado a las casillas de COMPETENCIA.
  //
  // Era `input:checked` a secas, y desde que los indicadores también son
  // casillas eso devolvía los ids de unos y otros mezclados: al cambiar de
  // lapso, el id 7 de un indicador marcaba la competencia 7.
  #marcadasEnPantalla() {
    return [...this.listaTarget.querySelectorAll('input[name*="competency_ids"]:checked')].map((c) => c.value)
  }

  #marcadosEnPantalla() {
    return [...this.listaTarget.querySelectorAll('input[name*="indicator_ids"]:checked')].map((c) => c.value)
  }

  // Marcar la competencia despliega sus indicadores; desmarcarla los guarda.
  //
  // ⚠️ Se esconde, no se borra: quien marca, mira, se arrepiente y vuelve a
  // marcar encuentra lo que había elegido. Y lo escondido no estorba — el
  // servidor descarta los indicadores de una competencia que no se mide.
  alternar(evento) {
    const item = evento.target.closest(".que-evalua-item")
    const mide = item?.querySelector(".que-evalua-mide")
    if (mide) mide.hidden = !evento.target.checked
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
    casilla.dataset.action = "change->que-evalua#alternar"

    const nombre = document.createElement("span")
    nombre.textContent = texto

    etiqueta.append(casilla, nombre)
    item.append(etiqueta, this.#queMide(id, indicadores, marcada))
    return item
  }

  // Los indicadores de esa competencia: los libres se marcan, los que ya mide
  // otra evaluación se ven apagados y dicen quién.
  //
  // ⚠️ Los de ESTA evaluación llegan con `libre: false` —los mide ella— así que
  // lo que decide si se pueden marcar no es `libre` sino `libre || ya marcado`.
  // Sin eso, editar una evaluación mostraba sus propios indicadores tachados y
  // guardar los soltaba.
  #queMide(id, indicadores, marcada) {
    const marcados = new Set([...this.#marcadosEnPantalla(), ...this.marcadosValue.map(String)])
    const caja = document.createElement("div")
    caja.className = "que-evalua-mide"
    caja.hidden = !marcada

    const elegibles = indicadores.filter((i) => i.libre || marcados.has(String(i.id)))
    const tomados   = indicadores.filter((i) => !elegibles.includes(i))

    if (elegibles.length > 0) caja.appendChild(this.#elegibles(elegibles, marcados))
    if (tomados.length > 0)   caja.appendChild(this.#tomados(tomados))
    caja.append(...this.#escribirOtros(id, elegibles.length > 0))
    return caja
  }

  #elegibles(indicadores, marcados) {
    const lista = document.createElement("ul")
    lista.className = "que-evalua-indicadores"

    indicadores.forEach(({ id, texto }) => {
      const casilla = document.createElement("input")
      casilla.type = "checkbox"
      casilla.name = "evaluation_activity[indicator_ids][]"
      casilla.value = id
      casilla.checked = marcados.has(String(id))

      const nombre = document.createElement("span")
      nombre.textContent = texto

      const etiqueta = document.createElement("label")
      etiqueta.className = "que-evalua-indicador"
      etiqueta.append(casilla, nombre)

      const li = document.createElement("li")
      li.appendChild(etiqueta)
      lista.appendChild(li)
    })
    return lista
  }

  #tomados(indicadores) {
    const lista = document.createElement("ul")
    lista.className = "que-evalua-indicadores que-evalua-indicadores--tomados"

    indicadores.forEach(({ texto, mide }) => {
      const nombre = document.createElement("span")
      nombre.className = "alta-mide-tomado"
      nombre.textContent = texto

      const quien = document.createElement("span")
      quien.className = "alta-mide-quien"
      quien.textContent = `lo mide «${mide}»`

      const li = document.createElement("li")
      li.append(nombre, quien)
      lista.appendChild(li)
    })
    return lista
  }

  // ⚠️ Uno por LÍNEA, como el formulario del plan: una maestra ya tiene sus
  // indicadores escritos en un documento y los pega de una vez.
  #escribirOtros(id, hayLibres) {
    const campo = document.createElement("textarea")
    campo.name = `evaluation_activity[indicadores_nuevos][${id}]`
    campo.id = `indicadores_nuevos_${id}`
    campo.rows = 2
    campo.className = "form-control"
    campo.placeholder = "Estima el resultado antes de calcular"
    campo.autocomplete = "off"

    const rotulo = document.createElement("label")
    rotulo.className = "form-label"
    rotulo.htmlFor = campo.id
    rotulo.textContent = hayLibres ? "Y otros indicadores, uno por línea" : "Qué indicadores mide, uno por línea"

    return [rotulo, campo]
  }
}
