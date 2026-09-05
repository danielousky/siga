import { Controller } from "@hotwired/stimulus"

// Guardado incremental de la planilla de informes descriptivos (MOR-216).
//
// Hermano de `carga-notas`, con dos diferencias que vienen del dato:
//
//   · una NOTA se termina de escribir en dos teclas, así que se guarda al
//     cambiar. Un INFORME son tres renglones: guardar en cada tecla sería una
//     petición por letra, y el `blur` es el momento natural — la maestra pasa
//     al siguiente alumno.
//   · el campo CRECE con lo que se escribe: un textarea de tres líneas fijas
//     esconde lo ya escrito justo cuando se relee para corregir.
//
// Lo que NO cambia es lo que más importa: el docente tiene que VER qué pasó. Un
// guardado silencioso que falla es peor que no guardar — se cierra el teléfono
// creyendo que se terminó.
export default class extends Controller {
  static targets = ["fila", "campo", "estado", "aviso", "avisoTexto"]
  static values  = { urlBase: String }

  connect() {
    this.pendientes = new Map()
    this._avisarAlSalir = this._avisarAlSalir.bind(this)
    window.addEventListener("beforeunload", this._avisarAlSalir)
    window.addEventListener("online", () => this.reintentarTodo())
    this.campoTargets.forEach((campo) => {
      campo.dataset.guardado = campo.value
      this.ajustarAlto(campo)
    })
  }

  disconnect() {
    window.removeEventListener("beforeunload", this._avisarAlSalir)
  }

  crecer(event) {
    this.ajustarAlto(event.target)
    // Escribir borra el «guardado» de la vez anterior: dejarlo puesto mientras
    // se teclea afirma algo que ya no es cierto.
    this.marcar(event.target, "")
  }

  guardar(event) {
    const campo = event.target
    if (campo.value === campo.dataset.guardado) return   // nada cambió

    this.enviar(campo)
  }

  reintentarTodo() {
    const campos = [...this.pendientes.keys()]
    this.pendientes.clear()
    this.ocultarAviso()
    campos.forEach((campo) => this.enviar(campo))
  }

  // ── internos ──────────────────────────────────────────────────────────────

  async enviar(campo) {
    const [ruta, query] = this.urlBaseValue.split("?")
    const url = `${ruta}/${campo.dataset.enrollment}${query ? `?${query}` : ""}`
    this.marcar(campo, "guardando")

    try {
      const respuesta = await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({ cuerpo: campo.value })
      })

      if (!respuesta.ok) {
        const cuerpo = await respuesta.json().catch(() => ({}))
        throw new Error(cuerpo.mensaje || "No se pudo guardar")
      }

      campo.dataset.guardado = campo.value
      this.pendientes.delete(campo)
      this.marcar(campo, "guardado")
      if (this.pendientes.size === 0) this.ocultarAviso()
    } catch (error) {
      this.pendientes.set(campo, campo.value)
      this.marcar(campo, "error")
      this.mostrarAviso(error.message)
    }
  }

  ajustarAlto(campo) {
    // ⚠️ `auto` primero: sin esto `scrollHeight` nunca baja, y el campo crece
    // pero no vuelve a achicarse cuando se borra texto.
    campo.style.height = "auto"
    campo.style.height = `${campo.scrollHeight}px`
  }

  marcar(campo, estado) {
    const fila = campo.closest("[data-carga-informes-target='fila']")
    if (!fila) return
    fila.dataset.estado = estado

    const etiqueta = fila.querySelector("[data-carga-informes-target='estado']")
    if (!etiqueta) return
    etiqueta.textContent = { guardando: "guardando…", guardado: "guardado", error: "no se guardó" }[estado] || ""
  }

  mostrarAviso(mensaje) {
    if (!this.hasAvisoTarget) return
    this.avisoTextoTarget.textContent = `${mensaje}. Lo escrito no se perdió: queda acá hasta que se pueda guardar.`
    this.avisoTarget.hidden = false
  }

  ocultarAviso() {
    if (this.hasAvisoTarget) this.avisoTarget.hidden = true
  }

  _avisarAlSalir(event) {
    if (this.pendientes.size === 0) return
    event.preventDefault()
    event.returnValue = ""
  }
}
