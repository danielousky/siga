require "test_helper"

# Los dos documentos de fin de año de Educación Inicial (MOR-99).
#
# El texto sale de los formatos del MPPE que entregó Daniel el 11 de septiembre
# de 2026 (`DOCs/209_CertificadoEduI`), y se diferencian en una sola frase:
#
#     III Grupo (el último)  →  CERTIFICACIÓN DE ESTUDIOS
#                               «y continuará estudios en el 1ER. GRADO del
#                                Nivel de Educación Primaria»
#     I y II Grupo           →  CONSTANCIA DE PROSECUCIÓN, y ahí termina
#
# ## ⚠️ Acá NO hay literal, y esa es la diferencia grande con primaria
#
# En Educación Inicial la calificación es un TEXTO —no hay nota, ni escala, ni
# promedio (`docs/specs/educacion-inicial.md`)— y el formato del ministerio lo
# refleja: no tiene casilla para una calificación.
class DocumentosDeInicialTest < ActiveSupport::TestCase
  setup do
    @esc = escenario_academico(nombre: "Jardín", nivel: :preescolar)
  end

  # ⚠️ `find_or_create_by!`: el escenario ya viene con un «1er Nivel» —es el
  # nombre que `NOMBRE_DEL_GRADO` le da a preescolar— y crearlo otra vez choca
  # contra el índice único de `(school_id, name)`.
  def documento_de(nombre_del_grado)
    con_el_colegio(@esc.colegio) do
      grado = Grade.find_or_create_by!(school: @esc.colegio, name: nombre_del_grado) do |g|
        g.level = :preescolar
      end
      seccion = Section.find_or_create_by!(grade: grado, academic_period: @esc.periodo,
                                           name: "U") { |s| s.capacity = 30 }
      inscripcion = Enrollment.find_or_create_by!(student: @esc.alumno, section: seccion) do |e|
        e.enrollment_date = Date.new(2025, 9, 20)
      end

      DocumentoDeInicial.para(enrollment: inscripcion)
    end
  end

  # ── Cuál de los dos ───────────────────────────────────────────────────────

  # ⚠️ El III Grupo es el último de la Etapa Preescolar, y no se deduce de qué
  # grados haya cargado el colegio: lo fija el currículo. Es la misma razón por
  # la que `DocumentoDePrimaria::ULTIMO_GRADO` está escrito — un plantel que
  # todavía no creó el 3er Nivel le habría certificado el fin del nivel a un
  # niño de I Grupo.
  test "el 3er Nivel emite la certificación, que continúa a primaria" do
    d = documento_de("3er Nivel")

    assert_equal "certificacion", d["tipo"]
    assert_equal "III", d["grupo"]
    assert_equal "el 1ER. GRADO del Nivel de Educación Primaria", d["continua_en"]
  end

  test "los otros grupos emiten la constancia de prosecución" do
    %w[1er\ Nivel 2do\ Nivel].each_with_index do |nombre, i|
      d = documento_de(nombre)

      assert_equal "prosecucion", d["tipo"], nombre
      assert_equal %w[I II][i], d["grupo"]
      # ⚠️ La constancia NO dice a dónde continúa: el formato oficial termina en
      # «durante el período escolar ___». Inventar esa frase sería poner en un
      # documento del ministerio algo que su formato no dice.
      assert_nil d["continua_en"], nombre
    end
  end

  # ⚠️ Ante un nombre de grado sin número se emite la CONSTANCIA, que es el
  # documento de todos los años. La certificación —que dice que el niño pasa a
  # primaria— es la que no se puede emitir de más.
  test "un grado sin número emite la constancia, no la certificación" do
    d = documento_de("Preescolar")

    assert_equal "prosecucion", d["tipo"]
  end

  # ── Lo que dice el papel ──────────────────────────────────────────────────

  test "certifica el grupo y la etapa, no una calificación" do
    d = documento_de("2do Nivel")

    assert_equal "Preescolar", d["etapa"]
    assert_equal @esc.periodo.name, d["periodo"]
    # ⚠️ Ni literal ni nota: en este nivel no existen, y el formato tampoco.
    assert_not d.key?("literal")
  end

  # ⚠️ El formato pide la CÉDULA ESCOLAR, que es justamente la que tiene un niño
  # de preescolar: la de identidad no la tiene todavía.
  test "identifica al niño con su cédula escolar" do
    d = documento_de("1er Nivel")

    assert_equal @esc.alumno.user.cedula_escolar, d.dig("estudiante", "identificador")
  end

  # ── Solo Inicial ──────────────────────────────────────────────────────────

  # ⚠️ A un alumno de primaria le toca su propio par de documentos, y a uno de
  # bachillerato la 31059. Emitirle este papel le pondría un nivel que no cursó.
  test "un alumno que no es de Inicial no recibe este documento" do
    otro = escenario_academico(nombre: "Escuela", nivel: :primaria)

    con_el_colegio(otro.colegio) do
      armador = DocumentoDeInicial.new(enrollment: otro.inscripcion)

      assert_not armador.emitible?
    end
  end

  # ── El PDF sale ───────────────────────────────────────────────────────────

  test "los dos se dibujan" do
    %w[3er\ Nivel 1er\ Nivel].each do |nombre|
      pdf = DocumentoDeInicialPdf.new(documento_de(nombre)).render

      assert_operator pdf.bytesize, :>, 1_000, nombre
      assert pdf.start_with?("%PDF"), nombre
    end
  end
end
