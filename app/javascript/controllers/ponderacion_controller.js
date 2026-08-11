import { Controller } from "@hotwired/stimulus"

// El medidor de peso del lapso.
//
// El profesor tiene que ver cuánto le queda MIENTRAS elige, no después de que el
// formulario lo rechace. Que la validación exista no basta: un rechazo tras
// enviar es información que llega tarde.
//
// Los pesos ya comprometidos vienen embebidos en el formulario en vez de pedirse
// al servidor en cada cambio. Un profesor tiene pocas secciones, así que el mapa
// es chico — y así el medidor responde al instante y sin conexión.
export default class extends Controller {
  static targets = ["asignacion", "lapso", "peso", "medidor", "barraUsado", "barraNuevo", "leyenda"]
  static values  = { asignaciones: Object }

  connect() {
    this.asignacionCambio({ conservarLapso: true })
  }

  // Al cambiar de sección/materia, los lapsos disponibles son otros: son los del
  // año escolar de ESA sección.
  asignacionCambio({ conservarLapso = false } = {}) {
    const datos = this.#asignacionActual()
    const elegido = conservarLapso ? this.lapsoTarget.value : ""

    this.lapsoTarget.innerHTML = ""
    this.lapsoTarget.appendChild(new Option("Elegí el lapso...", ""))

    if (datos) {
      datos.lapsos.forEach(({ id, nombre }) => {
        const opcion = new Option(nombre, id)
        if (String(id) === String(elegido)) opcion.selected = true
        this.lapsoTarget.appendChild(opcion)
      })
    }

    this.recalcular()
  }

  recalcular() {
    const datos = this.#asignacionActual()
    const lapso = this.lapsoTarget.value

    if (!datos || !lapso) {
      this.medidorTarget.hidden = true
      return
    }

    const usado = Number(datos.usado[lapso] ?? 0)
    const nuevo = Number(this.pesoTarget.value) || 0
    const total = usado + nuevo
    const libre = 100 - usado

    this.medidorTarget.hidden = false
    this.barraUsadoTarget.style.width = `${Math.min(usado, 100)}%`
    this.barraNuevoTarget.style.width = `${Math.min(nuevo, Math.max(libre, 0))}%`
    this.barraNuevoTarget.classList.toggle("weight-meter-fill--excedido", total > 100)

    this.leyendaTarget.textContent = this.#leyenda(usado, nuevo, total, libre)
    this.leyendaTarget.classList.toggle("weight-meter-value--excedido", total > 100)
  }

  #asignacionActual() {
    return this.asignacionesValue[this.asignacionTarget.value] || null
  }

  #leyenda(usado, nuevo, total, libre) {
    const n = (v) => (Number.isInteger(v) ? v : v.toFixed(2))

    if (total > 100) {
      return `Ya hay ${n(usado)} % comprometido: quedan ${n(libre)} % y estás pidiendo ${n(nuevo)} %.`
    }
    if (total === 100) {
      return `Con esta evaluación el lapso cierra en 100 %.`
    }
    if (nuevo === 0) {
      return `Ya hay ${n(usado)} % comprometido en este lapso. Quedan ${n(libre)} %.`
    }
    return `${n(usado)} % ya comprometido + ${n(nuevo)} % de esta = ${n(total)} %. Faltaría ${n(100 - total)} %.`
  }
}
