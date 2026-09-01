# Copia la estructura de un año escolar al siguiente (MOR-166).
#
# ## Qué es «la estructura», y qué NO
#
# Lo que un colegio vuelve a escribir cada septiembre y es casi idéntico:
#
#     SE COPIA                          NO SE COPIA
#     ────────                          ───────────
#     las secciones (1er Año A, B, C)   los alumnos    ← promover es otra cosa
#     su cupo y su aula                 las notas      ← son del año que pasó
#     su profesor guía                  la asistencia  ← ídem
#     quién dicta qué en cada una       los boletines  ← ídem
#
# Los **grados** y las **materias** no aparecen en ninguna columna porque no son
# del año: cuelgan del colegio y ya están. Lo mismo el pensum (`GradeSubject`).
#
# ⚠️ **Los alumnos NO se copian, y es a propósito.** Pasar un alumno de 1er a
# 2do Año depende de si aprobó, y eso lo dice el Artículo 112 —con su segunda
# oportunidad— no un botón de copiar. Copiar la matrícula tal cual repetiría a
# trescientos sesenta alumnos en el mismo grado. La promoción es otra
# funcionalidad y merece su propia pantalla.
#
# ## Por qué existe
#
# Un colegio de diez secciones con ocho materias cada una son **ochenta**
# asignaciones de profesor, escritas a mano, todos los septiembres — cuando el
# 90 % son las mismas del año anterior. Es la clase de trabajo que hace que un
# colegio no renueve.
#
# ## ERROR vs AVISO, como en el importador
#
# La distinción es la misma de `§ 3` y por la misma razón. Una sección que no se
# puede crear es un **error**: sin ella no hay dónde poner nada, y la copia
# entera se deshace. Una asignación de profesor que no se puede recrear —el
# profesor renunció y ya no está— es un **aviso**: se salta, se copia todo lo
# demás, y se dice cuál faltó. Si todo fuera error, un colegio con un profesor
# menos no podría copiar nada.
class CopiarLaEstructura
  Resultado = Data.define(:secciones, :ya_estaban, :asignaciones, :avisos) do
    def copio_algo? = secciones.any? || asignaciones.positive?
    def total_secciones = secciones.size + ya_estaban.size
  end

  def self.de(origen, al:) = new(origen, al).copiar

  def initialize(origen, destino)
    @origen = origen
    @destino = destino
  end

  # Cuánto hay para copiar, SIN copiar nada. Es lo que se muestra antes de
  # confirmar: «10 secciones y 82 asignaciones» es una decisión informada;
  # «¿Copiar?» a secas, no.
  def self.cuanto_hay(origen)
    secciones = Section.where(academic_period_id: origen.id)

    { secciones: secciones.count,
      asignaciones: TeacherSection.where(section_id: secciones.select(:id)).count }
  end

  def copiar
    return vacio unless copiable?

    creadas, ya_estaban, asignaciones, avisos = [], [], 0, []

    # ⚠️ Una transacción para las SECCIONES. Media estructura copiada es peor
    # que ninguna: el director cree que ya está y descubre en octubre que faltan
    # cuatro secciones.
    ActiveRecord::Base.transaction do
      secciones_del_origen.each do |vieja|
        # ⚠️ Se pregunta UNA vez. `crear_seccion` mete la nueva en el índice
        # —para que dos secciones iguales del origen no se dupliquen— así que
        # preguntar de nuevo la encuentra y la cuenta como «ya estaba».
        ya = existente(vieja)
        nueva = ya || crear_seccion(vieja)
        (ya ? ya_estaban : creadas) << nueva

        copiadas, salteadas = copiar_asignaciones(vieja, nueva)
        asignaciones += copiadas
        avisos.concat(salteadas)
      end
    end

    Resultado.new(secciones: creadas, ya_estaban: ya_estaban,
                  asignaciones: asignaciones, avisos: avisos)
  end

  private

  attr_reader :origen, :destino

  # Copiar de un colegio a otro sería una fuga, y copiar un año sobre sí mismo
  # no tiene sentido. Las dos se comprueban acá y no en el controller: el
  # servicio es lo que se puede llamar desde una tarea o una consola.
  def copiable?
    origen.present? && destino.present? &&
      origen.id != destino.id &&
      origen.school_id == destino.school_id
  end

  def vacio = Resultado.new(secciones: [], ya_estaban: [], asignaciones: 0, avisos: [])

  def secciones_del_origen
    @secciones_del_origen ||=
      Section.where(academic_period_id: origen.id).includes(:grade, teacher_sections: [ :teacher, :subject ]).to_a
  end

  # Ya existentes en el destino, indexadas por (grado, nombre) — que es la clave
  # única real de una sección dentro de un año.
  def ya_en_el_destino
    @ya_en_el_destino ||= Section.where(academic_period_id: destino.id).index_by { |s| [ s.grade_id, s.name ] }
  end

  def existente(vieja) = ya_en_el_destino[[ vieja.grade_id, vieja.name ]]

  def crear_seccion(vieja)
    Section.create!(
      grade_id: vieja.grade_id, academic_period: destino, name: vieja.name,
      capacity: vieja.capacity, classroom: vieja.classroom,
      # El guía se copia aunque puede haber cambiado: nueve de cada diez siguen
      # siendo el mismo, y corregir uno es más rápido que asignar diez.
      leader_teacher_id: vieja.leader_teacher_id
    ).tap { |nueva| ya_en_el_destino[[ nueva.grade_id, nueva.name ]] = nueva }
  end

  # ⚠️ Cada asignación por separado y tolerando el fallo: un profesor que ya no
  # está en el colegio no puede tumbar la copia de las otras setenta y nueve.
  def copiar_asignaciones(vieja, nueva)
    copiadas, salteadas = 0, []
    existentes = TeacherSection.where(section_id: nueva.id).pluck(:subject_id).to_set

    vieja.teacher_sections.each do |asignacion|
      next if existentes.include?(asignacion.subject_id)

      # `SAVEPOINT` propio: sin él, un `create!` fallido invalida la transacción
      # entera de PostgreSQL y las siguientes revientan con
      # «current transaction is aborted».
      ActiveRecord::Base.transaction(requires_new: true) do
        TeacherSection.create!(section: nueva, teacher_id: asignacion.teacher_id,
                               subject_id: asignacion.subject_id)
        copiadas += 1
      end
    rescue ActiveRecord::RecordInvalid => e
      salteadas << "#{nueva.grade.name} #{nueva.name} · #{asignacion.subject.name}: #{e.record.errors.full_messages.to_sentence}"
    end

    [ copiadas, salteadas ]
  end
end
