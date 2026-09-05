import { Controller } from "@hotwired/stimulus"

// Un textarea que crece con lo que se escribe (MOR-136).
//
// ## Por qué hace falta acá
//
// El campo de indicadores es una lista: una línea por indicador. Con alto fijo,
// la maestra que escribe el quinto ya no ve el primero — y lo que este campo
// tiene de bueno es justamente que se ve la lista completa mientras se arma.
//
// ⚠️ Se ajusta también al CONECTAR, no solo al escribir. Al editar, el campo
// llega con tres líneas ya puestas desde el servidor, y sin esto aparece
// recortado a la altura por defecto: la maestra cree que perdió indicadores.
export default class extends Controller {
  connect() { this.crecer() }

  crecer() {
    // ⚠️ Primero `auto`, después la medida. Sin resetear, `scrollHeight` nunca
    // baja —siempre devuelve al menos el alto actual— así que el campo crece al
    // agregar una línea y NO se encoge al borrarla.
    this.element.style.height = "auto"
    this.element.style.height = `${this.element.scrollHeight}px`
  }
}
