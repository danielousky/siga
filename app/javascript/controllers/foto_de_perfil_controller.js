import { Controller } from "@hotwired/stimulus"

// La foto de perfil, con lo que se eligió a la vista antes de guardar.
//
//     ╭────────╮   [↑ Subir una foto]      PNG, JPG o WEBP
//     │   AL   │   [🗑 Quitar]             hasta 2 MB
//     ╰────────╯
//
// ## ⚠️ Sin vista previa, elegir un archivo no hace NADA visible
//
// El `<input type="file">` nativo muestra el nombre del archivo en letra chica
// del sistema y nada más. Quien sube la foto de su hijo no sabe si agarró la
// correcta hasta que guarda, vuelve a la ficha y mira — y si se equivocó,
// repite el viaje entero. Acá la foto aparece en el avatar en el acto.
//
// ⚠️ El avatar NO se reemplaza: la foto y las iniciales conviven en el DOM y se
// alterna cuál se ve. Reconstruirlo perdería el color derivado del nombre
// (`AvataresHelper#color_de`), que es estable a propósito.
export default class extends Controller {
  static targets = ["campo", "foto", "iniciales", "quitar", "botonDeQuitar"]

  elegir() {
    const archivo = this.campoTarget.files[0]
    if (!archivo) return

    // Elegir una foto ANULA el «quitar» pendiente: son la misma decisión y la
    // última gana. Sin esto, quitar y después subir guardaba… nada.
    this.quitarTarget.value = "0"
    this.mostrar(URL.createObjectURL(archivo))
  }

  quitar() {
    this.campoTarget.value = ""
    this.quitarTarget.value = "1"
    this.mostrar(null)
  }

  mostrar(url) {
    if (url) {
      // ⚠️ El objeto anterior se libera: cada `createObjectURL` reserva memoria
      // hasta que se revoca, y quien prueba cinco fotos deja cinco colgando.
      if (this.previa) URL.revokeObjectURL(this.previa)
      this.previa = url
      this.fotoTarget.src = url
    }

    this.fotoTarget.hidden = !url
    this.inicialesTarget.hidden = !!url
    this.botonDeQuitarTarget.hidden = !url
  }

  disconnect() {
    if (this.previa) URL.revokeObjectURL(this.previa)
  }
}
