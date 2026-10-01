# Los certificados de fin de año de UNA sección: qué papel le toca, quiénes
# salen con «toda la sección» y quiénes no.
#
# Ver `docs/specs/certificados-en-documentos.md`.
#
# ## Por qué existe
#
# Hasta el 1 de octubre de 2026 cada certificado se emitía desde la ficha de su
# alumno, de a uno, y la regla de «cuál papel» vivía repartida en tres acciones
# de `DocumentosOficialesController`. Con la pestaña de «Documentos» hace falta
# contestar por la SECCIÓN, y antes de emitir:
#
#     ¿qué papel sale?            el grado lo decide, no la secretaria
#     ¿a quiénes?                 a los regulares
#     ¿quién NO sale en el lote?  quien repite — donde el papel dice «promovido»
#     ¿quién sale incompleto?     quien no tiene calificación definitiva
#
# ## ⚠️ Esta clase PREGUNTA, no decide otra vez
#
# Cuál papel le toca a un grado lo saben `DocumentoDePrimaria` y
# `DocumentoDeInicial`; quién repite lo sabe `PromocionDeAlumnos`. Acá no hay
# una segunda copia de ninguna de las dos reglas: una copia es una regla que el
# día de mañana dice otra cosa — y en esta pantalla «otra cosa» es un documento
# oficial que contradice a la pantalla de al lado.
class CertificadosDeLaSeccion
  CERTIFICACION_31059 = "Certificación de Calificaciones (31059)".freeze

  # Quien queda fuera del lote, con lo que la pantalla le va a decir a quien
  # emite: no «1 excluido», sino quién y por qué.
  Excluido = Data.define(:inscripcion, :aplazadas) do
    def alumno = inscripcion.student.user
  end

  # `director` es quien firma. Sin él cada armador lo busca por su cuenta —una
  # consulta por alumno—, así que quien emite una sección entera lo pasa.
  def initialize(seccion:, director: nil)
    @seccion = seccion
    @grado = seccion.grade
    @director = director
  end

  attr_reader :seccion

  def nivel
    if @grado.preescolar? then :inicial
    elsif @grado.primaria? then :primaria
    elsif @grado.media? then :media
    end
  end

  # El papel que sale de esta sección. Se puede preguntar con la sección vacía:
  # es lo que la pantalla escribe ANTES del botón.
  def papel
    case nivel
    when :inicial  then DocumentoDeInicial::NOMBRES.fetch(DocumentoDeInicial.tipo_para(@grado))
    when :primaria then DocumentoDePrimaria::NOMBRES.fetch(DocumentoDePrimaria.tipo_para(@grado))
    when :media    then CERTIFICACION_31059
    end
  end

  # ⚠️ Solo los REGULARES. Un retirado no terminó el año: su papel diría que
  # cursó un grado que dejó a la mitad. Es el mismo criterio de la ficha, que
  # solo ofrece el documento a quien tiene una inscripción activa.
  def inscripciones
    @inscripciones ||= @seccion.enrollments.regular.includes(student: :user).to_a
                               .sort_by { |i| [ i.student.user.last_name.to_s, i.student.user.first_name.to_s ] }
  end

  # Lo que emite «toda la sección».
  def del_lote
    @del_lote ||= inscripciones - fuera_del_lote.map(&:inscripcion)
  end

  # ⚠️ Quien REPITE no sale en el lote — y solo donde el papel AFIRMA la
  # promoción.
  #
  # Decisión de Daniel, 1 de octubre de 2026. El documento de primaria dice
  # «siendo promovido(a) al 4to Grado» sin mirar las notas. De a uno lo decide
  # quien lo firma; de a veinticuatro, nadie lo mira, y el colegio entrega un
  # papel oficial que dice lo contrario de su propia pantalla de promoción.
  #
  # ⚠️ No es un bloqueo: eligiendo a ese alumno en el desplegable, sale. Lo que
  # cambia es que hay que QUERER emitirlo. La norma de primaria no es clara y
  # la promoción la confirma el director; SIGA no le niega el papel, le quita
  # la posibilidad de imprimirlo sin enterarse.
  def fuera_del_lote
    return [] unless afirma_la_promocion?

    @fuera_del_lote ||= inscripciones.filter_map do |inscripcion|
      veredicto = veredictos.fetch(inscripcion.id)

      Excluido.new(inscripcion: inscripcion, aplazadas: veredicto.aplazadas) if veredicto.repite?
    end
  end

  # ⚠️ «Sin calificación definitiva» NO es «repite», y por eso SÍ salen.
  #
  # Un colegio en su primer año con SIGA tiene las notas del año pasado en
  # papel: ninguno de sus alumnos tiene definitiva. El certificado sale igual,
  # con el literal como una línea para llenar a mano —que es lo que hace el
  # formato del ministerio—, y la pantalla lo dice antes para que la línea en
  # blanco no sea una sorpresa en la impresora.
  #
  # Solo primaria: es el único de los tres papeles que lleva un literal.
  def sin_definitiva
    return [] unless nivel == :primaria

    @sin_definitiva ||= begin
      con_nota = FinalGradeBook.where(enrollment_id: del_lote.map(&:id))
                               .where.not(final_score: nil).distinct.pluck(:enrollment_id)

      del_lote.reject { |inscripcion| con_nota.include?(inscripcion.id) }
    end
  end

  # El PDF de esas inscripciones: una página —o las que ocupe— por alumno.
  def pdf_de(inscripciones)
    case nivel
    when :inicial
      DocumentoDeInicialPdf.new(inscripciones.map { |i| DocumentoDeInicial.para(enrollment: i, firmante: @director) })
    when :primaria
      DocumentoDePrimariaPdf.new(inscripciones.map { |i| DocumentoDePrimaria.para(enrollment: i, firmante: @director) })
    when :media
      CertificacionPdf.new(inscripciones.map { |i| CertificacionDeCalificaciones.para(student: i.student).merge("firmante" => firma) })
    end
  end

  # Con el mismo arranque que usa la ficha —«certificado-primaria-…»— para que
  # el archivo se llame igual venga de donde venga.
  def nombre_del_archivo(inscripciones)
    de_quien = inscripciones.one? ? apellido_de(inscripciones.first) : "#{@grado.name.parameterize}-#{@seccion.name.parameterize}"

    "#{arranque_del_archivo}-#{de_quien}.pdf"
  end

  # Con qué acción queda en la auditoría: la MISMA de la ficha. Es el mismo
  # papel, y quien busque «quién emitió certificados de primaria» tiene que
  # encontrar los dos caminos con una sola búsqueda.
  def accion_de_auditoria
    { inicial: "documento_de_inicial_emitido",
      primaria: "documento_de_primaria_emitido",
      media: "certificacion_emitida" }.fetch(nivel)
  end

  private

  # Los dos de primaria dicen «siendo promovido(a)». La 31059 no afirma nada:
  # es el historial de notas, y es cierto también para quien repite — sacarlo
  # del lote sería negarle un papel que no miente. En Inicial no hay notas, así
  # que nadie «repite».
  def afirma_la_promocion? = nivel == :primaria

  def veredictos
    @veredictos ||= PromocionDeAlumnos.veredictos(inscripciones, tope: @grado.school.tope_de_arrastre.to_i)
  end

  def apellido_de(inscripcion)
    inscripcion.student.user.apellidos.to_s.parameterize.presence || inscripcion.student_id.to_s
  end

  def arranque_del_archivo
    case nivel
    when :inicial  then "#{DocumentoDeInicial.tipo_para(@grado)}-inicial"
    when :primaria then "#{DocumentoDePrimaria.tipo_para(@grado)}-primaria"
    when :media    then "certificacion-31059"
    end
  end

  # La 31059 recibe la firma como un par de textos, no como el registro: así la
  # arma `DocumentosOficialesController` y así la espera el dibujante.
  def firma
    return {} if @director.nil?

    { "nombre" => @director.user.nombre_completo, "documento" => @director.user.identificador }
  end
end
