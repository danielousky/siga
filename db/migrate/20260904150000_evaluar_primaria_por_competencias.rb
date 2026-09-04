# Evaluar Educación Primaria por competencias (MOR-136).
#
# Spec congelado: `docs/specs/mor-136-evaluacion-de-primaria.md`.
#
# ## ⚠️ Esto NO toca la aritmética, y esa es la decisión que lo hace barato
#
# Daniel, cerrando el spec: *«la nota del lapso viene de la evaluación, porque
# la evaluación tiene una evaluation activity que tiene un peso… en realidad las
# competencias terminan siendo solo para mostrarlas en la boleta junto con los
# indicadores y la rúbrica»*.
#
# O sea que `GradeCalculator`, `activity_grades`, `moment_grades` y
# `final_grade_books` se quedan exactamente como están. Lo que estas cuatro
# tablas agregan es un PLAN descriptivo y su etiquetado.
#
#     LA NOTA — como hoy, sin tocar nada
#     evaluation_activities (peso) ──► activity_grades ──► moment_grades ──► anual
#
#     LA BOLETA — lo único nuevo
#     la actividad se ETIQUETA con lo que evalúa
#              └──► materia → competencia → indicadores → nivel de rúbrica
#
# ## El profesor califica con NÚMEROS. La rúbrica es una máscara
#
# Daniel: *«sencillamente se califica con número en primera instancia, y los
# profesores califican con números»*. Y la rúbrica la define el COLEGIO.
#
# ⚠️ La razón por la que el sustrato es el número y no el nivel la dio él mismo
# sin darse cuenta: *«había colegios que solo tenían tres [niveles], lo que lo
# hacía muy complicado porque metías en el mismo saco a estudiantes con 13 que a
# estudiantes con 17»*. Capturar el NIVEL pierde esa información **para
# siempre**; capturar el número y mostrar el nivel no pierde nada, y el colegio
# de tres niveles simplemente tiene una máscara más gruesa.
#
# Es lo que Cyndi ya vivía en Arcada, citado en `EscalaLiteral` desde `MOR-129`:
# *«la niña sacó 19, por eso tiene PC»*.
class EvaluarPrimariaPorCompetencias < ActiveRecord::Migration[8.1]
  TABLAS = %w[rubrics competencies indicators activity_competencies].freeze

  def change
    # ── La rúbrica, que define cada colegio ─────────────────────────────────
    #
    # Configurable y no constante —al revés que `GradoOficial` o `MateriaOficial`—
    # porque cambia de colegio en colegio y porque **es presentación**: cambiarla
    # no reescribe ninguna nota. Esa es toda la diferencia. Si el nivel fuera lo
    # que se guarda, esta tabla sería una bomba: mover un valor reescribiría el
    # lapso de todo el colegio.
    create_table :rubrics do |t|
      t.references :school, null: false, foreign_key: true

      # «PC», «PA». Lo que se imprime en la boleta.
      t.string :code, null: false
      # «Proceso consolidado». Lo que se lee en la leyenda del pie.
      t.string :name, null: false
      # Para el representante que no sabe qué significa. Opcional.
      t.text :description

      # ⚠️ `valor` es el PISO de la banda, no su tope ni su punto medio.
      #
      # El nivel de una nota es «el más alto cuyo valor no la supera». Con una
      # sola columna eso produce bandas CONTIGUAS donde no puede haber huecos ni
      # solapes. Con el valor como tope, un colegio deja el 16 sin nivel y se
      # entera el día que salga una boleta con un renglón en blanco.
      #
      #     PC 19 → 19-20    PA 17 → 17-18    PI 14 → 14-16
      #     PD 10 → 10-13    NP  1 →  1-9     ← reprobado
      t.integer :valor, null: false

      t.timestamps
    end

    add_index :rubrics, [ :school_id, :code ], unique: true
    # ⚠️ Dos niveles con el mismo piso hacen ambigua la traducción de una nota.
    add_index :rubrics, [ :school_id, :valor ], unique: true
    # El mismo CHECK del Art. 108 que llevan las otras cinco tablas de notas.
    add_check_constraint :rubrics, "valor BETWEEN 1 AND 20", name: "rubrics_valor_del_1_al_20"

    # ── El plan de evaluación: competencias ─────────────────────────────────
    #
    # ⚠️ Cuelga de la SECCIÓN, no del grado ni del `grade_subject`. Corroborado
    # con Cyndi Montoya, y revierte lo que habían recomendado las dos revisiones:
    # **cada profesor es autónomo en su gestión**. Dos secciones del mismo grado
    # pueden tener planes distintos, aunque lo normal sea que se copien.
    #
    # El trío `(section, subject, evaluation_moment)` es el MISMO de
    # `evaluation_activities` a propósito: el plan y las evaluaciones que lo
    # cumplen viven en la misma unidad de trabajo.
    create_table :competencies do |t|
      t.references :school,            null: false, foreign_key: true
      t.references :section,           null: false, foreign_key: true
      t.references :subject,           null: false, foreign_key: true
      t.references :evaluation_moment, null: false, foreign_key: true

      # Prosa de un docente, guardada TAL CUAL se escribió. No se normaliza para
      # mostrar: `Subject#name` puede permitirse la mayúscula porque es una
      # palabra, y esto es un párrafo de cuarenta.
      t.text :descripcion, null: false

      # ⚠️ Su gemela sin acentos y en minúscula, SOLO para el índice único.
      #
      # Sin esto, «Resuelve problemas de adición» y «resuelve problemas de
      # adicion» son dos filas, y el plan de la sección termina con la misma
      # competencia dos veces — que es exactamente lo que este issue viene a
      # evitar. Es el mismo reparto de `Subject#name` / `#name_canonico`.
      t.text :descripcion_canonica, null: false

      t.integer :orden, null: false, default: 0

      t.timestamps
    end

    add_index :competencies,
              [ :section_id, :subject_id, :evaluation_moment_id, :descripcion_canonica ],
              unique: true, name: "index_competencies_sin_repetir_en_el_plan"
    # La sugerencia del plan del año anterior busca por acá.
    add_index :competencies, [ :school_id, :subject_id ]

    # ── Los indicadores: describen, no se califican ─────────────────────────
    #
    # ⚠️ NO llevan nivel. El pedido de `MOR-216` —que los padres entiendan
    # mejor— se resuelve IMPRIMIÉNDOLOS. Pedirle a la maestra un nivel por
    # indicador donde juzgó uno por competencia produce el mismo valor repetido
    # tres veces: precisión falsa impresa en un papel que la familia guarda.
    create_table :indicators do |t|
      t.references :school,     null: false, foreign_key: true
      t.references :competency, null: false, foreign_key: true

      t.text    :descripcion, null: false
      t.text    :descripcion_canonica, null: false
      t.integer :orden, null: false, default: 0

      t.timestamps
    end

    add_index :indicators, [ :competency_id, :descripcion_canonica ],
              unique: true, name: "index_indicators_sin_repetir_en_la_competencia"

    # ── Qué evalúa cada evaluación ──────────────────────────────────────────
    #
    # El enganche entre el plan y la nota, y lo único que hace falta para que la
    # boleta pueda decir «Resuelve situaciones con fracciones… PA».
    #
    # ⚠️ Se etiqueta la COMPETENCIA, no el indicador, y es una decisión.
    #
    # El diagrama original apuntaba al indicador, pero **una competencia puede
    # no tener ninguno** —la boleta real del Teresiano trae varias así— y
    # entonces no habría manera de etiquetarla. Marcar indicadores en el
    # formulario es azúcar de la pantalla: lo que se guarda es su competencia.
    # Si algún día hace falta la precisión del indicador, se agrega y es aditivo.
    #
    # Muchos a muchos de verdad: una prueba evalúa dos competencias, y una
    # competencia se evalúa en la prueba y en el proyecto.
    create_table :activity_competencies do |t|
      t.references :school,     null: false, foreign_key: true
      t.references :competency, null: false, foreign_key: true
      t.references :evaluation_activity, null: false, foreign_key: true

      t.timestamps
    end

    add_index :activity_competencies, [ :evaluation_activity_id, :competency_id ],
              unique: true, name: "index_activity_competencies_sin_repetir"

    # ── El aislamiento, en la base ──────────────────────────────────────────
    #
    # ⚠️ Las cuatro llevan `school_id` MATERIALIZADO, y no es redundancia: el
    # RLS de PostgreSQL evalúa columnas de la fila, no asociaciones. Una tabla
    # que dedujera su colegio por cadena no se podría aislar (`MOR-85`).
    #
    # ⚠️ Y el guarda no habría avisado. `aislamiento_estructural_test` pregunta
    # «¿qué tablas TIENEN school_id y les falta RLS?»: una tabla SIN la columna
    # pasa en verde y la lee todo el mundo.
    reversible do |dir|
      dir.up do
        TABLAS.each do |tabla|
          execute "ALTER TABLE #{tabla} ENABLE ROW LEVEL SECURITY"
          execute "ALTER TABLE #{tabla} FORCE  ROW LEVEL SECURITY"
          execute <<~SQL.squish
            CREATE POLICY aislamiento_por_colegio ON #{tabla}
              USING (#{condicion})
              WITH CHECK (#{condicion})
          SQL
        end
      end

      dir.down do
        TABLAS.each { |tabla| execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON #{tabla}" }
      end
    end
  end

  private

  def condicion
    <<~SQL.squish
      current_setting('siga.bypass_rls', true) = 'on'
      OR school_id IS NOT DISTINCT FROM NULLIF(current_setting('siga.school_id', true), '')::bigint
    SQL
  end
end
