import { Controller } from "@hotwired/stimulus"

// Los identificadores que el colegio YA usa, como pastillas.
//
//     Sección   (A) (B) (C) (Otra…)
//                            └─ al tocarla aparece el campo
//
// ## ⚠️ Por qué pastillas y no un `datalist`
//
// El `datalist` ofrece lo que ya se usa sin encerrar —un colegio puede abrir su
// primera «D»— y esa parte está bien. Lo que no funciona es dónde se usa: en un
// teléfono el `datalist` no se ve hasta que se empieza a teclear, así que el
// «autoaprendizaje» que lo justificaba no existe para quien arma las secciones
// desde el teléfono en septiembre.
//
// ⚠️ El campo de texto SIGUE SIENDO el valor. Las pastillas solo lo escriben:
// sin JavaScript el campo se ve y se llena como siempre, y el formulario manda
// exactamente lo mismo.
export default class extends Controller {
  static targets = ["campo", "pastilla", "otra"]

  connect() { this.#pintar(this.campoTarget.value.trim().toUpperCase()) }

  elegir(evento) {
    const valor = evento.params.valor
    this.campoTarget.value = valor
    this.#pintar(valor)
  }

  otra() {
    this.campoTarget.value = ""
    this.#pintar(null)
    this.campoTarget.focus()
  }

  // Escribir a mano también apaga la pastilla: si el campo dice «D», ninguna de
  // las que están arriba puede seguir marcada.
  escribir() { this.#pintar(this.campoTarget.value.trim().toUpperCase()) }

  #pintar(valor) {
    let alguna = false

    this.pastillaTargets.forEach((pastilla) => {
      const suya = pastilla.dataset.valor === valor
      pastilla.classList.toggle("elegida", suya)
      if (suya) alguna = true
    })

    // ⚠️ Son al REVÉS el uno del otro, y escribirlos iguales fue el bug: con
    // una pastilla marcada se escondían los dos, así que no había forma de
    // volver al campo libre — el colegio que abre su primera «D» quedaba
    // encerrado en lo que ya usaba, que es justo lo que este control existe
    // para evitar.
    this.campoTarget.parentElement.hidden = alguna
    this.otraTarget.hidden = !alguna
  }
}
