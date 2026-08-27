import { Controller } from "@hotwired/stimulus"

// El buscador global de `⌘K` y los atajos de teclado (MOR-149).
//
// ## Por qué esto importa en SIGA y no es un adorno
//
// La secretaria busca a un alumno cuarenta veces al día, con la mamá esperando
// del otro lado del mostrador. Sin esto son cuatro pasos y dos cargas de página:
// menú → Alumnos → esperar → escribir → elegir.
//
// ## ⚠️ Por qué NO usa `<turbo-frame>`
//
// La primera versión ponía `frame.src = url` y dejaba que Turbo trajera el
// fragmento. Se veía elegante y **no funcionaba**: pintaba «Content missing» en
// cada búsqueda, con el servidor respondiendo 200, `text/html`, y un frame
// perfecto con el id correcto.
//
// Un frame tiene que estar conectado, activo, visible y no ser preview para
// cargar — y este vive dentro de un modal con `hidden`, que es justamente el
// caso raro. Depurar la mecánica interna de Turbo para un fragmento que se pide
// y se pega no vale la pena: `fetch` hace lo mismo en cinco líneas, deja ver el
// error cuando falla, y no depende de ninguna condición invisible.
export default class extends Controller {
  static targets = ["modal", "campo", "resultados", "resultado"]
  static values = { url: String }

  connect() {
    this.enGlobal = this.atajoGlobal.bind(this)
    document.addEventListener("keydown", this.enGlobal)
    this.seleccion = 0
  }

  disconnect() {
    document.removeEventListener("keydown", this.enGlobal)
    clearTimeout(this.espera)
    if (this.peticion) this.peticion.abort()
  }

  // ── los atajos ──────────────────────────────────────────────────────────

  // ⚠️ TODO el teclado se maneja acá, en un solo `keydown` sobre el documento.
  //
  // La primera versión ponía `keydown->busqueda#enModal` en el div del modal y
  // `esc` no cerraba nada. Con el foco dentro de un `<input type="search">`, el
  // navegador se queda con Escape para limpiar el campo antes de que el evento
  // llegue a un ancestro.
  //
  // En el documento, en fase de burbujeo, llega siempre — y además el atajo de
  // abrir y el de cerrar viven en el mismo lugar, que es más fácil de leer.
  //
  // ⚠️ Y por eso el modal NO declara `keydown->busqueda#enModal` en su HTML: con
  // las dos declaraciones el evento entra dos veces y la flecha abajo salta de
  // dos en dos. Un solo oyente, un solo lugar.
  atajoGlobal(evento) {
    if (this.abierto) return this.enModal(evento)

    const meta = evento.metaKey || evento.ctrlKey

    if (meta && evento.key.toLowerCase() === "k") {
      evento.preventDefault()
      this.abrir()
      return
    }

    // Una sola tecla: solo cuando no se está escribiendo en ningún lado. Sin
    // esto, escribir «1/2» en un campo de nota sería imposible.
    if (evento.key === "/" && !this.escribiendo(evento.target)) {
      evento.preventDefault()
      this.abrir()
    }
  }

  enModal(evento) {
    switch (evento.key) {
      case "Escape":
        evento.preventDefault()
        this.cerrar()
        break
      case "ArrowDown":
        evento.preventDefault()
        this.mover(1)
        break
      case "ArrowUp":
        evento.preventDefault()
        this.mover(-1)
        break
      case "Enter":
        evento.preventDefault()
        this.ir()
        break
    }
  }

  escribiendo(elemento) {
    if (!elemento) return false

    return (
      elemento.isContentEditable ||
      ["INPUT", "TEXTAREA", "SELECT"].includes(elemento.tagName)
    )
  }

  // ── abrir y cerrar ──────────────────────────────────────────────────────

  get abierto() {
    return this.hasModalTarget && !this.modalTarget.hidden
  }

  abrir() {
    if (!this.hasModalTarget) return

    this.modalTarget.hidden = false
    // Guardar quién tenía el foco para devolvérselo al cerrar: sin esto, quien
    // navega con teclado vuelve al principio de la página cada vez.
    this.foco = document.activeElement
    this.campoTarget.value = ""
    this.campoTarget.focus()
    this.seleccion = 0
    document.body.classList.add("con-modal")
  }

  cerrar() {
    if (!this.abierto) return

    this.modalTarget.hidden = true
    document.body.classList.remove("con-modal")
    clearTimeout(this.espera)
    if (this.foco && this.foco.focus) this.foco.focus()
  }

  // Cierra si el clic cayó en el fondo y no en el panel.
  fuera(evento) {
    if (evento.target === this.modalTarget) this.cerrar()
  }

  // ── la búsqueda ─────────────────────────────────────────────────────────

  // Cada tecleo pide el fragmento. 180 ms: menos son tres consultas por palabra,
  // más se siente lento al escribir.
  buscar() {
    clearTimeout(this.espera)
    this.espera = setTimeout(() => this.pedir(), 180)
  }

  async pedir() {
    const termino = this.campoTarget.value

    // Cancelar la petición anterior: escribiendo rápido salen cinco, y sin esto
    // la que conteste última gana — que puede ser la de «bl» sobre la de
    // «blanco». Los resultados se verían de dos letras atrás.
    if (this.peticion) this.peticion.abort()
    this.peticion = new AbortController()

    try {
      const respuesta = await fetch(`${this.urlValue}?q=${encodeURIComponent(termino)}`, {
        headers: { Accept: "text/html" },
        signal: this.peticion.signal
      })

      if (!respuesta.ok) throw new Error(`El servidor respondió ${respuesta.status}`)

      this.resultadosTarget.innerHTML = await respuesta.text()
      this.seleccion = 0
      this.pintar()
    } catch (error) {
      // Una búsqueda cancelada no es un error: es lo normal al escribir.
      if (error.name === "AbortError") return

      // ⚠️ El error se DICE. La versión anterior fallaba en silencio y dejaba
      // «Content missing» en pantalla, que no le explica nada a nadie.
      this.resultadosTarget.innerHTML =
        '<div class="busqueda-vacia"><p>No se pudo buscar.</p>' +
        '<p class="nota-ayuda">Revise su conexión e inténtelo de nuevo.</p></div>'
    }
  }

  // ── moverse por los resultados ──────────────────────────────────────────

  mover(paso) {
    const opciones = this.resultadoTargets
    if (opciones.length === 0) return

    // Da la vuelta en los extremos: bajar desde el último lleva al primero, que
    // es lo que espera quien mantiene la flecha apretada.
    this.seleccion = (this.seleccion + paso + opciones.length) % opciones.length
    this.pintar()
  }

  pintar() {
    this.resultadoTargets.forEach((opcion, i) => {
      const activo = i === this.seleccion

      opcion.classList.toggle("activo", activo)
      // El `li` lleva el rol de opción, no el enlace.
      if (opcion.parentElement) {
        opcion.parentElement.setAttribute("aria-selected", String(activo))
      }
      if (activo) opcion.scrollIntoView({ block: "nearest" })
    })
  }

  ir() {
    const elegido = this.resultadoTargets[this.seleccion]
    if (elegido) elegido.click()
  }
}
