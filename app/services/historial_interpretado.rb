# La planilla de notas de años anteriores, ya entendida (MOR-126, tanda 3).
#
# Una fila es **un alumno en una materia de un año escolar**, con sus lapsos al
# lado. De ahí sale un `MomentGrade` por lapso y un `FinalGradeBook` por materia,
# los dos marcados `origen: :importada` para que nadie los recalcule.
#
# ## Lo que hace a esta planilla distinta de las otras dos
#
# **Cada fila puede ser de un año escolar diferente.** La matrícula y el pensum
# son de UN año —el de la importación— y por eso el intérprete busca las
# secciones dentro de ese año y listo. Acá no: un historial trae 2021-2022,
# 2022-2023 y 2023-2024 en el mismo archivo, y «3er Año A» significa una sección
# distinta en cada uno.
#
# Así que la sección se resuelve por PAR (año escolar, sección), y lo que puede
# faltar no es solo la sección: puede faltar el año entero, con sus lapsos.
class HistorialInterpretado
  include InterpretaLaPlanilla

  QUE_ES_UNA_FILA = %w[calificación calificaciones].freeze
  COLUMNA_DE_FILA = "Alumno y área".freeze

  class Fila < InterpretaLaPlanilla::Fila
    attr_reader :alumno, :lapsos
    attr_accessor :ano_escolar, :periodo, :materia, :nombre_de_materia, :definitiva, :reparacion

    def initialize(numero:)
      super
      @alumno = {}
      @lapsos = {}
    end

    def nombre_del_alumno
      Normaliza.titulo([ alumno[:first_name], alumno[:last_name], alumno[:second_last_name] ]
                         .compact_blank.join(" "))
    end

    def etiqueta = [ nombre_del_alumno, nombre_de_materia ].compact_blank.join(" · ")

    def alguna_nota? = lapsos.any? || definitiva.present?

    # Alguna de sus notas vino en letra, así que el número exacto se perdió:
    # «B» abarca 17 y 18 y se guarda 17. Se cuenta para avisarlo antes de cargar.
    def literal! = @literal = true
    def literal? = @literal.present?
  end

  attr_reader :filas

  def initialize(planilla:, mapeo:, colegio:, periodo: nil)
    preparar(planilla: planilla, mapeo: mapeo, colegio: colegio, periodo: periodo)

    # ⚠️ TODOS los años del colegio, no el de la importación. Ver la cabecera.
    @periodos = AcademicPeriod.where(school: colegio).to_a
    @todas_las_secciones = Section.includes(:grade).where(grade: @grados).to_a
    @materias = Subject.where(school: colegio).to_a
    @pensum = GradeSubject.where(grade: @grados).pluck(:grade_id, :subject_id).to_set

    @filas = @planilla.filas.map { |cruda| interpretar(cruda) }
  end

  # ⚠️ Las secciones que faltan, POR AÑO ESCOLAR — y solo de los años que ya
  # existen.
  #
  # El método del concern agrupa por sección y busca dentro de UN año, que es lo
  # correcto para la matrícula y el pensum. Acá daba dos cosas mal: buscaba en el
  # año vigente aunque la fila fuera de 2022, y listaba secciones de años que
  # todavía no existen — ruido, porque después de crear el año esas secciones
  # pueden estar perfectamente.
  #
  # Una fila cuyo AÑO falta ya se reporta en `anos_que_faltan`. Una cosa rota se
  # dice una vez.
  def secciones_de_la_planilla
    filas.select { |f| f.periodo && f.seccion_texto.present? }
         .group_by { |f| [ f.periodo, f.seccion_texto ] }
         .map do |(periodo, texto), de_esa|
           grado, nombre = partir(texto)

           { texto: "#{texto} · #{periodo.name}", tambien: [], cuantas: de_esa.size,
             seccion: de_esa.first.seccion, grado: grado, nombre_de_seccion: nombre,
             periodo: periodo, **propuesta_de_grado(grado ? nil : texto) }
         end.sort_by { |s| s[:texto] }
  end

  # ── los resúmenes de esta planilla ────────────────────────────────────────

  # Los años escolares que la planilla nombra y el colegio no tiene. Se listan
  # con su conteo, igual que las secciones: «2021-2022 · 340 calificaciones».
  def anos_que_faltan
    filas.reject { |f| f.periodo || f.ano_escolar.blank? }
         .group_by(&:ano_escolar)
         .map { |nombre, de_ese| { nombre: nombre, cuantas: de_ese.size, lapsos: lapsos_de_la_planilla } }
         .sort_by { |a| a[:nombre] }
  end

  # Cuántos lapsos trae el archivo. Sale de las COLUMNAS mapeadas, no de una
  # pregunta: si la planilla tiene LAPSO 1 y LAPSO 2, ese colegio tiene dos.
  def lapsos_de_la_planilla
    @lapsos_de_la_planilla ||= ColumnasDeHistorial.de_lapsos.count { |c| @mapeo[c.clave.to_s].present? }
  end

  def alumnos_distintos = cargables.map { |f| f.alumno[:cedula_escolar] || f.alumno[:document] }.uniq.size
  def materias_distintas = cargables.map(&:materia).compact.uniq.size
  def anos_distintos = cargables.map(&:periodo).compact.uniq.size

  # Las notas que vinieron en letra. Se listan porque el número exacto se pierde:
  # «B» abarca 17 y 18, y se guarda 17. Ver `EscalaLiteral.numero_de`.
  def en_literal = cargables.select(&:literal?).size

  private

  def interpretar(cruda)
    fila = Fila.new(numero: cruda.numero)

    leer_alumno(fila, cruda)
    leer_ano_escolar(fila, cruda)
    leer_la_seccion_del_ano(fila, cruda)
    leer_materia(fila, cruda)
    leer_notas(fila, cruda)

    fila
  end

  # ── el alumno ─────────────────────────────────────────────────────────────

  def leer_alumno(fila, cruda)
    encabezado = @mapeo["nombre_completo"]
    nombre = NombreDePersona.new(valor(cruda, :nombre_completo),
                                 apellidos_primero: NombreDePersona.apellidos_primero?(encabezado))

    fila.alumno.merge!(nombre.to_h) unless nombre.vacio?
    fila.aviso("Alumno: #{nombre.motivo}") if !nombre.vacio? && !nombre.seguro?

    documento, tipo = documento_y_tipo(valor(cruda, :documento))
    fila.alumno[:document] = documento
    fila.alumno[:document_type] = tipo if documento.present?
    fila.alumno[:cedula_escolar] = valor(cruda, :cedula_escolar).to_s.strip.upcase.presence

    # ⚠️ Sin identificador no se puede saber DE QUIÉN es la nota, y una nota
    # cargada al alumno equivocado es peor que no cargarla. El nombre no sirve:
    # en una matrícula de 360 hay apellidos repetidos, y esto es historial —el
    # alumno puede haber egresado hace tres años—.
    return if fila.alumno[:document].present? || fila.alumno[:cedula_escolar].present?

    fila.error("Sin cédula ni cédula escolar: no se sabe de quién es esta nota")
  end

  # ── cuándo ────────────────────────────────────────────────────────────────

  def leer_ano_escolar(fila, cruda)
    fila.ano_escolar = valor(cruda, :ano_escolar).to_s.strip.gsub(/\s+/, " ")
    return fila.error("Sin año escolar") if fila.ano_escolar.blank?

    fila.periodo = @periodos.find { |p| Normaliza.limpiar(p.name) == Normaliza.limpiar(fila.ano_escolar) }
    return if fila.periodo

    fila.error("El año escolar «#{fila.ano_escolar}» no existe todavía")
  end

  # La sección de ESE año, no la de hoy. Es la diferencia con las otras dos
  # planillas y la razón por la que esto no usa `leer_seccion` del concern.
  def leer_la_seccion_del_ano(fila, cruda)
    texto = valor(cruda, :seccion).to_s.strip.gsub(/\s+/, " ")
    fila.seccion_texto = texto

    return fila.error("Sin sección") if texto.blank?
    return if fila.periodo.nil?  # ya se reportó el año; una falla por fila alcanza

    grado, nombre = partir(texto)
    return fila.error("No hay ningún grado que se llame como «#{texto}»") if grado.nil?

    fila.seccion = @todas_las_secciones.find do |s|
      s.grade_id == grado.id && s.academic_period_id == fila.periodo.id &&
        Normaliza.limpiar(s.name).delete(" ") == Normaliza.limpiar(nombre.to_s).delete(" ")
    end

    fila.error("«#{texto}» no existe en #{fila.ano_escolar}") if fila.seccion.nil?
  end

  # ── la materia ────────────────────────────────────────────────────────────

  # Por nombre o por código, y tiene que estar en el PENSUM del grado: una nota
  # de Química en 1er Grado no es un dato, es un error de la planilla.
  def leer_materia(fila, cruda)
    fila.nombre_de_materia = valor(cruda, :materia).to_s.strip.gsub(/\s+/, " ")
    return fila.error("Sin materia") if fila.nombre_de_materia.blank?

    buscada = Normaliza.limpiar(fila.nombre_de_materia)
    fila.materia = @materias.find { |m| Normaliza.limpiar(m.code) == buscada } ||
                   @materias.find { |m| Normaliza.limpiar(m.name) == buscada }

    return fila.error("El área «#{fila.nombre_de_materia}» no existe en el colegio") if fila.materia.nil?
    return if fila.seccion.nil?

    return if @pensum.include?([ fila.seccion.grade_id, fila.materia.id ])

    fila.aviso("#{fila.materia.name} no está en el pensum de #{fila.seccion.grade.name}. " \
               "Se carga igual, pero conviene revisarlo.")
  end

  # ── las notas ─────────────────────────────────────────────────────────────

  def leer_notas(fila, cruda)
    ColumnasDeHistorial.de_lapsos.each_with_index do |columna, i|
      nota = leer_una_nota(fila, cruda, columna.clave)
      fila.lapsos[i + 1] = nota if nota
    end

    fila.definitiva = leer_una_nota(fila, cruda, :definitiva)
    fila.reparacion = leer_una_nota(fila, cruda, :reparacion)

    return if fila.alguna_nota?

    fila.error("La fila no trae ninguna calificación")
  end

  # Acepta el número del 1 al 20 y también el literal A–E: el historial de un
  # colegio de primaria viene en letras, que es lo único que se imprimió.
  def leer_una_nota(fila, cruda, clave)
    crudo = valor(cruda, clave).to_s.strip
    return nil if crudo.blank?

    if (letra = EscalaLiteral.numero_de(crudo))
      fila.literal!
      return letra
    end

    numero = crudo.tr(",", ".").to_f.round
    return numero if numero.between?(1, 20)

    fila.error("«#{crudo.truncate(12)}» no es una calificación del 1 al 20 ni un literal A–E")
    nil
  end
end
