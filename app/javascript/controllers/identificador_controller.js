import { Controller } from "@hotwired/stimulus"

// UN campo para las dos cédulas, y decir cuál se reconoció mientras se escribe.
//
//     12345678        →  Cédula de identidad
//     V20140000012    →  Cédula escolar · la asigna el MPPE
//
// ## ⚠️ El micro-copy aparece AL ESCRIBIR, no antes
//
// Explicar la diferencia entre las dos cédulas ANTES de escribir obliga a
// entenderla para poder empezar. Diciéndolo después, quien tiene la partida
// delante escribe lo que ve y el sistema confirma qué entendió — que es la
// única pregunta que le importa: «¿lo estoy haciendo bien?».
//
// ⚠️ La misma regla que `User#identificador=`, y tiene que seguir siendo la
// misma: acá decide qué se MUESTRA, allá qué se GUARDA. Si se separan, la
// pantalla dice una cosa y la base guarda otra.
//
// ⚠️ Y se compara el LARGO, no una expresión armada con `new RegExp`: escribir
// la regla dentro de una plantilla obliga a escapar la barra dos veces, y con
// una de menos `\\d` deja de ser «un dígito» y pasa a ser «una barra seguida de
// d» — que no coincide con nada. Resultado: toda cédula se leía como escolar.
export default class extends Controller {
  static targets = ["campo", "aviso", "sigla"]
  static values = { digitos: Number }

  connect() { this.revisar() }

  revisar() {
    const crudo = this.campoTarget.value.replace(/[^A-Za-z0-9]/g, "").toUpperCase()

    if (crudo === "") return this.#decir("", false)

    const conSigla = /^[A-Z]/.test(crudo)
    const numero = conSigla ? crudo.slice(1) : crudo
    const esCedula = numero.length <= this.digitosValue && /^\d+$/.test(numero)

    this.#decir(esCedula ? "Cédula de identidad" : "Cédula escolar · la asigna el MPPE", esCedula)
  }

  // ⚠️ El selector de V/E aparece SOLO cuando es una cédula de identidad. Una
  // cédula escolar ya trae su nacionalidad adentro, así que ofrecerlo al lado
  // sería un segundo control para el mismo dato — y dos verdades que se pueden
  // contradecir.
  #decir(texto, esCedula) {
    this.avisoTarget.textContent = texto
    if (this.hasSiglaTarget) this.siglaTarget.hidden = !esCedula
  }
}
