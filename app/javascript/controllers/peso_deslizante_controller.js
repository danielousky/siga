import { Controller } from "@hotwired/stimulus"

// El peso, con un deslizador al lado del número (23 de septiembre).
//
// Daniel: *«en el porcentaje podemos agregar un rango en la misma línea,
// pequeño; podemos robarle un poco de espacio al texto y que la persona
// deslice en lugar de escribir»*.
//
//     Examen del lapso        ▬▬▬●▬▬▬  40 %   5 nov   [5 de 30]  🗑
//                             ▲        ▲
//                             │        └─ sigue siendo el campo: se teclea
//                             └─ y ahora también se arrastra
//
// ## ⚠️ El número es el dato; el rango es otra manera de moverlo
//
// El deslizador NO lleva `name`, y por eso no se envía: con los dos mandando
// `weight_percentage`, el formulario llevaría el peso dos veces y el servidor
// se quedaría con el último del marcado — que puede ser el que el profesor no
// tocó. Un control sin `name` no entra en el envío; es la regla del HTML, no
// un truco.
export default class extends Controller {
  static targets = ["rango", "numero"]

  connect() {
    this.#copiarElTope()

    // ⚠️ El tope del número NO es 100: es lo que QUEDA contando a las otras
    // evaluaciones, y lo recalcula `reparto` en vivo cada vez que cualquiera
    // de ellas cambia. El rango tiene que respetar ese mismo tope, o arrastrar
    // vuelve a permitir pasarse del 100 % — justo lo que `#toparLosCampos`
    // existe para impedir. Se MIRA el que ya está puesto en vez de calcularlo
    // otra vez acá: dos cuentas del mismo número se separan el día que una
    // cambie.
    this.vigia = new MutationObserver(() => this.#copiarElTope())
    this.vigia.observe(this.numeroTarget, { attributeFilter: [ "min", "max" ] })
  }

  disconnect() {
    this.vigia?.disconnect()
  }

  // Arrastrar escribe en el número y avisa como si se hubiera tecleado: así la
  // barra del reparto se mueve por el mismo camino de siempre y no hace falta
  // enseñarle a `reparto` que existe un deslizador.
  mover() {
    this.numeroTarget.value = this.rangoTarget.value
    this.numeroTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  // Y al revés: tecleando, el deslizador acompaña.
  escribir() {
    this.rangoTarget.value = this.numeroTarget.value
  }

  #copiarElTope() {
    this.rangoTarget.min = this.numeroTarget.min || 1
    this.rangoTarget.max = this.numeroTarget.max || 100
    this.rangoTarget.value = this.numeroTarget.value
  }
}
