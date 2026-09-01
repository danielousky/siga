import { Controller } from "@hotwired/stimulus"

// Un campo que solo deja escribir ciertos caracteres (MOR-170).
//
// Daniel, probando el identificador de sección: «permite espacios iniciales y
// caracteres raros». Y tenía razón: `pattern` es validación del NAVEGADOR —
// impide enviar, no escribir— así que se podía teclear «A Ñ{*}¡» y descubrir el
// error recién al guardar.
//
//     <input data-controller="campo-filtrado"
//            data-campo-filtrado-permite-value="A-Za-z0-9"
//            data-campo-filtrado-mayuscula-value="true">
//
// `permite` es el CUERPO de una clase de caracteres, y el controlador arma la
// negación. Se declara lo permitido y no lo prohibido a propósito: la lista de
// lo que no se quiere es infinita, y siempre falta un símbolo.
//
// ⚠️ No reemplaza a la validación del modelo ni al `pattern`. Son tres capas y
// cada una tapa lo que la anterior no puede: esto es lo que se VE al escribir,
// `pattern` ataja el envío, y el modelo ataja lo que llegue por otra puerta.
export default class extends Controller {
  // ⚠️ `permite` VACÍO significa «no filtres nada, solo normaliza».
  //
  // El nombre de una materia es texto libre —«Castellano y Literatura», con
  // acentos y espacios— pero se guarda en mayúscula. Sin este caso habría que
  // inventar una clase de caracteres que permita todo, que es una manera
  // enredada de decir «ninguna».
  static values = {
    permite: { type: String, default: "" },
    mayuscula: { type: Boolean, default: false }
  }

  // Al SALIR del campo: quita los espacios de los bordes y junta los dobles.
  //
  // ⚠️ No se puede hacer mientras se escribe. Un nombre lleva espacios en el
  // medio —«JOSÉ LUIS», «DE LA CRUZ»— así que recortar en cada tecla impediría
  // escribir el segundo nombre: la barra desaparecería apenas pulsada.
  //
  // Hace lo mismo que `Normaliza.mayuscula` en el servidor: `strip`, juntar
  // espacios, mayúscula. Que las dos capas coincidan es lo que evita que el
  // campo muestre una cosa y se guarde otra.
  recortar() {
    const campo = this.element
    const limpio = campo.value.trim().replace(/\s+/g, " ")
    if (limpio !== campo.value) campo.value = limpio
  }

  connect() {
    // Lo que ya venía escrito —un valor recuperado tras un error de
    // validación— también se limpia: si no, el campo arranca con lo que
    // justamente se está impidiendo escribir.
    this.filtrar()
  }

  filtrar() {
    const campo = this.element
    const antes = campo.value
    const sobra = new RegExp(`[^${this.permiteValue}]`, "g")

    let despues = this.permiteValue === "" ? antes : antes.replace(sobra, "")
    if (this.mayusculaValue) despues = despues.toUpperCase()
    if (despues === antes) return

    // ⚠️ El cursor, o escribir en el medio se vuelve inusable.
    //
    // Asignar `value` lo manda al final. Quien corrige el primer carácter de
    // «B1» escribiría el siguiente al final y terminaría con algo peor que lo
    // que estaba arreglando. Se cuenta cuántos caracteres se quitaron ANTES del
    // cursor y se lo devuelve a su lugar.
    const cursor = campo.selectionStart ?? antes.length
    const quitados = this.permiteValue === ""
      ? cursor
      : antes.slice(0, cursor).replace(sobra, "").length
    campo.value = despues
    campo.setSelectionRange(quitados, quitados)
  }
}
