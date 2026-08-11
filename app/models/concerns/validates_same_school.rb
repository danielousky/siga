# Declara que estas asociaciones tienen que pertenecer al MISMO colegio que el
# registro, e impide guardarlo si no.
#
#     class Enrollment < ApplicationRecord
#       derives_school_from :student
#       validates_same_school :section      # el alumno y la sección, mismo colegio
#     end
#
# Es el aislamiento de ESCRITURA, y es distinto del de lectura.
#
# Los scopes y el RLS evitan VER lo ajeno. Pero si un `id` llega por un formulario
# y el modelo no lo verifica, se crea una fila que cruza dos colegios y queda ahí.
# Una fila así es peor que una fuga de lectura: la fuga se corta arreglando el
# filtro, pero el dato cruzado YA ESTÁ ESCRITO y hay que salir a buscarlo.
#
# Ver MOR-89.
module ValidatesSameSchool
  extend ActiveSupport::Concern

  class_methods do
    def validates_same_school(*associations)
      validate do
        next if school_id.blank?

        associations.each do |name|
          relacionado = public_send(name)
          next if relacionado.blank?
          next unless relacionado.respond_to?(:school_id)
          next if relacionado.school_id.blank? || relacionado.school_id == school_id

          errors.add(name, :different_school)
        end
      end
    end
  end
end
