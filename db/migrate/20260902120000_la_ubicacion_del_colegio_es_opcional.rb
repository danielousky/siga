# La ubicación de un colegio deja de ser obligatoria (MOR-208).
#
# El registro pide lo MÍNIMO —nombre, código DEA y qué dicta— y la ubicación se
# completa después, en la identidad del colegio. Daniel: *«nada de cédula, logo
# o sello, ni nada de eso… Luego él puede entrar a los detalles y cambiar alguna
# cosa que considere»*.
#
# ⚠️ La validación del modelo no alcanza: la columna tenía `NOT NULL`, así que
# aflojar el modelo dejaba el alta reventando con un `PG::NotNullViolation` —un
# 500 en vez de un formulario con su error—. Las dos capas tienen que decir lo
# mismo.
#
# ⚠️ Y NO se toca `entidad_federal`, `municipio` ni `parroquia`: esos salen
# impresos en los documentos del ministerio y su exigencia vive donde
# corresponde, en la pantalla que los pide.
class LaUbicacionDelColegioEsOpcional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :schools, :location, true
  end
end
