# Declara que el colegio de este modelo se deduce de otro, y lo mantiene
# sincronizado solo.
#
#     class Section < ApplicationRecord
#       derives_school_from :grade
#     end
#
# `school_id` está materializado en la tabla aunque sea derivable, porque es el
# prerrequisito del RLS: una política de PostgreSQL evalúa columnas de la fila y
# no puede recorrer asociaciones. Ver MOR-85.
#
# El precio de materializarlo es que puede quedar desincronizado del padre. Este
# concern paga ese precio en un solo lugar: si alguien reasigna una inscripción a
# un alumno de otro colegio, el `school_id` lo sigue — en vez de confiar en que
# quien escriba el código se acuerde.
module DerivesSchoolFrom
  extend ActiveSupport::Concern

  class_methods do
    def derives_school_from(association)
      belongs_to :school

      before_validation do
        padre = public_send(association)
        self.school_id = padre.school_id if padre.respond_to?(:school_id) && padre.school_id
      end
    end
  end
end
