import { Controller } from "@hotwired/stimulus"

// Un teléfono venezolano, con su guion puesto solo (MOR-179).
//
//     0414-1234567      móvil
//     0212-5551234      fijo
//
// Los dos tienen la misma forma: cuatro dígitos de código y siete de número.
// Daniel: «el teléfono también debería ser solo con el formato de teléfono
// 04XX-0001122».
//
// ## Por qué un controlador propio y no `campo-filtrado`
//
// Aquel QUITA lo que no corresponde; este además PONE algo que no se escribió —
// el guion— y eso cambia dónde queda el cursor de una manera distinta. Meterlo
// en el otro habría sido una bandera más y dos comportamientos en el mismo
// método.
//
// ⚠️ No valida que el número exista ni que el operador sea real: eso no se puede
// saber, y un formulario que rechaza un teléfono correcto es peor que uno que
// acepta uno inventado. Lo que evita es el error de tipeo — una letra, un
// espacio, un paréntesis— que después rompe el enlace de «llamar» en el teléfono
// de la secretaria.
export default class extends Controller {
  static values = { largo: { type: Number, default: 11 } }

  formatear() {
    const campo = this.element
    const antes = campo.value
    const digitos = antes.replace(/\D/g, "").slice(0, this.largoValue)

    const despues = digitos.length > 4
      ? `${digitos.slice(0, 4)}-${digitos.slice(4)}`
      : digitos

    if (despues === antes) return

    // ⚠️ El cursor, contado en DÍGITOS y no en caracteres.
    //
    // El guion se pone y se quita solo, así que la posición en el texto cambia
    // sin que nadie haya escrito nada ahí. Contando cuántos dígitos había antes
    // del cursor y volviendo a buscar esa misma cantidad, el punto de edición se
    // mantiene aunque el guion se corra.
    const digitosAntesDelCursor = antes
      .slice(0, campo.selectionStart ?? antes.length)
      .replace(/\D/g, "").length

    campo.value = despues

    let posicion = 0
    let contados = 0
    while (posicion < despues.length && contados < digitosAntesDelCursor) {
      if (/\d/.test(despues[posicion])) contados++
      posicion++
    }
    campo.setSelectionRange(posicion, posicion)
  }
}
