# Los grados no sabían de qué colegio eran, y `grades.name` era único global:
# si un colegio creaba "1er Año", ningún otro podía volver a usar ese nombre.
#
# La prueba de que el problema era real está en los propios datos: los grados se
# llamaban "1er Año - Bolívar" y "1er Año - Bello". Nadie nombra así un grado —
# ese sufijo existía solo para esquivar el índice único.
#
# Ver MOR-82.
class AddSchoolToGrades < ActiveRecord::Migration[8.1]
  def up
    add_reference :grades, :school, null: true, foreign_key: true

    backfill_school_from_sections
    backfill_school_from_name_suffix
    verify_every_grade_has_a_school!

    # El índice viejo se suelta ANTES de limpiar los nombres: al quitarle el
    # sufijo a "1er Año - Bolívar" y "1er Año - Bello" los dos pasan a llamarse
    # "1er Año", y con el índice único global todavía puesto eso explota.
    remove_index :grades, name: "index_grades_on_name"

    strip_school_suffix_from_names

    change_column_null :grades, :school_id, false
    add_index :grades, [:school_id, :name], unique: true
  end

  def down
    # Antes de devolver el índice único global hay que garantizar que los nombres
    # vuelvan a ser únicos entre colegios, o el índice no se puede crear.
    #
    # Ojo: esto NO es byte-idéntico al original. Reconstruye el sufijo con el
    # nombre completo del colegio ("1er Año - U.E. Simón Bolívar"), no con el
    # apodo que traían los seeds ("1er Año - Bolívar"). Restaura el invariante,
    # no el texto exacto.
    execute <<~SQL.squish
      UPDATE grades g
         SET name = g.name || ' - ' || s.name
        FROM schools s
       WHERE s.id = g.school_id
         AND EXISTS (
               SELECT 1 FROM grades o
                WHERE o.name = g.name AND o.id <> g.id
             )
    SQL

    remove_index :grades, column: [:school_id, :name]
    add_index :grades, :name, unique: true
    remove_reference :grades, :school, foreign_key: true
  end

  private

  # La señal buena: la cadena real grade → sections → academic_period → school.
  # Solo se aplica cuando un grado resuelve a UN colegio; si sus secciones
  # apuntan a colegios distintos, se deja nulo a propósito para que lo levante
  # la verificación y alguien lo mire, en vez de elegir uno al azar.
  def backfill_school_from_sections
    execute <<~SQL.squish
      UPDATE grades g
         SET school_id = origen.school_id
        FROM (
               SELECT s.grade_id, MIN(ap.school_id) AS school_id
                 FROM sections s
                 JOIN academic_periods ap ON ap.id = s.academic_period_id
             GROUP BY s.grade_id
               HAVING COUNT(DISTINCT ap.school_id) = 1
             ) origen
       WHERE g.id = origen.grade_id
         AND g.school_id IS NULL
    SQL
  end

  # La señal de respaldo, para grados que todavía no tienen ninguna sección:
  # el sufijo del nombre contra el nombre del colegio. Menos confiable, así que
  # va segunda y solo cubre lo que la cadena no alcanzó.
  def backfill_school_from_name_suffix
    execute <<~SQL.squish
      UPDATE grades g
         SET school_id = s.id
        FROM schools s
       WHERE g.school_id IS NULL
         AND g.name LIKE '% - %'
         AND s.name ILIKE '%' || split_part(g.name, ' - ', 2) || '%'
    SQL
  end

  def verify_every_grade_has_a_school!
    huerfanos = select_all(
      "SELECT id, name FROM grades WHERE school_id IS NULL ORDER BY id"
    ).to_a
    return if huerfanos.empty?

    detalle = huerfanos.map { |g| "  ##{g['id']} #{g['name']}" }.join("\n")
    raise ActiveRecord::IrreversibleMigration, <<~MSG
      No se pudo determinar el colegio de #{huerfanos.size} grado(s):

      #{detalle}

      Ninguna de las dos señales alcanzó: no tienen secciones que resuelvan a un
      único colegio, y su nombre no trae un sufijo que coincida con ninguno.
      Asignales school_id a mano y volvé a correr la migración.
    MSG
  end

  # Una vez que el grado sabe a qué colegio pertenece, el sufijo deja de tener
  # razón de ser. Arrastrarlo sería quedarse con la cicatriz después de curar
  # la herida — y además dejaría "1er Año - Bolívar" en pantalla para siempre.
  def strip_school_suffix_from_names
    execute <<~SQL.squish
      UPDATE grades g
         SET name = btrim(split_part(g.name, ' - ', 1))
        FROM schools s
       WHERE s.id = g.school_id
         AND g.name LIKE '% - %'
         AND s.name ILIKE '%' || split_part(g.name, ' - ', 2) || '%'
    SQL
  end
end
