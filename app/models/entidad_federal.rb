# Las entidades federales de Venezuela (MOR-157).
#
# ## Por qué una lista cerrada y no un campo de texto
#
# La entidad federal sale impresa en los documentos del MPPE, y ahí «Miranda»,
# «Edo. Miranda», «MIRANDA» y «Edo Miranda» son cuatro cosas distintas para
# cualquier cosa que después quiera agrupar, contar o emparejar. Son
# veinticinco, no cambian, y las fija la Constitución: escribirlas a mano es
# regalar el problema.
#
# ## Municipio y parroquia siguen siendo texto, a propósito
#
# Son 335 y ~1.150. El catálogo completo es un archivo de datos que hay que
# conseguir, mantener y versionar, y hoy no paga: con la entidad cerrada ya se
# puede agrupar por estado, que es la pregunta que un vendedor se hace. El día
# que haga falta, el lugar donde ponerlo ya está.
#
# ⚠️ **Vargas se llama La Guaira desde 2019.** Escribir «Vargas» en un documento
# oficial lo deja desactualizado.
class EntidadFederal
  TODAS = [
    "Amazonas", "Anzoátegui", "Apure", "Aragua", "Barinas", "Bolívar",
    "Carabobo", "Cojedes", "Delta Amacuro", "Distrito Capital",
    "Falcón", "Guárico", "La Guaira", "Lara", "Mérida", "Miranda",
    "Monagas", "Nueva Esparta", "Portuguesa", "Sucre", "Táchira",
    "Trujillo", "Yaracuy", "Zulia", "Dependencias Federales"
  ].freeze

  # Tolera cómo lo escribió una persona o una planilla importada: «EDO. MIRANDA»
  # y «miranda» son la misma entidad.
  def self.normalizar(texto)
    buscado = I18n.transliterate(texto.to_s).downcase.gsub(/\b(edo|estado)\b\.?/, "").gsub(/[^a-z]/, "")
    return nil if buscado.blank?

    TODAS.find { |e| I18n.transliterate(e).downcase.gsub(/[^a-z]/, "") == buscado }
  end

  def self.valida?(texto) = TODAS.include?(texto)
end
