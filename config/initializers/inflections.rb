# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end

# ═══════════════════════════════════════════════════════════════════════════
# Palabras del dominio que el inflector INGLÉS rompe
# ═══════════════════════════════════════════════════════════════════════════
#
# Rails singulariza y pluraliza con reglas del inglés, y la app está en español.
# A veces coincide por casualidad —"grado" → "grados"— y a veces no:
#
#     "solicitudes".singularize  # => "solicitude"   ✗
#     "boletín".pluralize        # => "boletíns"     ✗
#
# Lo peligroso es que funcione en las palabras terminadas en vocal: se confía sin
# pensar, y el día que la palabra termina en consonante sale un `siga_solicitude_path`
# que nadie escribiría a mano. Apareció justamente así, en MOR-133.
#
# Para el TEXTO de las vistas está `pluralizar` en ApplicationHelper, con las dos
# formas escritas a mano. Esto es para lo que Rails deriva solo: nombres de ruta,
# de tabla y de clase.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "solicitud", "solicitudes"
  inflect.irregular "constancia", "constancias"
  inflect.irregular "importacion", "importaciones"
end
