import { Controller } from "@hotwired/stimulus"

// En secundaria la escala es siempre numérica (MOR-129).
//
// No existe la calificación literal en bachillerato, así que ofrecerla es
// ofrecer un error: el modelo la rechaza igual, pero después de que la persona
// llenó el formulario entero.
//
// La opción se ESCONDE en vez de deshabilitarse el `<select>`. Un select
// deshabilitado no envía su valor, así que el formulario llegaría sin escala y
// el grado se guardaría con el default de la columna — el problema que este
// campo vino a arreglar, por otra puerta.
export default class extends Controller {
  static targets = ["nivel", "escala", "aviso"]

  connect() {
    this.ajustar()
  }

  ajustar() {
    const secundaria = this.nivelTarget.value === "secundaria"
    const literal = this.escalaTarget.querySelector('option[value="literal"]')

    if (secundaria && this.escalaTarget.value === "literal") {
      this.escalaTarget.value = "numerica"
    }

    literal.hidden = secundaria
    literal.disabled = secundaria
    this.avisoTarget.hidden = !secundaria
  }
}
