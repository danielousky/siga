# La parroquia del plantel (MOR-99).
#
# El **Certificado de Educación Primaria** y la **Constancia de Prosecución** la
# piden explícitamente: *«ubicado en el municipio ______ de la parroquia ______
# adscrito a la Zona Educativa del estado ______»*.
#
# `addresses` ya tiene `parroquia`, pero cuelga del USUARIO: es dónde vive una
# persona, no dónde funciona un colegio. Es la misma razón por la que `direccion`,
# `municipio` y `entidad_federal` terminaron en `schools`.
class LosDocumentosDePrimariaPidenParroquia < ActiveRecord::Migration[8.1]
  def change
    add_column :schools, :parroquia, :string
  end
end
