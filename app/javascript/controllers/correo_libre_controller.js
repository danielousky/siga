import { Controller } from "@hotwired/stimulus"

// ¿Ese correo está libre? — se pregunta al SALIR del campo (MOR-208).
//
// Daniel: «tiene que ser una validación muy rápida. Cuando él lo transcriba,
// después que lo transcriba, validamos de una vez allí si el correo está
// correcto y no existe».
//
// ⚠️ Al salir del campo (`blur`) y NO en cada tecla. Preguntando al teclear se
// consulta el servidor una vez por letra —«d», «da», «dan»…— y todas esas
// respuestas dicen «libre» sobre un correo a medio escribir, así que el aviso
// parpadea mientras la persona todavía está escribiendo.
//
// ⚠️ Y el aviso NUNCA impide enviar. Si el servidor no contesta —la conexión de
// un colegio se corta— el formulario tiene que seguir funcionando: la validación
// de verdad la hace el modelo al guardar. Esto ahorra un viaje, no lo reemplaza.
export default class extends Controller {
  // ⚠️ El controlador vive en el `.form-group`, no en el `<input>`: un target
  // tiene que ser DESCENDIENTE del elemento del controlador, y un `<input>` no
  // tiene hijos. Con el controlador en el campo, `hasAvisoTarget` era false y
  // esto no mostraba nada — sin ningún error, porque para Stimulus «no hay
  // target» es una situación normal.
  static targets = ["campo", "aviso"]
  static values = { url: String }

  async comprobar() {
    const correo = this.campoTarget.value.trim()
    if (!correo) return this.callar()

    try {
      const url = `${this.urlValue}?email=${encodeURIComponent(correo)}`
      const r = await fetch(url, { headers: { Accept: "application/json" } })
      if (!r.ok) return this.callar()

      const { libre, formato } = await r.json()

      if (!formato) this.decir("Eso no parece un correo. Revise que tenga arroba y punto.", false)
      else if (!libre) this.decir("Ese correo ya tiene una cuenta en SIGA. ¿Quiere iniciar sesión?", false)
      else this.decir("Correo disponible.", true)
    } catch {
      // Sin conexión no se dice nada: un aviso rojo por una red mala asusta más
      // de lo que ayuda, y el modelo lo va a atajar igual.
      this.callar()
    }
  }

  decir(texto, bien) {
    if (!this.hasAvisoTarget) return

    this.avisoTarget.textContent = texto
    this.avisoTarget.classList.toggle("campo-aviso--bien", bien)
    this.avisoTarget.classList.toggle("campo-aviso--mal", !bien)
    this.avisoTarget.hidden = false
  }

  callar() {
    if (this.hasAvisoTarget) this.avisoTarget.hidden = true
  }
}
