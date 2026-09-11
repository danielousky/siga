import { Controller } from "@hotwired/stimulus"

// Una planilla que se guarda sola, campo por campo.
//
// Es UNO para las tres —notas, informes descriptivos y Educación Inicial—
// donde antes había dos controladores de 151 y 122 líneas que hacían lo mismo
// con `fetch` a mano y un JSON propio cada uno.
//
//     escribir  ──►  salir del campo  ──►  se guarda  ──►  ✓
//                         │
//                         └─ sin conexión ──► ⟳  queda en cola
//                                              y se reintenta al volver
//
// ## ⚠️ Por qué el envío lo hace TURBO y no un `fetch` escrito acá
//
// Cada fila es un `<form>` de verdad, y `requestSubmit()` deja que Turbo lo
// mande. Con eso el CSRF, los encabezados y la respuesta dejan de ser trabajo
// nuestro — eran treinta líneas por controlador, copiadas, y en una de las dos
// copias faltaba el `Accept`.
//
// Lo que queda acá es lo que NINGÚN transporte da: la cola de pendientes, el
// aviso al salir de la página y la navegación con el teclado.
//
// ## ⚠️ Y por qué STREAMS y no reemplazar el frame entero
//
// La planilla de notas son treinta filas y el profesor las recorre con Enter.
// Un frame que se reemplaza entero repinta las treinta en cada tecla y se lleva
// el foco del campo siguiente — que es justo lo que hace usable la pantalla. El
// servidor contesta un stream que toca solo la marca de estado y el contador,
// que son los dos únicos pedazos que no tienen el foco.
export default class extends Controller {
  static targets = ["fila", "campo", "aviso", "avisoTexto"]

