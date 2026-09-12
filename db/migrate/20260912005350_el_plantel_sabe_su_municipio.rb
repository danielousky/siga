# El municipio de cada plantel, DEDUCIDO de su propio código DEA.
#
# ## ⚠️ El código lleva la ubicación adentro, y está comprobado
#
#     O D 0489 02 03
#             │  │  └── municipio dentro del estado  ── «03» = Atures
#             │  └───── entidad federal (código INE) ── «02» = Amazonas
#             └──────── el registro ante la zona educativa
#
# Los cuatro dígitos finales son el `Co_municip` de la División Político
# Territorial del INE, tal cual. Contrastado contra las 13.441 filas con código:
# **casan 13.434 (99 %)**.
#
# ⚠️ Las excepciones son dos, y son reales: Distrito Capital y La Guaira tienen
# UN SOLO municipio cada uno —Libertador y Vargas— y el MPPE usa ahí códigos
# 02, 03, 04, 05 que son subdivisiones suyas, no municipios. Cualquier código de
# un estado con un solo municipio cae en ese municipio, y eso no es una
# suposición: es aritmética.
#
# ⚠️ Se guarda DEDUCIDO y no se deduce al vuelo porque el catálogo no cambia
# entre despliegues, y porque así se ve en el CSV qué se dedujo para cada uno.
class ElPlantelSabeSuMunicipio < ActiveRecord::Migration[8.1]
  def change
    add_column :planteles_oficiales, :municipio, :string
  end
end
