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
    const limpio = campo.value.normalize("NFC").trim().replace(/\s+/g, " ")
    if (limpio !== campo.value) campo.value = limpio
  }

  connect() {
    // ⚠️ La composición se escucha ACÁ y no en el `action` de la vista.
    //
    // Que el campo tenga que enterarse de si hay una tecla muerta a medio
    // componer es un detalle de CÓMO se filtra, no algo que las seis vistas que
    // usan este controlador deban saber — y si tuvieran que declararlo, la
    // próxima se olvidaría y el bug volvería en un solo formulario.
    this.componiendo = false
    this.alEmpezarAComponer = () => { this.componiendo = true }
    this.alTerminarDeComponer = () => { this.componiendo = false; this.filtrar() }
    this.element.addEventListener("compositionstart", this.alEmpezarAComponer)
    this.element.addEventListener("compositionend", this.alTerminarDeComponer)

    // Lo que ya venía escrito —un valor recuperado tras un error de
    // validación— también se limpia: si no, el campo arranca con lo que
    // justamente se está impidiendo escribir.
    this.filtrar()
  }

  disconnect() {
    this.element.removeEventListener("compositionstart", this.alEmpezarAComponer)
    this.element.removeEventListener("compositionend", this.alTerminarDeComponer)
  }

  // ⚠️ Mientras se compone una tecla muerta, NO se toca el campo (MOR-191).
  //
  // Daniel: *«debe permitir poder agregar acentos, lo intenté y me sale sin
  // acento»*. En un teclado español, «É» son dos pulsaciones: ´ y después E.
  // Entre las dos, el navegador dispara `input` con un `´` suelto en el
  // valor — que no está en la lista de permitidos, así que se borraba. Y
  // asignar `value` en ese momento **cancela la composición**, de modo que la
  // E siguiente llegaba sola. Escribir JOSÉ daba JOSE.
  filtrar() {
    if (this.componiendo) return

    const campo = this.element
    const antes = campo.value
    const cursor = campo.selectionStart ?? antes.length

    // ⚠️ Y a NFC, o el acento se pierde igual aunque esté permitido.
    //
    // macOS entrega «É» descompuesta: una E más una tilde combinante aparte
    // (U+0301). Esa tilde es un carácter que la lista no menciona, así que el
    // filtro la borraba y dejaba la E pelada — el mismo síntoma por otro
    // camino, y el que se lleva también lo que se PEGA desde otro lado.
    //
    // Normalizado a NFC son un solo carácter, «É», que sí está permitido.
    // Además es la forma con la que el buscador sabe comparar: `translate()`
    // mapea acentos precompuestos, así que un «LÓPEZ» descompuesto se guarda
    // bien, se ve bien y **no lo encuentra nadie**.
    const normalizado = antes.normalize("NFC")
    const sobra = new RegExp(`[^${this.permiteValue}]`, "g")

    let despues = this.permiteValue === "" ? normalizado : normalizado.replace(sobra, "")
    if (this.mayusculaValue) despues = despues.toUpperCase()
    if (despues === antes) return

    // ⚠️ El cursor, o escribir en el medio se vuelve inusable.
    //
    // Asignar `value` lo manda al final. Quien corrige el primer carácter de
    // «B1» escribiría el siguiente al final y terminaría con algo peor que lo
    // que estaba arreglando. Se cuenta cuántos caracteres SOBREVIVEN de lo que
    // había antes del cursor y se lo devuelve a su lugar.
    //
    // Se mide sobre el texto ya normalizado: si venía descompuesto, la E y su
    // tilde eran dos caracteres y ahora son uno.
    const hastaElCursor = antes.slice(0, cursor).normalize("NFC")
    const quedan = this.permiteValue === ""
      ? hastaElCursor.length
      : hastaElCursor.replace(sobra, "").length

    campo.value = despues
    campo.setSelectionRange(quedan, quedan)
  }
}
