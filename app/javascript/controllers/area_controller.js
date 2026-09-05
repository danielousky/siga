import { Controller } from "@hotwired/stimulus"

// El área y sus secciones, en el formulario de una evaluación (MOR-223).
//
// Daniel: *«esto lo separamos en 2 selects: si el profe solo da una materia
// pues vamos directo, pero si dicta más de una, le colocamos el select previo»*.
//
// Al cambiar de área, las secciones son otras. El mapa viaja embebido en el
// formulario —igual que `ponderacion` y `que-evalua`— porque la elección ocurre
// en esta pantalla: pedirle al servidor la lista en cada cambio sería un viaje
// para no cambiar de tema.
//
// ⚠️ Si el profesor dicta UNA sola área, este select no existe: `areaTarget` no
// está y `connect` no hace nada. Por eso todas las lecturas van con `has…`
// antes — un controlador que revienta sin su target se lleva la aplicación
// Stimulus entera, y con ella el medidor de peso y el plan de competencias del
// mismo formulario.
export default class extends Controller {
  static targets = ["area", "seccion"]
  static values  = { secciones: Object }

  cambio() {
    if (!this.hasAreaTarget || !this.hasSeccionTarget) return

    const elegida = this.seccionTarget.value
    const opciones = this.seccionesValue[this.areaTarget.value] || []

    this.seccionTarget.innerHTML = ""
    this.seccionTarget.appendChild(new Option("Elige una de tus secciones...", ""))

    opciones.forEach(({ valor, nombre }) => {
      const opcion = new Option(nombre, valor)
      // Conservar lo elegido si sigue existiendo: cambiar de área y volver no
      // puede perder la sección que ya se había marcado.
      if (valor === elegida) opcion.selected = true
      this.seccionTarget.appendChild(opcion)
    })

    // Avisarle a los otros controladores del mismo formulario: el medidor de
    // peso y el plan de competencias cuelgan de la sección, no del área.
    this.seccionTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
