# Cómo se llaman las cosas en pantalla (MOR-212).
#
# ## Por qué existe
#
# Daniel, de la jornada del 3 de septiembre: *«corrección de nomenclatura:
# Preescolar = Educación Inicial; Primaria = Educación Primaria; Bachillerato =
# Educación Media General; Técnico Medio = Educación Técnica Media; Materias =
# Áreas de aprendizaje»*.
#
# No es purismo. Un director llena planillas del MPPE con estas palabras, y un
# sistema que le dice «Materias» donde el ministerio dice «Áreas de
# aprendizaje» lo obliga a traducir en cada pantalla.
#
# Y hasta ahora el vocabulario estaba **escrito a mano en cada vista**: la
# corrección de una palabra era salir a buscarla por cuarenta archivos. Acá vive
# una vez.
#
# ## ⚠️ El MODELO no cambia, y esa es la decisión que lo hace barato
#
#     Subject          la clase          ← inglés, Rails deduce de acá
#     subjects         la tabla          ← inglés
#     /materias        la URL            ← español, y CORTA: se lee bien
#     «Áreas de aprendizaje»  la pantalla ← el término del MPPE
#
# Es `MOR-162` llevado un paso más allá: inglés donde Rails deduce, español
# donde alguien lee, y **el término oficial donde alguien decide**. La URL se
# queda en `/materias` porque `/areas-de-aprendizaje` no se lee mejor: son
# veintiún caracteres para lo mismo.
#
# ## ⚠️ Dos formas, y la corta no es un capricho
#
# Daniel: *«si necesitas reducirlo en algunos espacios muy particulares (como
# teléfonos) podemos poner: Inicial, Primaria y Media»*.
#
#     LARGA   donde se DECIDE          elegir niveles, el panel del director
#     CORTA   donde se CONFIRMA        la barra, el menú, las pestañas, un chip
#
# Un nombre largo en un chip de la barra se recorta a la mitad, y medio nombre
# no dice nada; un nombre corto en la pantalla donde el director elige qué
# dicta su colegio le pide adivinar. Son dos trabajos distintos.
class Vocabulario
  # Lo que en el modelo es `Subject`.
  #
  # ⚠️ La forma corta es «Área», sin más: en una pestaña o un encabezado de
  # tabla el contexto ya dice de qué se habla, y «Área de aprendizaje» ocupa
  # tres veces el lugar para agregar cero información.
  AREA          = "Área de aprendizaje".freeze
  AREAS         = "Áreas de aprendizaje".freeze
  AREA_CORTA    = "Área".freeze
  AREAS_CORTAS  = "Áreas".freeze

  # Con artículo, para las frases corridas: «¿Quitar al profesor de esta área?».
  LA_AREA       = "el área de aprendizaje".freeze
  LAS_AREAS     = "las áreas de aprendizaje".freeze

  class << self
    # El nombre de un nivel. `corto: true` donde el largo no cabe.
    #
    # ⚠️ Delega en `GradoOficial`, que es donde vive el catálogo: duplicar la
    # tabla acá sería un segundo lugar con la misma verdad, y el día que el
    # MPPE cambie una palabra se corregiría solo uno.
    def nivel(valor, corto: false) = GradoOficial.etiqueta(valor, corto: corto)

    # «3 áreas de aprendizaje» / «1 área de aprendizaje».
    #
    # ⚠️ El plural va ESCRITO, no deducido: `"área".pluralize` devuelve «área»
    # —el inflector de Rails es inglés— y el proyecto ya tiene un helper
    # (`ApplicationHelper#contar`) justamente por eso.
    def areas(cuantas, corto: false)
      singular = corto ? AREA_CORTA : AREA
      plural   = corto ? AREAS_CORTAS : AREAS

      "#{cuantas} #{cuantas == 1 ? singular.downcase : plural.downcase}"
    end
  end
end
