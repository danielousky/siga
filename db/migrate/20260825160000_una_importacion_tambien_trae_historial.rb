# El tercer tipo de planilla: el historial de notas (MOR-126, tanda 3).
#
# El `CHECK` se rehace porque enumera los tipos que existen. Sin tocarlo, la base
# rechazaría cualquier importación de historial con un error de restricción —no
# de validación— que no le dice nada a nadie.
class UnaImportacionTambienTraeHistorial < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :importaciones, name: "importaciones_tipo_valido"
    add_check_constraint :importaciones, "tipo IN (0, 1, 2)", name: "importaciones_tipo_valido"
  end

  def down
    remove_check_constraint :importaciones, name: "importaciones_tipo_valido"
    add_check_constraint :importaciones, "tipo IN (0, 1)", name: "importaciones_tipo_valido"
  end
end
