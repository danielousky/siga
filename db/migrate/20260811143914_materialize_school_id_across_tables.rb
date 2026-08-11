# Nueve tablas pertenecen a un colegio pero solo lo saben recorriendo asociaciones.
# Un activity_grade llegaba a su escuela por cuatro saltos.
#
# Es información derivable, y duplicarla es deliberado. Tres razones, y la tercera
# es la que lo vuelve no negociable:
#
#   1. Todo índice único se vuelve componible. No se puede poner school_id en un
#      índice si la columna no está en la tabla.
#   2. Cada scope pasa a ser un solo salto, en vez de un joins de tres o cuatro
#      niveles que además es fácil de olvidar.
#   3. Es el prerrequisito del RLS. Una política de PostgreSQL evalúa columnas DE
#      LA FILA; no puede recorrer asociaciones de ActiveRecord. Sin esta columna,
#      la segunda capa de defensa no se puede escribir.
#
# El orden importa: se migra en cascada de padres a hijos, porque activity_grades
# se backfillea desde evaluation_activities, y moment_grades / final_grade_books
# desde enrollments.
#
# Ver MOR-85.
class MaterializeSchoolIdAcrossTables < ActiveRecord::Migration[8.1]
  # tabla => [tabla_padre, columna_fk]. En orden de dependencia.
  CASCADA = [
    [:sections,              :grades,                :grade_id],
    [:grade_subjects,        :grades,                :grade_id],
    [:enrollments,           :students,              :student_id],
    [:teacher_sections,      :sections,              :section_id],
    [:evaluation_activities, :sections,              :section_id],
    [:activity_grades,       :evaluation_activities, :evaluation_activity_id],
    [:moment_grades,         :enrollments,           :enrollment_id],
    [:final_grade_books,     :enrollments,           :enrollment_id]
  ].freeze

  def up
    CASCADA.each do |tabla, padre, fk|
      add_reference tabla, :school, null: true, foreign_key: true
      backfill_from_parent(tabla, padre, fk)
      verify_no_orphans!(tabla, padre)
      change_column_null tabla, :school_id, false
    end

    # activity_logs es el caso raro y va aparte: el colegio se deduce del ROL del
    # usuario, que puede ser estudiante, profesor o administrador.
    add_reference :activity_logs, :school, null: true, foreign_key: true
    backfill_activity_logs
    report_activity_logs_without_school
    # Se queda NULLABLE a propósito: un usuario sin rol no tiene colegio, y las
    # acciones del sistema pueden no tener usuario con rol. Forzar NOT NULL acá
    # obligaría a inventar un colegio o a perder el registro de auditoría.
  end

  def down
    remove_reference :activity_logs, :school, foreign_key: true
    CASCADA.reverse_each { |tabla, _padre, _fk| remove_reference tabla, :school, foreign_key: true }
  end

  private

  # La clave primaria de students/teachers/admins es user_id, no id.
  def primary_key_for(tabla)
    %i[students teachers admins].include?(tabla) ? "user_id" : "id"
  end

  def backfill_from_parent(tabla, padre, fk)
    execute <<~SQL.squish
      UPDATE #{tabla} hijo
         SET school_id = padre.school_id
        FROM #{padre} padre
       WHERE padre.#{primary_key_for(padre)} = hijo.#{fk}
    SQL
  end

  def verify_no_orphans!(tabla, padre)
    pk = primary_key_for(tabla)
    huerfanos = select_all(
      "SELECT #{pk} FROM #{tabla} WHERE school_id IS NULL ORDER BY #{pk} LIMIT 10"
    ).to_a
    return if huerfanos.empty?

    total = select_value("SELECT COUNT(*) FROM #{tabla} WHERE school_id IS NULL")
    raise ActiveRecord::MigrationError, <<~MSG
      #{total} fila(s) de #{tabla} quedaron sin colegio tras backfillear desde #{padre}.

      Primeras: #{huerfanos.map { |h| h[pk] }.join(', ')}

      Significa que su fila padre en #{padre} tampoco tiene school_id, o que la
      FK apunta a algo que no existe. Revisalo antes de volver a correrla.
    MSG
  end

  # El usuario llega a su colegio por el rol que tenga. COALESCE recorre los tres
  # en orden; si no tiene ninguno, queda NULL y se reporta.
  def backfill_activity_logs
    execute <<~SQL.squish
      UPDATE activity_logs al
         SET school_id = COALESCE(st.school_id, te.school_id, ad.school_id)
        FROM users u
   LEFT JOIN students st ON st.user_id = u.id
   LEFT JOIN teachers te ON te.user_id = u.id
   LEFT JOIN admins   ad ON ad.user_id = u.id
       WHERE u.id = al.user_id
    SQL
  end

  def report_activity_logs_without_school
    sin_colegio = select_value("SELECT COUNT(*) FROM activity_logs WHERE school_id IS NULL").to_i
    return if sin_colegio.zero?

    say "#{sin_colegio} activity_log(s) quedaron sin colegio: su usuario no tiene " \
        "rol de estudiante, profesor ni administrador. La columna es nullable a " \
        "propósito para no perder el registro de auditoría.", true
  end
end
