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
  static targets = ["asignacion", "lapso", "peso", "rango", "medidor", "barraUsado", "barraNuevo", "leyenda"]
  static values  = { asignaciones: Object }

  connect() {
    this.asignacionCambio({ conservarLapso: true })

    // ⚠️ Y el deslizador se pone donde el número, también al EDITAR.
    // `asignacionCambio` llega hasta `proponerElPeso`, que sale en la primera
    // línea cuando el campo ya trae un valor —justo el caso de editar— así que
    // el deslizador se quedaba en 1 sobre una evaluación que vale 40.
    this.#moverElRango()
  }

  // Al cambiar de sección/materia, los lapsos disponibles son otros: son los del
  // año escolar de ESA sección.
  asignacionCambio({ conservarLapso = false } = {}) {
    const datos = this.#asignacionActual()

    // ⚠️ Con el contexto fijado desde el enlace, el lapso es un `hidden` y no
    // hay lista que repoblar — ya está decidido. Repoblarlo sería, además,
    // `appendChild` sobre un `<input>`, que es un elemento vacío.
    if (this.lapsoTarget.tagName !== "SELECT") {
      this.proponerElPeso()
      this.recalcular()
      return
    }

    const elegido = conservarLapso ? this.lapsoTarget.value : ""

    this.lapsoTarget.innerHTML = ""
    this.lapsoTarget.appendChild(new Option("Elija el lapso...", ""))

    if (datos) {
      datos.lapsos.forEach(({ id, nombre }) => {
        const opcion = new Option(nombre, id)
        if (String(id) === String(elegido)) opcion.selected = true
        this.lapsoTarget.appendChild(opcion)
      })
    }

    this.proponerElPeso()
    this.recalcular()
  }

  // ⚠️ Propone el peso que falta, en vez de dejar el campo vacío (MOR-164).
  //
  // El profesor tenía que mirar el medidor, restar de cabeza y escribir el
  // resultado. SIGA ya sabe cuánto queda libre: pedírselo es pedirle que haga
  // una cuenta que el sistema tiene hecha.
  //
  // Es una PROPUESTA, no una imposición: se puede escribir otra cosa encima. Un
  // profesor que reparte 40/30/30 borra el 100 y escribe 40 — y a partir de ahí
  // el sistema le propone lo que va quedando.
  proponerElPeso() {
    // Solo si el campo está vacío: nunca se le pisa un número escrito a mano, ni
    // el peso de una evaluación que se está editando.
    if (this.pesoTarget.value) return

    const datos = this.#asignacionActual()
    const lapso = this.lapsoTarget.value
    if (!datos || !lapso) return

    const libre = 100 - Number(datos.usado[lapso] ?? 0)
    if (libre > 0) this.pesoTarget.value = Number(libre.toFixed(2))
    this.#moverElRango()
  }

  // ⚠️ El deslizador topa en LO QUE QUEDA, no en 100.
  //
  // Daniel: *«no me debería permitir pasar del porcentaje que supere los
  // 100 %, eso es un error, debería poder jugar con lo que me queda»*.
  //
  // Con `max="100"` fijo, arrastrarlo hasta el final proponía un reparto que el
  // modelo iba a rechazar — el profesor descubría el tope al guardar, después
  // de haber escrito todo lo demás. El deslizador es justamente el control que
  // debe hacer imposible lo imposible: no hay forma de teclear de más.
  //
  // ⚠️ Editando, `libre` YA descuenta la evaluación que se está tocando
  // (`peso_usado(..., excepto:)`), o cambiarle el 40 % a 45 sería imposible con
  // el lapso cerrado en 100.
  #toparElRango() {
    if (!this.hasRangoTarget) return

    const libre = this.#loQueQueda()
    // El lapso ya está en 100: el deslizador no tiene rango que ofrecer y se
    // apaga. La leyenda de abajo explica por qué, que es lo que hace falta.
    this.rangoTarget.disabled = libre <= 0
    this.rangoTarget.max = Math.max(libre, 1)
  }

  #loQueQueda() {
    const datos = this.#asignacionActual()
    const lapso = this.lapsoTarget.value
    if (!datos || !lapso) return 100

    return 100 - Number(datos.usado[lapso] ?? 0)
  }

  #moverElRango() {
    if (!this.hasRangoTarget) return

    this.#toparElRango()
    const tope = Number(this.rangoTarget.max)
    const valor = Number(this.pesoTarget.value)
    this.rangoTarget.value = Number.isFinite(valor) ? Math.min(Math.max(valor, 1), tope) : 1
  }

  // ⚠️ El deslizador y el número son DOS caras del mismo valor, y hay que
  // moverlas juntas. El que viaja al servidor es el número; el deslizador no
  // tiene `name`.
  //
  // Del deslizador al número: el valor entero se escribe tal cual. Del número
  // al deslizador: se recorta al rango 1–100 —el campo admite 33,33 y el
  // deslizador solo enteros— y el número NO se toca, o escribir «33,33» se
  // volvería «33» debajo de los dedos.
  desdeElRango() {
    this.pesoTarget.value = this.rangoTarget.value
    this.recalcular()
  }

  desdeElNumero() {
    this.#moverElRango()
    this.recalcular()
  }

  // Al salir del campo se corrige el exceso tecleado. ⚠️ Se hace en `blur` y no
  // en `input`: recortando mientras se escribe, teclear «40» en un hueco de 25
  // convierte el 4 en 25 y el resultado es «254».
  ajustarAlSalir() {
    const tope = this.#loQueQueda()
    const valor = Number(this.pesoTarget.value)
    if (!Number.isFinite(valor) || valor <= tope) return

    this.pesoTarget.value = Number(tope.toFixed(2))
    this.#moverElRango()
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
    this.#toparElRango()

    this.medidorTarget.hidden = false
    this.barraUsadoTarget.style.width = `${Math.min(usado, 100)}%`
    this.barraNuevoTarget.style.width = `${Math.min(nuevo, Math.max(libre, 0))}%`
    this.barraNuevoTarget.classList.toggle("weight-meter-fill--excedido", total > 100)

    this.leyendaTarget.textContent = this.#leyenda(usado, nuevo, total, libre)
    this.leyendaTarget.classList.toggle("weight-meter-value--excedido", total > 100)
  }

  // Al cambiar de lapso también cambia lo que queda libre, así que la propuesta
  // se vuelve a calcular.
  lapsoCambio() {
    this.pesoTarget.value = ""
    this.proponerElPeso()
    this.recalcular()
  }

  #asignacionActual() {
    return this.asignacionesValue[this.asignacionTarget.value] || null
  }

  #leyenda(usado, nuevo, total, libre) {
    const n = (v) => (Number.isInteger(v) ? v : v.toFixed(2))

    if (total > 100) {
      return `Ya hay ${n(usado)} % comprometido: quedan ${n(libre)} % y está pidiendo ${n(nuevo)} %.`
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
