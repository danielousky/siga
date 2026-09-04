# Declara cómo este modelo llega al NIVEL, y le pone el scope que filtra por el
# nivel de la sesión.
#
#     class Section < ApplicationRecord
#       llega_al_nivel_por :grade
#     end
#
#     Section.del_nivel_de_la_sesion   # → solo las de primaria, si eso se eligió
#
# ## Gemelo de `DelAnioEscolar`, y a propósito
#
# Son el mismo tipo de cosa —una preferencia de quien mira, no un límite de
# seguridad— así que se comportan igual y se leen igual. Si alguno de los dos
# se cambia, el otro casi seguro tiene que cambiar también.
#
#     el COLEGIO   límite de SEGURIDAD           →  default_scope, siempre
#     el AÑO       preferencia de quien mira     →  scope explícito
#     el NIVEL     preferencia de quien mira     →  scope explícito
#
# ## Por qué NO es un `default_scope`
#
# Rompería cosas que **tienen** que funcionar:
#
#   · el historial de un alumno **cruza niveles por definición** — el mismo niño
#     hace 6to Grado y al año siguiente 1er Año;
#   · la constancia de un egresado de bachillerato se pide desde una sesión que
#     puede estar parada en primaria;
#   · `School#niveles` —que es quien DECIDE qué niveles ofrecer— tendría que
#     consultar grados sin filtrar por el nivel que todavía no eligió. Eso es
#     una recursión.
#
# Y al revés: que un nivel «se cuele» en una consulta no es un incidente. Son
# datos del mismo colegio, de quien ya los puede ver.
#
# ## El nivel vive en `grades.level`
#
# Es la única columna. Todo lo demás llega por su grado, y son tres
# profundidades — las mismas tres que el año escolar:
#
#     llega_al_nivel_por                          grades            (columna propia)
#     llega_al_nivel_por :grade                   sections, grade_subjects
#     llega_al_nivel_por section: :grade          enrollments, teacher_sections
#     llega_al_nivel_por enrollment: {section: :grade}   notas, asistencias
#
# ⚠️ **Filtra por `IN`, no por `=`.** «Bachillerato» son DOS valores del enum:
# `secundaria` y `media_tecnica`. Con `=` elegir bachillerato escondería el 6to
# Año — la trampa que `Grade#media?` existe para evitar. Ver `Current#nivel`.
#
# ⚠️ Si no hay nivel elegido, el scope **no filtra nada**, no devuelve cero. Es
# lo contrario de `SchoolScoped`, y es correcto: ahí sí se quiere ver todo.
module DelNivel
  extend ActiveSupport::Concern

  class_methods do
    # `camino` es cómo esta tabla llega a `grades`; `nil` si el nivel es propio.
    def llega_al_nivel_por(camino = nil)
      scope :del_nivel_de_la_sesion, -> {
        next all unless Current.un_solo_nivel?
        next where(level: Current.niveles_del_enum) if camino.nil?

        # ⚠️ `where` sobre `grades` y no sobre el modelo: el camino puede tener
        # tres saltos y la columna siempre está al final.
        joins(camino).where(grades: { level: Current.niveles_del_enum })
      }
    end

    # La segunda forma: para un modelo que llega al nivel por un `has_many`.
    #
    #     llega_al_nivel_por_los Enrollment, :student_id       # Student
    #     llega_al_nivel_por_los TeacherSection, :teacher_id   # Teacher
    #
    # ## ⚠️ Por qué una subconsulta y no un `joins`
    #
    # Un alumno tiene MUCHAS inscripciones y un profesor MUCHAS secciones, así
    # que un `joins` los duplica: un profesor con cuatro secciones de primaria
    # aparecería cuatro veces en la lista y el conteo diría 4 donde hay 1.
    #
    # `.distinct` lo arreglaría y trae su propio problema: con `ORDER BY` sobre
    # una columna de la tabla unida —que es como se ordena por apellido—
    # PostgreSQL exige que esa columna esté en el SELECT, y ahí Pagy empieza a
    # contar mal. Una subconsulta no duplica, no necesita distinct y compone
    # con `includes`, con `order` y con la paginación sin pensar en nada.
    #
    # ## ⚠️ Y arrastra el AÑO ESCOLAR, aunque el nivel no lo pida
    #
    # «Alumnos de primaria» es una pregunta que solo tiene respuesta dentro de
    # un año: el mismo niño es de primaria en 2025-2026 y de bachillerato en
    # 2026-2027. Sin el año, quien pasó de 6to Grado a 1er Año cuenta en los dos
    # niveles a la vez — y la suma de los tres niveles daría más que el total
    # del colegio, que es la clase de número que hace desconfiar de todo lo
    # demás.
    #
    # Con «Todos los años» elegido el filtro de año no hace nada, y contar en
    # los dos niveles pasa a ser la respuesta correcta.
    def llega_al_nivel_por_los(modelo, columna)
      scope :del_nivel_de_la_sesion, -> {
        next all unless Current.un_solo_nivel?

        where(id: modelo.del_anio_de_la_sesion.del_nivel_de_la_sesion.select(columna))
      }
    end
  end
end
