import { Controller } from "@hotwired/stimulus"

// Guardado incremental de la planilla de notas.
//
// Cada nota viaja sola, apenas se escribe. No hay botón "Guardar": con la
// conectividad que hay, un formulario de 30 campos que se envía al final es una
// promesa de perder el trabajo de una noche.
//
// Lo que más importa acá no es guardar, es que el profesor VEA lo que pasó. Un
// guardado silencioso que falla es peor que no guardar: cierra el teléfono
// creyendo que terminó. Por eso cada fila tiene su estado, los fallos quedan en
// una cola visible con botón de reintento, y salir de la página con notas sin
// guardar pide confirmación.
export default class extends Controller {
  // `definitiva` solo existe en la planilla de REPARACIÓN: ahí el profesor tiene
  // que ver en el momento con qué nota queda el alumno (Art. 112). La planilla
  // de notas normal no lo declara, y `definitivaTargets` devuelve [] sin
  // romperse — por eso el mismo controlador sirve para las dos.
  static targets = ["fila", "input", "estado", "definitiva", "progresoBarra", "progresoTexto", "aviso", "avisoTexto"]
  static values  = { urlBase: String, cargadas: Number, total: Number }

  connect() {
    this.pendientes = new Map()   // input → valor que no se pudo guardar
    this.enVuelo = new Set()
    this._avisarAlSalir = this._avisarAlSalir.bind(this)
    window.addEventListener("beforeunload", this._avisarAlSalir)
    window.addEventListener("online", () => this.reintentarTodo())
  }

  disconnect() {
    window.removeEventListener("beforeunload", this._avisarAlSalir)
  }

  // Enter y flechas mueven entre alumnos sin tocar el mouse: cargar 30 notas
  // pasando por el mouse en cada una es lo que hace que un profesor abandone.
  navegar(event) {
    const salto = { Enter: 1, ArrowDown: 1, ArrowUp: -1 }[event.key]
    if (!salto) return

    event.preventDefault()
    const inputs = this.inputTargets
    const siguiente = inputs[inputs.indexOf(event.target) + salto]
    if (siguiente) {
      siguiente.focus()
      siguiente.select()
    } else {
      event.target.blur()   // dispara el change del último
    }
  }

  guardar(event) {
    this.#enviar(event.target)
  }

  reintentarTodo() {
    for (const input of [...this.pendientes.keys()]) this.#enviar(input)
  }

  async #enviar(input) {
    const fila = input.closest("[data-carga-notas-target='fila']")
    const alumno = fila.dataset.alumno
    const valor = input.value.trim()

    if (this.enVuelo.has(alumno)) return
    this.enVuelo.add(alumno)
    this.#estado(fila, "guardando")

    try {
      const respuesta = await fetch(this.urlBaseValue.replace("STUDENT_ID", alumno), {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({ score: valor })
      })

      const datos = await respuesta.json()

      if (!respuesta.ok) {
        this.#estado(fila, "rechazado", datos.mensaje)
        this.pendientes.delete(input)   // no es un problema de red: reintentar no arregla nada
      } else {
        this.#estado(fila, valor === "" ? "vacio" : "guardado")
        this.pendientes.delete(input)
        this.#progreso(datos.cargadas, datos.total)
        this.#definitiva(fila, datos)
      }
    } catch {
      // Sin red. El valor se queda en pantalla y en la cola.
      this.#estado(fila, "sin-red")
      this.pendientes.set(input, valor)
    } finally {
      this.enVuelo.delete(alumno)
      this.#actualizarAviso()
    }
  }

  #estado(fila, estado, mensaje = "") {
    const marca = fila.querySelector("[data-carga-notas-target='estado']")
    fila.dataset.estado = estado
    marca.textContent = { guardando: "…", guardado: "✓", vacio: "—", "sin-red": "⟳", rechazado: "!" }[estado] || ""
    marca.title = mensaje || { guardando: "Guardando…", guardado: "Guardada", vacio: "Sin nota", "sin-red": "Sin conexión: queda pendiente", rechazado: mensaje }[estado] || ""

    if (estado === "rechazado" && mensaje) {
      this.avisoTextoTarget.textContent = mensaje
      this.avisoTarget.hidden = false
    }
  }

  // La nota con la que queda el alumno, al lado del campo. Sin esto, quien carga
  // 14 sobre un 8 no sabe si el sistema se quedó con el 8: el Art. 112 sería una
  // promesa que no se comprueba hasta que salga el boletín.
  #definitiva(fila, datos) {
    const celda = fila.querySelector("[data-carga-notas-target='definitiva']")
    if (!celda || datos.definitiva === undefined) return

    celda.textContent = datos.definitiva ?? "—"
    celda.classList.toggle("bajo", !datos.aprobado)
    celda.classList.toggle("aprobada", !!datos.aprobado)
  }

  #progreso(cargadas, total) {
    if (cargadas == null) return
    this.progresoBarraTarget.style.width = `${total ? (cargadas * 100) / total : 0}%`
    this.progresoTextoTarget.textContent = `${cargadas} de ${total} cargadas`
  }

  #actualizarAviso() {
    const cuantas = this.pendientes.size
    if (cuantas === 0) {
      this.avisoTarget.hidden = true
      return
    }
    this.avisoTextoTarget.textContent =
      `${cuantas} ${cuantas === 1 ? "nota quedó" : "notas quedaron"} sin guardar: no hay conexión. Se reintenta solo al volver.`
    this.avisoTarget.hidden = false
  }

  _avisarAlSalir(event) {
    if (this.pendientes.size === 0) return
    event.preventDefault()
    event.returnValue = ""
  }
}
