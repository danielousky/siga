import { Controller } from "@hotwired/stimulus"

// Estado → municipio → parroquia, en cascada (MOR-159).
//
// «Tipear solo cuando no quede otra opción» — Daniel. Elegir de una lista es
// más rápido que escribir, y sobre todo produce el MISMO texto siempre: estos
// tres campos salen IMPRESOS en los documentos del MPPE, y ahí «Libertador»,
// «Mcpio. Libertador» y «LIBERTADOR» son tres lugares distintos para cualquier
// cosa que después quiera agrupar.
//
// ## ⚠️ Siempre hay salida a mano
//
// El catálogo está incompleto y se escribió sin fuente oficial. Cada
// desplegable termina en «No está en la lista», que descubre un campo de texto.
// Un catálogo equivocado NO puede impedirle a un colegio registrarse — un
// colegio que no puede registrarse no vuelve.
//
// ## Y por qué el catálogo viaja en la página
//
// Son ~20 KB, menos que un icono. Una petición por cada cambio de estado sería
// una espera en medio de un formulario, y con una conexión mala —que en
// Venezuela es lo normal— convierte un desplegable en una pantalla trabada.
export default class extends Controller {
  static targets = ["entidad", "municipio", "parroquia", "municipioLibre", "parroquiaLibre"]
  static values = { catalogo: Object, otro: String }

  connect() {
    // Se dibuja el estado inicial sin borrar lo que ya venía: un formulario que
    // vuelve con errores de validación tiene que conservar lo que la persona
    // eligió, o lo hace escribir todo de nuevo.
    this.pintarMunicipios(this.municipioTarget.dataset.actual)
    this.pintarParroquias(this.parroquiaTarget.dataset.actual)
  }

  alCambiarEntidad() {
    this.pintarMunicipios(null)
    this.pintarParroquias(null)
  }

  alCambiarMunicipio() {
    this.pintarParroquias(null)
    this.alternarLibre(this.municipioTarget, this.municipioLibreTarget)
  }

  alCambiarParroquia() {
    this.alternarLibre(this.parroquiaTarget, this.parroquiaLibreTarget)
  }

  // ── dibujar ─────────────────────────────────────────────────────────────

  pintarMunicipios(elegido) {
    const municipios = Object.keys(this.catalogoValue[this.entidadTarget.value] || {})

    this.llenar(this.municipioTarget, municipios, elegido, "Seleccione el municipio…")
    this.alternarLibre(this.municipioTarget, this.municipioLibreTarget)
  }

  pintarParroquias(elegido) {
    const delEstado = this.catalogoValue[this.entidadTarget.value] || {}
    const parroquias = delEstado[this.municipioTarget.value] || []

    this.llenar(this.parroquiaTarget, parroquias, elegido, "Seleccione la parroquia…")
    this.alternarLibre(this.parroquiaTarget, this.parroquiaLibreTarget)
  }

  llenar(select, opciones, elegido, vacio) {
    select.innerHTML = ""
    select.appendChild(new Option(vacio, ""))

    opciones.forEach((o) => select.appendChild(new Option(o, o)))
    select.appendChild(new Option("No está en la lista…", this.otroValue))

    // Si lo que venía guardado no está en el catálogo, el desplegable queda en
    // «No está en la lista» y el texto libre lo muestra. Así un colegio cargado
    // antes de esto no pierde su dato al abrir el formulario.
    if (!elegido) return

    const conocido = opciones.includes(elegido)
    select.value = conocido ? elegido : this.otroValue
  }

  // El campo de texto solo existe cuando hace falta. Y se limpia al ocultarlo:
  // un valor invisible que igual se manda es la clase de dato que después nadie
  // entiende de dónde salió.
  alternarLibre(select, libre) {
    const hace_falta = select.value === this.otroValue

    libre.hidden = !hace_falta
    libre.querySelector("input").disabled = !hace_falta
    if (!hace_falta) libre.querySelector("input").value = ""
  }
}
