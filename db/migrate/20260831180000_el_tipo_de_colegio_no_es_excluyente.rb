# `school_type` era excluyente, y un colegio no lo es (MOR-160).
#
# ## Por qué se borra en vez de conservarse
#
# La columna decía «o primaria o bachillerato». Un colegio venezolano corriente
# dicta preescolar Y primaria Y bachillerato, así que para la mitad del mercado
# la respuesta era falsa: Andrés Bello, con nueve grados de preescolar y
# primaria, decía «Primaria» a secas.
#
# La respuesta buena ya existe y no es una columna: `School#niveles` se DERIVA
# de los grados cargados. Es no excluyente por construcción, incluye Media
# Técnica, y no se puede desincronizar porque no es un segundo lugar donde vive
# la misma verdad — es la verdad.
#
# Conservarla «por si acaso» obligaba a un sincronizador —lo hubo, durante un
# día— y eso es exactamente el vicio que este proyecto evita en todas partes.
#
# ## Y no la usaba nadie
#
# Se verificó uno por uno: **ningún documento del MPPE la lee.** La certificación
# 31059, el certificado de primaria y la constancia de prosecución leen
# `Grade#level` y `Grade#media?`, que es el dato del alumno, no el del plantel.
# Tampoco la lee ninguna pantalla del colegio: solo el panel de SIGA, que ahora
# muestra los niveles reales.
#
# ## El dato no se pierde
#
# Es derivable: un colegio con un grado de bachillerato era `secondary`. Si algún
# día hiciera falta el valor viejo, sale de `grades`.
class ElTipoDeColegioNoEsExcluyente < ActiveRecord::Migration[8.1]
  def up
    remove_column :schools, :school_type
  end

  # ⚠️ La vuelta atrás recalcula desde los grados, no inventa: un colegio con
  # bachillerato es `secondary`, el resto `primary`. Es lo mismo que hacía el
  # sincronizador que esta migración elimina.
  def down
    add_column :schools, :school_type, :integer
    execute <<~SQL
      UPDATE schools SET school_type = CASE
        WHEN EXISTS (SELECT 1 FROM grades WHERE grades.school_id = schools.id AND grades.level IN (1, 3))
        THEN 1 ELSE 0 END
    SQL
    change_column_null :schools, :school_type, false
  end
end
