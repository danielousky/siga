import { Controller } from "@hotwired/stimulus"

// El buscador global de `⌘K` y los atajos de teclado (MOR-149).
//
// ## Por qué esto importa en SIGA y no es un adorno
//
// La secretaria busca a un alumno cuarenta veces al día, con la mamá esperando
// del otro lado del mostrador. Hoy son cuatro pasos y dos cargas de página:
// menú → Estudiantes → esperar → escribir → elegir. Con esto es escribir el
// apellido y apretar Enter.
//
// ## ⚠️ El atajo NO puede pisar el del navegador ni el del sistema
//
// `⌘K` está libre en el navegador; `⌘L` no —es la barra de direcciones— y `⌘F`
// tampoco. Se eligió `⌘K` porque además es lo que ya hacen las herramientas de
// las que viene la costumbre, y `/` como alternativa para quien no usa Mac ni
// quiere modificadores.
//
// ## Y no se activa mientras se está escribiendo en otro lado
//
// Si `/` abriera el buscador siempre, escribir «1/2» en un campo de nota sería
// imposible. Los atajos de una sola tecla se ignoran dentro de un `input`, un
// `textarea` o un `select`.
export default class extends Controller {
  static targets = ["modal", "campo", "frame", "resultado"]

  connect() {
    this.enGlobal = this.enGlobal || this.atajoGlobal.bind(this)
    document.addEventListener("keydown", this.enGlobal)
    this.seleccion = 0
  }

  disconnect() {
    document.removeEventListener("keydown", this.enGlobal)
  }

  // ── los atajos ──────────────────────────────────────────────────────────

  atajoGlobal(evento) {
    const meta = evento.metaKey || evento.ctrlKey

    if (meta && evento.key.toLowerCase() === "k") {
      evento.preventDefault()
      this.abrir()
      return
    }

    // Una sola tecla: solo cuando no se está escribiendo en ningún lado.
    if (evento.key === "/" && !this.escribiendo(evento.target)) {
      evento.preventDefault()
      this.abrir()
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

  abrir() {
    if (!this.hasModalTarget) return

    this.modalTarget.hidden = false
    // ⚠️ Guardar quién tenía el foco para devolvérselo al cerrar. Sin esto,
    // quien navega con teclado vuelve al principio de la página cada vez que
    // abre y cierra el buscador.
    this.foco = document.activeElement
    this.campoTarget.value = ""
    this.campoTarget.focus()
    this.seleccion = 0
    document.body.classList.add("con-modal")
  }

  cerrar() {
    if (!this.hasModalTarget || this.modalTarget.hidden) return

    this.modalTarget.hidden = true
    document.body.classList.remove("con-modal")
    if (this.foco && this.foco.focus) this.foco.focus()
  }

  // Cierra si el clic cayó en el fondo y no en el panel.
  fuera(evento) {
    if (evento.target === this.modalTarget) this.cerrar()
  }

  // ── el teclado dentro del modal ─────────────────────────────────────────

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

  mover(paso) {
    const opciones = this.resultadoTargets
    if (opciones.length === 0) return

    // Da la vuelta en los extremos: bajar desde el último lleva al primero. Es
    // lo que espera quien mantiene la flecha apretada.
    this.seleccion = (this.seleccion + paso + opciones.length) % opciones.length
    this.pintar()
  }

  pintar() {
    this.resultadoTargets.forEach((opcion, i) => {
      const activo = i === this.seleccion
      opcion.classList.toggle("activo", activo)
      // El `li` es el que lleva el rol de opción, no el enlace.
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

  // Cada tecleo pide el fragmento. `debounce` de 180 ms: menos que eso son tres
  // consultas por palabra, y más se siente lento al escribir.
  buscar() {
    clearTimeout(this.espera)
    this.espera = setTimeout(() => this.pedir(), 180)
  }

  pedir() {
    const termino = this.campoTarget.value
    const url = `${this.frameTarget.dataset.url}?q=${encodeURIComponent(termino)}`

    this.frameTarget.src = url
    this.seleccion = 0
  }
}
