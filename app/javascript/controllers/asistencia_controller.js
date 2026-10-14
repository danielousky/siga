import { Controller } from "@hotwired/stimulus"

// La toma de asistencia (MOR-111).
//
// Un minuto para treinta alumnos, de pie, con la clase entrando. Todo lo de acá
// sale de esa restricción:
//
//   · Todos arrancan PRESENTES. Se tocan las excepciones, que la mayoría de los
//     días son dos o tres.
//   · Un toque cicla presente → ausente → tarde → presente. Sin menús, sin
//     selects: en un teléfono cada menú son dos toques y una espera.
//   · El objetivo del toque es la FILA ENTERA, no una casilla de 20 px.
//
// ## Por qué acá hay botón "Guardar" y en la planilla de notas no
//
// Parece una inconsistencia y es deliberada. Las notas son treinta valores
// tipeados —media hora de trabajo— y por eso cada una viaja sola: un envío
// final que falla tira todo. Acá el trabajo son tres toques, y con una conexión
// mala **una petición chica llega mucho más seguido que treinta**. Si falla, se
// reintenta sin haber perdido nada.
const CICLO = { presente: "ausente", ausente: "tarde", tarde: "presente" }
const ETIQUETAS = { presente: "Presente", ausente: "Ausente", tarde: "Tarde" }

export default class extends Controller {
  static targets = ["alumno", "etiqueta", "resumen", "guardar", "aviso", "avisoTexto", "avisoEnlace"]
  static values  = { url: String, dia: String, total: Number }

  connect() {
    this.guardado = false
    this._avisarAlSalir = this._avisarAlSalir.bind(this)
    window.addEventListener("beforeunload", this._avisarAlSalir)
    this.#resumir()
  }

  disconnect() {
    window.removeEventListener("beforeunload", this._avisarAlSalir)
  }

  alternar(event) {
    const fila = event.currentTarget.closest("[data-asistencia-target='alumno']")
    const siguiente = CICLO[fila.dataset.estado] || "ausente"

    fila.dataset.estado = siguiente
    fila.querySelector("[data-asistencia-target='etiqueta']").textContent = ETIQUETAS[siguiente]

    this.guardado = false
    this.#resumir()
  }

  async guardar() {
    const estados = {}
    for (const fila of this.alumnoTargets) {
      estados[fila.dataset.inscripcion] = fila.dataset.estado
    }

    this.guardarTarget.disabled = true
    this.guardarTarget.textContent = "Guardando…"
    this.avisoTarget.hidden = true

    try {
      const respuesta = await fetch(`${this.urlValue}?dia=${this.diaValue}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({ dia: this.diaValue, estados })
      })

      const datos = await respuesta.json()

      if (!respuesta.ok) {
        this.#fallar(datos.mensaje || "No se pudo guardar.", datos.enlace)
        return
      }

      this.guardado = true
      this.guardarTarget.textContent = "Guardada ✓"
      this.resumenTarget.textContent = datos.mensaje
    } catch {
      // Sin red. Lo marcado sigue en pantalla: se reintenta con el mismo botón.
      this.#fallar("Sin conexión. Lo que marcó sigue aquí: toque otra vez para reintentar.")
    } finally {
      this.guardarTarget.disabled = false
      if (!this.guardado) this.guardarTarget.textContent = "Guardar asistencia"
    }
  }

  // ⚠️ El enlace viene del muro de la suscripción: a quien la paga, el servidor
  // le dice adónde ir («Ver cómo activarla →»). Sin él, el aviso dice que no se
  // puede y deja a la persona sin salida. Se ESCRIBE en un `<a>` que ya está en
  // la página, y no se arma con `innerHTML`: el texto viene del servidor y así
  // nunca se interpreta como marcado.
  #fallar(mensaje, enlace = null) {
    this.avisoTextoTarget.textContent = mensaje
    this.avisoTarget.hidden = false

    if (!this.hasAvisoEnlaceTarget) return
    const hay = Boolean(enlace && enlace.url)
    this.avisoEnlaceTarget.hidden = !hay
    if (!hay) return

    this.avisoEnlaceTarget.href = enlace.url
    this.avisoEnlaceTarget.textContent = `${enlace.texto} →`
  }

  // El resumen es la verificación del profesor: mira el número y sabe si marcó
  // lo que quería, sin releer treinta nombres.
  #resumir() {
    const cuenta = { presente: 0, ausente: 0, tarde: 0 }
    for (const fila of this.alumnoTargets) cuenta[fila.dataset.estado]++

    const partes = [`${cuenta.presente} ${cuenta.presente === 1 ? "presente" : "presentes"}`]
    if (cuenta.ausente) partes.push(`${cuenta.ausente} ${cuenta.ausente === 1 ? "ausente" : "ausentes"}`)
    if (cuenta.tarde) partes.push(`${cuenta.tarde} con retraso`)

    this.resumenTarget.textContent = partes.join(" · ")
  }

  _avisarAlSalir(event) {
    if (this.guardado) return
    // Solo molesta si el profesor marcó algo: salir de una pantalla intacta no
    // pierde nada, y un diálogo de más es lo que enseña a ignorarlos.
    const hayMarcas = this.alumnoTargets.some((f) => f.dataset.estado !== "presente")
    if (!hayMarcas) return

    event.preventDefault()
    event.returnValue = ""
  }
}
