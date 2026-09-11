import { Controller } from "@hotwired/stimulus"
import { contieneSinAcentos } from "lib/sin_acentos"

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

  // ⚠️ Enter en el buscador NO envía el formulario.
  //
  // Un campo de texto dentro de un `<form>` dispara el «envío implícito» del
  // navegador al pulsar Enter, y eso acá es grave: en el alta de inscripción el
  // primer botón de la lista es «Inscribir», así que buscar un apellido y
  // pulsar Enter —el gesto más natural del mundo— inscribía al primer alumno de
  // la pantalla.
  //
  // El buscador filtra mientras se escribe: Enter no tiene nada que hacer.
  sinEnviar(evento) {
    if (evento.key === "Enter") evento.preventDefault()
  }

  filtrar() {
    const q = this.buscarTarget.value.trim()
    let visibles = 0

    this.itemTargets.forEach((item) => {
      const marcado = item.querySelector("input[type=checkbox]")?.checked
      // ⚠️ Ignorando acentos, como el buscador del servidor. Con
      // `toLowerCase().includes()` a secas, escribir «sofia» no encontraba a
      // Sofía — y en Venezuela eso deja afuera a López, Pérez, Guzmán,
      // Rodríguez, Martínez, Hernández, Díaz y Gómez. Ver `lib/sin_acentos`.
      const coincide = q === "" || contieneSinAcentos(item.textContent, q)
      const mostrar = marcado || coincide

      item.hidden = !mostrar
      if (mostrar) visibles++
    })

    if (this.hasVacioTarget) this.vacioTarget.hidden = visibles > 0
  }
}
