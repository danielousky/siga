# La primera capa del aislamiento: todo lo que se consulte de este modelo queda
# filtrado por el colegio de la petición en curso.
#
#     class Student < ApplicationRecord
#       include SchoolScoped
#     end
#
#     Student.all   # → solo los del colegio de Current
#
# La idea es que alguien escriba `Student.all` en un controller nuevo y obtenga,
# sin pensarlo, solo los alumnos de su colegio. Es una convención de la
# aplicación — y las convenciones se rompen. Por eso debajo está el RLS de
# MOR-87, que hace que un filtro olvidado devuelva CERO filas en vez de las del
# vecino.
#
# ## Qué pasa sin contexto de colegio
#
# `Current.school` es nil fuera de una petición: consola, rake, jobs, seeds.
# Ahí el scope **no filtra nada**, y eso es deliberado: hacerlo fallar dejaría
# la consola y las migraciones inutilizables.
#
# Lo que impide que eso sea una fuga es que el RLS de Postgres sigue aplicando:
# sin la variable de sesión, la política devuelve cero filas. O sea que en un
# contexto sin inquilino no se ve de más — se ve de menos, que es el modo
# correcto de fallar.
#
# Para los casos donde ver todos los colegios ES legítimo (seeds, migraciones),
# está `Current.sin_aislamiento`, que apaga las dos capas de forma explícita.
#
# Ver MOR-86 y MOR-87.
module SchoolScoped
  extend ActiveSupport::Concern

  # No declara `belongs_to :school`: cada modelo ya lo trae, sea propio o puesto
  # por `DerivesSchoolFrom`. Declararlo de nuevo acá lo pisaría — y en el caso de
  # `ActivityLog`, que lo tiene `optional: true` a propósito, lo rompería.
  included do
    default_scope do
      if Current.tenant_scope_disabled || Current.school_id.nil?
        all
      else
        where(school_id: Current.school_id)
      end
    end
  end

  class_methods do
    # Para los cruces legítimos entre colegios: redes de colegios, paneles
    # internos, reportes consolidados.
    #
    # Se prefiere esto antes que `unscoped` porque sigue siendo un filtro —
    # solo que más ancho. `unscoped` apaga TODO, incluidos scopes que no tienen
    # nada que ver con el inquilino.
    def de_los_colegios(*school_ids)
      unscope(where: :school_id).where(school_id: school_ids.flatten)
    end
  end
end
