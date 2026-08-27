import { Controller } from "@hotwired/stimulus"

// El menú lateral: qué queda plegado, y el navbar del teléfono (MOR-149).
//
// ## Lo que este controlador NO hace: abrir y cerrar
//
// Eso lo hace `<details>`, que es del navegador: anda sin JavaScript, responde
// al teclado solo, y no puede quedar diciendo «abierto» mientras se ve cerrado.
// Acá solo se anota lo que ya pasó y se coordinan los grupos entre sí.
//
// ## Por qué una COOKIE y no `localStorage`
//
// Quien dibuja el `open` de cada grupo es el SERVIDOR. Con `localStorage` el
// servidor no sabe nada: la página llega con todos los grupos abiertos y el
// JavaScript los cierra después de pintar — un salto visible en cada carga.
// Con cookie la página llega ya dibujada como quedó.
//
// ## Y por qué en el teléfono se comporta distinto
//
// Ahí la barra es un navbar: cinco chips, y el que se toca despliega sus
// pantallas en cajas de lado a lado. Dos desplegables abiertos a la vez se
// taparían entre sí, así que abrir uno cierra los otros — y aterrizar con uno
// abierto taparía la primera fila de datos, así que al llegar se cierran todos.
export default class extends Controller {
  static targets = ["grupo"]
  static CLAVE = "menu_plegado"
  static ANGOSTO = 768

  connect() {
    this.enDocumento = this.alTocarAfuera.bind(this)
    this.enTecla = this.alPresionarTecla.bind(this)

    document.addEventListener("click", this.enDocumento)
    document.addEventListener("keydown", this.enTecla)

    this.cerrarTodoEnTelefono()
  }

  disconnect() {
    document.removeEventListener("click", this.enDocumento)
    document.removeEventListener("keydown", this.enTecla)
  }

  get enTelefono() {
    return window.innerWidth <= this.constructor.ANGOSTO
  }

  // El servidor abre el grupo de la pantalla actual porque en escritorio es lo
  // correcto —esconder dónde estás parado es peor que un menú largo—. En el
  // navbar del teléfono ese mismo grupo llegaría desplegado sobre el contenido.
  cerrarTodoEnTelefono() {
    if (this.enTelefono) this.cerrarTodo()
  }

  cerrarTodo() {
    this.grupoTargets.forEach((grupo) => { grupo.open = false })
  }

  // ⚠️ Cerrar un grupo dispara su propio `toggle`, que vuelve acá. No hay
  // recursión porque en el teléfono se sale antes de tocar nada más, y en
  // escritorio nadie cierra grupos por su cuenta.
  alTogglear(evento) {
    const grupo = evento.target

    if (this.enTelefono) {
      if (grupo.open) {
        this.grupoTargets.forEach((otro) => { if (otro !== grupo) otro.open = false })
      }
      // El navbar no recuerda nada: arranca cerrado en cada pantalla.
      return
    }

    this.recordar(grupo)
  }

  // Tocar fuera cierra, que es lo que hace cualquier menú desplegable. Solo en
  // el teléfono: en escritorio el acordeón es parte de la página, no una capa.
  alTocarAfuera(evento) {
    if (!this.enTelefono) return
    if (this.element.contains(evento.target)) return

    this.cerrarTodo()
  }

  alPresionarTecla(evento) {
    if (evento.key !== "Escape" || !this.enTelefono) return

    this.cerrarTodo()
  }

  // ── lo que se recuerda ────────────────────────────────────────────────

  recordar(grupo) {
    const plegados = new Set(this.leer())

    if (grupo.open) plegados.delete(grupo.id)
    else plegados.add(grupo.id)

    const anio = 60 * 60 * 24 * 365
    document.cookie =
      `${this.constructor.CLAVE}=${encodeURIComponent([...plegados].join(","))}` +
      `; path=/; max-age=${anio}; samesite=lax`
  }

  leer() {
    const galleta = document.cookie
      .split("; ")
      .find((c) => c.startsWith(`${this.constructor.CLAVE}=`))

    if (!galleta) return []

    return decodeURIComponent(galleta.split("=")[1]).split(",").filter(Boolean)
  }
}
