// Comparar textos ignorando acentos, igual que el buscador del servidor.
//
// ## Por qué existe
//
// La regla ya estaba escrita —en Ruby, en `BusquedaSinAcentos`— pero solo del
// lado del servidor. Los filtros que corren en el NAVEGADOR comparaban con
// `toLowerCase().includes()` a secas, así que escribir «sofia» no encontraba a
// Sofía. Daniel lo vio buscando representados: «hay otro buscador que ya
// contemplaba ese tipo de coincidencias. Hay que unificarlo».
//
// No se puede compartir el código con Ruby —son dos motores— pero sí la REGLA, y
// esta es la mitad JavaScript de la misma decisión. Si una cambia, la otra
// también: están anotadas la una en la otra.
//
// ## ⚠️ La eñe también se aplana, y es una decisión
//
// `normalize("NFD")` descompone «ñ» en «n» + tilde, así que quitar los signos la
// convierte en «n» — lo mismo que hace el mapa de `BusquedaSinAcentos`.
//
// En español la eñe es una letra propia y no una ene con adorno: «año» y «ano»
// son dos palabras muy distintas. Pero esto es un BUSCADOR de personas, y quien
// escribe «nunez» está buscando a Núñez. El falso positivo es que aparezca un
// apellido de más en una lista; el falso negativo es no encontrar a nadie.
//
// ⚠️ Y esto normaliza la COMPARACIÓN, jamás el dato: el apellido de esa persona
// sigue siendo «Núñez», con eñe, y así sale en el boletín y en la certificación
// del MPPE.
export function sinAcentos(texto) {
  return (texto ?? "")
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
}

// ¿El texto contiene lo buscado, ignorando acentos y mayúsculas?
export function contieneSinAcentos(texto, buscado) {
  return sinAcentos(texto).includes(sinAcentos(buscado))
}
