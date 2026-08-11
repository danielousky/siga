# Los momentos de evaluación eran filas compartidas por toda la plataforma, y la
# validación de que los pesos sumen 100 % sumaba sobre TODA la tabla. Consecuencia:
# si el primer colegio definía sus tres lapsos ocupando el 100 %, ningún otro podía
# crear un momento de evaluación jamás.
#
# No era una fuga de lectura: era una denegación de servicio entre inquilinos. El
# segundo cliente que entrara al sistema descubría que el producto no funciona.
#
# Cuelgan del PERÍODO y no de la escuela a propósito. El período ya pertenece a una
# escuela, así que el aislamiento se obtiene igual — pero además la estructura de
# evaluación de cada año escolar queda congelada junto con sus notas. Cambiar los
# lapsos en 2027 no altera lo ya calculado en 2026, y en un expediente académico
# eso no es opcional.
#
# Ver MOR-83.
class MoveEvaluationMomentsToAcademicPeriod < ActiveRecord::Migration[8.1]
  def up
    add_reference :evaluation_moments, :academic_period, null: true, foreign_key: true

    guard_against_losing_moments!
    clone_moments_into_every_period
    repoint_moment_grades_to_their_clone
    repoint_evaluation_activities_to_their_clone
    verify_nothing_points_at_a_shared_moment!
    delete_the_shared_originals

    change_column_null :evaluation_moments, :academic_period_id, false
    add_index :evaluation_moments, [:academic_period_id, :name], unique: true
  end

  def down
    remove_index :evaluation_moments, column: [:academic_period_id, :name]

    # Colapsa de vuelta a un juego único de momentos, quedándose con el de menor id
    # por cada nombre y repuntando los dependientes hacia él.
    #
    # Ojo: esto SÍ pierde información. Si dos períodos tenían un "Primer Lapso" con
    # pesos distintos, sobrevive uno solo y el otro peso se pierde. Es la naturaleza
    # de volver a un modelo que no puede expresar la diferencia.
    execute <<~SQL.squish
      UPDATE moment_grades mg
         SET evaluation_moment_id = superviviente.id
        FROM evaluation_moments actual
        JOIN (
               SELECT name, MIN(id) AS id FROM evaluation_moments GROUP BY name
             ) superviviente ON superviviente.name = actual.name
       WHERE actual.id = mg.evaluation_moment_id
         AND actual.id <> superviviente.id
    SQL

    execute <<~SQL.squish
      UPDATE evaluation_activities ea
         SET evaluation_moment_id = superviviente.id
        FROM evaluation_moments actual
        JOIN (
               SELECT name, MIN(id) AS id FROM evaluation_moments GROUP BY name
             ) superviviente ON superviviente.name = actual.name
       WHERE actual.id = ea.evaluation_moment_id
         AND actual.id <> superviviente.id
    SQL

    execute <<~SQL.squish
      DELETE FROM evaluation_moments
       WHERE id NOT IN (SELECT MIN(id) FROM evaluation_moments GROUP BY name)
    SQL

    remove_reference :evaluation_moments, :academic_period, foreign_key: true
  end

  private

  # Sin períodos no hay a dónde clonar, y el paso de borrado se llevaría los
  # momentos por delante. Mejor abortar que vaciar la tabla en silencio.
  def guard_against_losing_moments!
    momentos = select_value("SELECT COUNT(*) FROM evaluation_moments WHERE academic_period_id IS NULL").to_i
    periodos = select_value("SELECT COUNT(*) FROM academic_periods").to_i
    return if momentos.zero? || periodos.positive?

    raise ActiveRecord::MigrationError, <<~MSG
      Hay #{momentos} momento(s) de evaluación compartidos y ningún período académico
      al cual colgarlos. Clonarlos por período dejaría la tabla vacía.

      Creá al menos un período académico antes de correr esta migración.
    MSG
  end

  # Cada período se queda con su propio juego completo de momentos. Se clona, no se
  # reasigna: si se reasignara, un solo período se quedaría con los originales y el
  # resto arrancaría sin ninguno.
  def clone_moments_into_every_period
    execute <<~SQL.squish
      INSERT INTO evaluation_moments (name, weight, academic_period_id, created_at, updated_at)
           SELECT compartido.name, compartido.weight, p.id, now(), now()
             FROM evaluation_moments compartido
       CROSS JOIN academic_periods p
            WHERE compartido.academic_period_id IS NULL
    SQL
  end

  # El paso delicado: una nota tiene que quedar apuntando al momento de SU período.
  # El período de la nota sale de enrollment → section → academic_period, y el clon
  # correcto es el que comparte nombre con el momento original.
  def repoint_moment_grades_to_their_clone
    # El destino se resuelve en una subconsulta en vez de encadenar JOINs contra
    # moment_grades: en un UPDATE ... FROM de PostgreSQL la tabla que se actualiza
    # no es visible dentro de los JOIN del FROM, solo en el WHERE.
    execute <<~SQL.squish
      UPDATE moment_grades mg
         SET evaluation_moment_id = destino.clon_id
        FROM (
               SELECT origen.id AS nota_id, clon.id AS clon_id
                 FROM moment_grades origen
                 JOIN enrollments e ON e.id = origen.enrollment_id
                 JOIN sections s ON s.id = e.section_id
                 JOIN evaluation_moments compartido ON compartido.id = origen.evaluation_moment_id
                 JOIN evaluation_moments clon ON clon.academic_period_id = s.academic_period_id
                                             AND clon.name = compartido.name
                WHERE compartido.academic_period_id IS NULL
             ) destino
       WHERE mg.id = destino.nota_id
    SQL
  end

  # Mismo repunte para las actividades, que llegan a su período por la sección.
  def repoint_evaluation_activities_to_their_clone
    execute <<~SQL.squish
      UPDATE evaluation_activities ea
         SET evaluation_moment_id = destino.clon_id
        FROM (
               SELECT origen.id AS actividad_id, clon.id AS clon_id
                 FROM evaluation_activities origen
                 JOIN sections s ON s.id = origen.section_id
                 JOIN evaluation_moments compartido ON compartido.id = origen.evaluation_moment_id
                 JOIN evaluation_moments clon ON clon.academic_period_id = s.academic_period_id
                                             AND clon.name = compartido.name
                WHERE compartido.academic_period_id IS NULL
             ) destino
       WHERE ea.id = destino.actividad_id
    SQL
  end

  # Antes de borrar los originales hay que estar seguros de que nadie los apunta.
  # Si quedó alguno, borrar dejaría filas huérfanas o rompería la FK — mejor parar
  # acá con el detalle que descubrirlo después.
  def verify_nothing_points_at_a_shared_moment!
    notas = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM moment_grades mg
        JOIN evaluation_moments m ON m.id = mg.evaluation_moment_id
       WHERE m.academic_period_id IS NULL
    SQL

    actividades = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM evaluation_activities ea
        JOIN evaluation_moments m ON m.id = ea.evaluation_moment_id
       WHERE m.academic_period_id IS NULL
    SQL

    return if notas.zero? && actividades.zero?

    raise ActiveRecord::MigrationError, <<~MSG
      Después de repuntar quedaron dependientes apuntando a momentos compartidos:
        moment_grades:          #{notas}
        evaluation_activities:  #{actividades}

      Suele significar que su sección no tiene período académico, o que el clon con
      ese nombre no existe. Revisalos antes de volver a correr la migración.
    MSG
  end

  def delete_the_shared_originals
    execute "DELETE FROM evaluation_moments WHERE academic_period_id IS NULL"
  end
end
