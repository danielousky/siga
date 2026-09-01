# Declara cómo este modelo llega al AÑO ESCOLAR, y le pone el scope que filtra
# por el año de la sesión (MOR-165).
#
#     class Enrollment < ApplicationRecord
#       llega_al_anio_por :section
#     end
#
#     Enrollment.del_anio_de_la_sesion   # → solo las del año elegido arriba
#
# ## Por qué NO es un `default_scope`, y `SchoolScoped` sí
#
# Son dos cosas que se parecen y no lo son:
#
#     el COLEGIO   es un límite de seguridad   →  se aplica solo, siempre
#     el AÑO       es una preferencia de quien mira →  se aplica cuando se pide
#
# Que el colegio se cuele en una consulta es un incidente. Que un año se cuele
# no es nada: son datos del mismo colegio, de quien ya los puede ver.
#
# Y al revés, un `default_scope` por año **rompería cosas que tienen que
# funcionar**: el historial de un alumno cruza años por definición, la constancia
# de un egresado es de un año que ya cerró, y `AcademicPeriod.en_operacion` —que
# es quien DECIDE el año— tendría que consultar secciones sin filtrar por el año
# que todavía no eligió. Un default_scope ahí es una recursión.
#
# Por eso el scope es explícito y se lee en el controller: quien lista pide el
# recorte, quien busca un histórico no lo pide.
#
# ## El año vive en `sections`
#
# Solo tres tablas tienen `academic_period_id` propio: `sections`,
# `evaluation_moments` e `importaciones`. Todo lo demás —inscripciones,
# asistencias, notas, boletines— llega por su sección, que es donde el modelo
# educativo venezolano lo pone: un alumno se inscribe en una SECCIÓN de un año.
#
# ⚠️ Si no hay año elegido —«Todos los años»— el scope **no filtra nada**, no
# devuelve cero. Es lo contrario de `SchoolScoped`, y es correcto: ahí sí se
# quiere ver todo.
module DelAnioEscolar
  extend ActiveSupport::Concern

  class_methods do
    # `camino` es cómo esta tabla llega a `sections`; `nil` si el año es propio.
    #
    #     llega_al_anio_por                      # sections, evaluation_moments
    #     llega_al_anio_por :section             # enrollments, teacher_sections
    #     llega_al_anio_por enrollment: :section # attendances, moment_grades
    def llega_al_anio_por(camino = nil)
      scope :del_anio_de_la_sesion, -> {
        next all unless Current.un_solo_anio?
        next where(academic_period_id: Current.academic_period_id) if camino.nil?

        # ⚠️ `where` sobre `sections` y no sobre el modelo: el join puede tener
        # dos saltos y la columna siempre está al final del camino.
        joins(camino).where(sections: { academic_period_id: Current.academic_period_id })
      }
    end
  end
end
