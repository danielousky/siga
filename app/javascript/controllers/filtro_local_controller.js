import { Controller } from "@hotwired/stimulus"

// Filtra en el navegador una lista que ya está en la página.
//
// No es el `search-filter` de los listados: aquel manda una petición al
// servidor con Turbo, y acá no hay a dónde ir — las 200 casillas de alumnos ya
// están dentro del formulario, y sacarlas rompería lo que el usuario lleva
// marcado.
//
// Lo marcado NO se filtra nunca: una casilla que desaparece al escribir parece
// que se desmarcó, y quien está registrando a un representante con tres hijos
// necesita ver los tres mientras busca al cuarto.
export default class extends Controller {
  static targets = ["buscar", "item", "vacio"]

  filtrar() {
    const q = this.buscarTarget.value.trim().toLowerCase()
    let visibles = 0

    this.itemTargets.forEach((item) => {
      const marcado = item.querySelector("input[type=checkbox]")?.checked
      const coincide = q === "" || item.textContent.toLowerCase().includes(q)
      const mostrar = marcado || coincide

      item.hidden = !mostrar
      if (mostrar) visibles++
    })

    if (this.hasVacioTarget) this.vacioTarget.hidden = visibles > 0
  }
}
