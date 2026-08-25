# Lo que la Certificación de Calificaciones exige y el modelo no tenía (MOR-99).
#
# La forma **31059** es el documento oficial de la Educación Media General, en
# vigencia desde el **17 de noviembre de 2017**, respaldada por la Resolución
# DM/0033 publicada en Gaceta Oficial **41.221** del 24 de agosto de 2017. La
# elabora la Dirección General de Registro y Control Académico del MPPE.
#
# Dos huecos, y el segundo ya estaba anticipado en el propio código.
#
# ## 1 · El plantel no sabe dónde queda
#
# La sección II del formato pide **entidad federal, municipio y dirección** del
# plantel, y `schools` solo tenía `name`, `dea_code`, `location` y `school_type`.
# `addresses` existe pero cuelga del USUARIO: es dónde vive una persona, no dónde
# funciona un colegio.
#
# ## 2 · ⚠️ Dos áreas se califican con LETRA, en bachillerato
#
# Desde el plan 31059, **Orientación y Convivencia** y **Participación en Grupos
# de Creación, Recreación y Producción** llevan calificación literal, mientras el
# resto de las áreas de formación va del 1 al 20. (En el mismo cambio se eliminó
# Educación para el Trabajo.)
#
# Esto NO se puede representar con `grades.escala`, y el comentario de `Grade` ya
# lo había previsto con estas palabras: *«poner un grado de bachillerato en
# literal pondría en literal a Matemática, que es indefendible. Si esas áreas del
# EMG hacen falta algún día, la escala tendría que vivir por MATERIA.»*
#
# Hacen falta. Va en `subjects.escala`, NULL por defecto: una materia sin escala
# propia usa la de su grado, que sigue siendo la regla general.
class LoQueExigeLaCertificacionDelMppe < ActiveRecord::Migration[8.1]
  def change
    change_table :schools, bulk: true do |t|
      t.string :entidad_federal
      t.string :municipio
      t.string :direccion
    end

    # NULL = «la que diga el grado». No se le pone default a propósito: un
    # default convertiría a TODAS las materias en excepciones declaradas, y la
    # excepción son dos.
    add_column :subjects, :escala, :integer, null: true
  end
end