  connect() {
    // campo → el valor que no se pudo guardar
    this.pendientes = new Map()
    this.campoTargets.forEach((campo) => { campo.dataset.guardado = campo.value })

    this._avisarAlSalir = this._avisarAlSalir.bind(this)
    this._alVolverLaRed = () => this.reintentarTodo()
    window.addEventListener("beforeunload", this._avisarAlSalir)
    window.addEventListener("online", this._alVolverLaRed)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this._avisarAlSalir)
    window.removeEventListener("online", this._alVolverLaRed)
  }

  // ── Escribir y salir ──────────────────────────────────────────────────────

  // ⚠️ Escribir borra el «✓» de la vez anterior: dejarlo puesto mientras se
  // teclea afirma algo que ya dejó de ser cierto.
  escribir(evento) {
    this.#marcar(evento.target, "")
  }

  // ⚠️ Solo si CAMBIÓ. Entrar a un campo, mirarlo y salir no es editar; sin esa
  // comprobación, tabular por la planilla deja treinta guardados y treinta
  // líneas en la auditoría de notas que nadie tocó.
  guardar(evento) {
    const campo = evento.target

    if (campo.value === campo.dataset.guardado) return

    this.#enviar(campo)
  }

  // Enter y las flechas mueven entre alumnos sin tocar el mouse: cargar treinta
  // notas pasando por el mouse en cada una es lo que hace que un profesor
  // abandone a la mitad.
  navegar(evento) {
    const salto = { Enter: 1, ArrowDown: 1, ArrowUp: -1 }[evento.key]
    if (!salto) return
    // ⚠️ En un textarea, la flecha mueve el cursor DENTRO del texto y Enter
    // hace un párrafo: un informe descriptivo son tres renglones, y saltar de
    // alumno al bajar una línea sería inutilizable.
    if (evento.target.tagName === "TEXTAREA" && evento.key !== "Enter") return

    evento.preventDefault()
    const campos = this.campoTargets
    const siguiente = campos[campos.indexOf(evento.target) + salto]

    if (!siguiente) return evento.target.blur()   // el último guarda al salir

    // ⚠️ Cada campo necesita un `id` PROPIO para que esto funcione, y ahí me
    // equivoqué una vez: `number_field_tag :score` le pone `id="score"` a los
    // treinta. Turbo, después de pintar un stream, vuelve a enfocar por `id`
    // —para no perder el foco si el elemento enfocado fue reemplazado— y
    // `getElementById("score")` devuelve SIEMPRE el primero de la página. El
    // foco saltaba al alumno siguiente y volvía solo al primero de la lista.
    siguiente.focus()
    if (siguiente.select) siguiente.select()
  }

  reintentarTodo() {
    const campos = [ ...this.pendientes.keys() ]
    this.pendientes.clear()
    this.#actualizarAviso()
    campos.forEach((campo) => this.#enviar(campo))
  }

  // ── Lo que Turbo avisa ────────────────────────────────────────────────────

  // Del estado del envío, el cliente pinta los dos que el servidor no puede
  // saber: mientras viaja, y cuando no llegó.
  enviando(evento) {
    this.#marcarFila(evento.target, "guardando")
  }

  llego(evento) {
    const campo = this.#campoDe(evento.target)
    if (!campo) return

    if (evento.detail.success) {
      // La marca definitiva la pintó el servidor por stream; acá solo se
      // recuerda qué quedó guardado, para no reenviarlo.
      campo.dataset.guardado = campo.value
      this.pendientes.delete(campo)
    } else {
      // ⚠️ Un rechazo del servidor NO va a la cola: reintentarlo no lo arregla
      // —un 25 sigue estando fuera de la escala— y quedaría reintentándose
      // solo, para siempre. El servidor ya dijo por qué, en su marca.
      this.pendientes.delete(campo)
    }

    this.#actualizarAviso()
  }

  // Sin red: Turbo no llega ni a tener respuesta. Lo escrito se queda en
  // pantalla y en la cola.
  sinRed(evento) {
    const campo = this.#campoDe(evento.target)
    if (!campo) return

    this.pendientes.set(campo, campo.value)
    this.#marcar(campo, "sin_red")
    this.#actualizarAviso()
  }

  // ── internos ──────────────────────────────────────────────────────────────

  // ⚠️ `requestSubmit()` NO envía un formulario inválido, y no avisa.
  //
  // El campo de una nota declara `min=1 max=20`, así que escribir 25 y salir
  // deja al navegador bloqueando el envío **en silencio**: el valor se queda en
  // pantalla y la marca sigue diciendo «✓ Guardado» de la vez anterior. O sea,
  // la pantalla afirma que se guardó un 25 que no existe.
  //
  // Con el `fetch` a mano de antes esto no pasaba —se saltaba la validación
  // nativa y contestaba el servidor—, así que es la trampa exacta de mover el
  // envío a Turbo. Acá se pregunta primero y el motivo lo da el navegador, que
  // además lo dice en español y sin ir al servidor.
  #enviar(campo) {
    const formulario = campo.closest("form")
    if (!formulario) return

    if (!formulario.checkValidity()) {
      this.#marcar(campo, "rechazado", campo.validationMessage)
      return
    }

    formulario.requestSubmit()
  }

  #campoDe(formulario) {
    return this.campoTargets.find((campo) => campo.closest("form") === formulario)
  }

  #marcarFila(formulario, estado) {
    const campo = this.#campoDe(formulario)
    if (campo) this.#marcar(campo, estado)
  }

  // ⚠️ Se busca la marca DENTRO de la fila y no por `id`: el stream del
  // servidor la reemplaza por otra con el mismo `id`, así que guardarse una
  // referencia dejaría escribiendo sobre un elemento que ya no está en la
  // página.
  #marcar(campo, estado, mensaje = null) {
    const marca = campo.closest("[data-planilla-target='fila']")?.querySelector(".planilla-estado")
    if (!marca) return

    marca.dataset.estado = estado
    marca.textContent = MARCAS[estado] || ""
    marca.dataset.tooltip = mensaje || AVISOS[estado] || ""
  }

  #actualizarAviso() {
    if (!this.hasAvisoTarget) return

    const cuantas = this.pendientes.size
    this.avisoTarget.hidden = cuantas === 0
    if (cuantas === 0) return

    this.avisoTextoTarget.textContent =
      `${cuantas} ${cuantas === 1 ? "quedó" : "quedaron"} sin guardar: no hay conexión. ` +
      "Lo escrito no se perdió y se reintenta solo al volver."
  }

  _avisarAlSalir(evento) {
    if (this.pendientes.size === 0) return
    evento.preventDefault()
    evento.returnValue = ""
  }
}

// ⚠️ Los mismos símbolos que pinta el servidor (`PlanillaHelper::MARCAS`), y es
// la única duplicación que queda: son dos estados que el servidor no produce
// nunca, así que no hay respuesta de donde sacarlos. Si cambian allá, cambian
// acá — lo cuida `marcas_de_la_planilla_test`.
const MARCAS = { guardando: "…", guardado: "✓", vacio: "—", sin_red: "⟳", rechazado: "!" }
const AVISOS = {
  guardando: "Guardando…",
  guardado: "Guardado",
  vacio: "Sin llenar",
  sin_red: "Sin conexión: queda pendiente y se reintenta solo",
  rechazado: "No se pudo guardar"
}
