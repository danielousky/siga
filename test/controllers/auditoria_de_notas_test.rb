require "test_helper"

# Quién le cambió la nota a mi hijo.
#
# Es la pregunta de auditoría que un colegio necesita poder responder, la hace
# una madre por UNA nota meses después, y hasta acá el sistema no la contestaba:
# `ActivityLog` tenía etiquetas para "Calificación registrada/modificada/
# eliminada" y **nadie las emitía**.
class AuditoriaDeNotasTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.profesor
    @actividad = @a.actividad
    # El alumno 2: el 1 ya trae una nota puesta por el escenario, y este test
    # necesita empezar desde "sin nota".
    @alumno    = @a.escenario.alumno(2)
  end

  def cambiar(score)
    patch evaluation_activity_nota_path(@actividad, @alumno.user_id),
          params: { score: score }, as: :json
  end

  def ultimo_log
    con_el_colegio(@a.escenario.colegio) { ActivityLog.order(:created_at).last }
  end

  test "poner una nota por primera vez queda registrado" do
    assert_difference "con_el_colegio(@a.escenario.colegio) { ActivityLog.count }", 1 do
      cambiar(15)
    end

    log = ultimo_log
    assert_equal "calificacion_registrada", log.action
    assert_match(/le puso 15/, log.message)
    assert_match(/#{@alumno.user.last_name}/, log.message)
  end

  # Lo que hace útil el registro: no solo QUE cambió, sino DE QUÉ a qué.
  test "corregir una nota deja constancia del valor anterior" do
    cambiar(12)
    cambiar(15)

    log = ultimo_log
    assert_equal "calificacion_modificada", log.action
    assert_match(/le cambió el 12 por 15/, log.message)
    assert_equal 12, log.metadata["anterior"]
    assert_equal 15, log.metadata["actual"]
  end

  # La planilla reenvía al salir del campo: un profesor que revisa sus notas sin
  # tocar nada generaría treinta "Calificación modificada", y un historial lleno
  # de cambios que no ocurrieron esconde los que sí.
  test "guardar el mismo valor no registra un cambio" do
    cambiar(13)

    assert_no_difference "con_el_colegio(@a.escenario.colegio) { ActivityLog.count }" do
      cambiar(13)
    end
  end

  # Vaciar el campo borra la nota —el alumno vuelve a "sin nota", que no es un
  # cero— y eso también tiene que quedar.
  test "borrar una nota queda registrado con el valor que tenía" do
    cambiar(18)
    cambiar("")

    log = ultimo_log
    assert_equal "calificacion_eliminada", log.action
    assert_match(/le borró la nota \(era 18\)/, log.message)
  end

  # Un fallo auditando nunca puede impedir que se guarde la nota: el profesor
  # está cargando treinta un domingo por la noche.
  test "la nota se guarda aunque la auditoría falle" do
    # Sin gema de mocks: se redefine el método y se restaura en el `ensure`.
    original = ActivityLog.method(:create!)
    ActivityLog.define_singleton_method(:create!) { |*| raise "auditoría caída" }

    begin
      cambiar(14)
      assert_response :success
    ensure
      ActivityLog.define_singleton_method(:create!, original)
    end

    nota = con_el_colegio(@a.escenario.colegio) do
      @actividad.activity_grades.find_by(student_id: @alumno.user_id)
    end
    assert_equal 14, nota.score.to_i
  end

  # `Grade` en este sistema es el GRADO ESCOLAR. Con los tokens viejos,
  # "grade_destroyed" se leía como "se borró un grado".
  test "los tokens de calificación no se confunden con los de grado escolar" do
    assert_includes ActivityLog::ACTIONS, "calificacion_registrada"
    assert_not_includes ActivityLog::ACTIONS, "grade_created"
  end

  # Eran dos listas escritas a mano y se separaron: `constancia_emitida` tenía
  # etiqueta y no estaba en ACTIONS.
  test "ACTIONS y LABELS no pueden separarse" do
    assert_equal ActivityLog::LABELS.keys.sort, ActivityLog::ACTIONS.sort
    assert_includes ActivityLog::ACTIONS, "constancia_emitida"
  end

  # Una etiqueta sin emisor promete una auditoría que no existe: se consulta el
  # registro para responder "¿quién hizo esto?" y el silencio se confunde con
  # "no pasó". Si esta lista vuelve a tener contenido, alguien agregó la
  # etiqueta antes que el registro.
  test "no hay acciones etiquetadas que nadie emita" do
    assert_empty ActivityLog::ACCIONES_SIN_EMISOR
  end

  # El problema espejo, y el que de verdad se ve: un token que se emite sin
  # etiqueta cae en el `humanize` de respaldo y sale **en inglés** en la pantalla
  # de auditoría — "Department created", "Soporte siga entro".
  #
  # Se leen los controllers en vez de mantener otra lista a mano, que es
  # exactamente cómo se separaron `ACTIONS` y `LABELS`.
  test "todo token que un controller emite tiene su etiqueta en español" do
    # `ActivityGradesController` pasa la acción en una variable; van explícitos.
    emitidos = %w[calificacion_registrada calificacion_modificada calificacion_eliminada].to_set

    Rails.root.glob("app/controllers/**/*.rb").each do |ruta|
      texto = ruta.read
      emitidos.merge(texto.scan(/action:\s*"([a-z_]+)"/).flatten)

      { "creado" => "created", "actualizado" => "updated", "eliminado" => "destroyed" }.each do |es, en|
        texto.scan(/registrar_cambio\(:#{es},\s*@([a-z_]+)/).flatten.each do |modelo|
          # `academic_period` audita como `period_*`: el token viene de antes.
          emitidos << "#{modelo == 'academic_period' ? 'period' : modelo}_#{en}"
        end
      end
    end

    sin_etiqueta = emitidos - ActivityLog::LABELS.keys.to_set

    assert_empty sin_etiqueta,
      "Estos tokens se emiten y no tienen etiqueta, así que la pantalla de " \
      "auditoría los muestra en inglés: #{sin_etiqueta.to_a.sort.join(', ')}"
  end
end
