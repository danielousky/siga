import { Controller } from "@hotwired/stimulus"

// El menú lateral que se encoge a solo iconos (MOR-149).
//
// ## Por qué el estado vive en localStorage y no en la sesión
//
// Es una preferencia de ESTA pantalla, no de esta persona: la misma secretaria
// quiere el menú ancho en el monitor del escritorio y encogido en la laptop de
// 13", y guardarlo en el servidor le daría el mismo ancho en las dos.
//
// Además no vale una petición: nadie quiere esperar a que el servidor confirme
// que sí, que quiere el menú angosto.
//
// ## Por qué la clase va en <html> y no en el <aside>
//
// El `main` también tiene que reaccionar —gana el ancho que el menú suelta— y
// desde el aside no se puede alcanzar a un hermano anterior sin `:has()`, que
// todavía no está en todos los navegadores que un colegio venezolano usa.
export default class extends Controller {
  static targets = ["boton"]
  static values = { clave: { type: String, default: "siga:menu-encogido" } }

  connect() {
    // ⚠️ Se lee en `connect` y no en el layout porque Turbo conserva el DOM
    // entre navegaciones: si esto viviera en un `<script>` del layout, el menú
    // volvería a expandirse en cada visita.
    this.aplicar(localStorage.getItem(this.claveValue) === "si")
  }

  alternar() {
    const encogido = !document.documentElement.classList.contains("menu-encogido")

    this.aplicar(encogido)
    localStorage.setItem(this.claveValue, encogido ? "si" : "no")
  }

  aplicar(encogido) {
    document.documentElement.classList.toggle("menu-encogido", encogido)

    if (!this.hasBotonTarget) return

    // `aria-expanded` va en el BOTÓN y describe lo que el botón controla, no
    // cómo se ve el botón. Sin esto, quien navega con lector de pantalla no
    // tiene forma de saber si el menú está abierto o cerrado.
    this.botonTarget.setAttribute("aria-expanded", String(!encogido))
    this.botonTarget.setAttribute(
      "aria-label",
      encogido ? "Expandir el menú" : "Encoger el menú"
    )
  }
}
