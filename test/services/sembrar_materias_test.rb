require "test_helper"

# Las materias oficiales, sembradas por grado (MOR-208).
#
# Daniel: *«las materias básicas también las podemos deducir. No hay que pedirle
# que cargue matemáticas, castellano, biología, historia»*.
class SembrarMateriasTest < ActiveSupport::TestCase
  setup do
    @colegio = Current.sin_aislamiento do
      School.create!(name: "U.E. Semilla", dea_code: "PDSEM#{Process.pid}",
                     entidad_federal: "Lara", municipio: "Iribarren")
    end
  end

  def sembrar(*niveles)
    con_el_colegio(@colegio) do
      SembrarGrados.para(@colegio, niveles: niveles)
      SembrarMaterias.para(@colegio)
    end
  end

  def materias_de(nombre_del_grado)
    con_el_colegio(@colegio) { Grade.find_by(name: nombre_del_grado).subjects.pluck(:code).sort }
  end

  # ⚠️ El año importa, y es la razón de que el catálogo guarde grados y no
  # niveles: sembrar Física en 1er Año llenaría el boletín de un chico de 12
  # años con una materia que no cursa.
  test "cada materia cae SOLO en los años en que se cursa" do
    sembrar(:secundaria)

    assert_includes materias_de("1er Año"), "CN", "Ciencias Naturales va en 1ero y 2do"
    assert_not_includes materias_de("1er Año"), "FIS", "Física empieza en 3er Año"

    assert_includes materias_de("3er Año"), "FIS"
    assert_not_includes materias_de("3er Año"), "CN", "Ciencias Naturales termina en 2do"

    assert_includes materias_de("5to Año"), "CT", "Ciencias de la Tierra es solo de 5to"
    assert_not_includes materias_de("4to Año"), "CT"
  end

  # ⚠️ Un colegio que llega hasta 3er Año no dicta Ciencias de la Tierra. Por eso
  # el catálogo se consulta por GRADOS y no por nivel.
  test "un bachillerato incompleto recibe solo lo de sus años" do
    con_el_colegio(@colegio) do
      %w[1er\ Año 2do\ Año 3er\ Año].each { |n| Grade.create!(school: @colegio, name: n) }
      SembrarMaterias.para(@colegio)
    end

    codigos = con_el_colegio(@colegio) { Subject.pluck(:code) }
    assert_includes codigos, "FIS", "Física se dicta desde 3ero"
    assert_not_includes codigos, "CT", "Ciencias de la Tierra es de 5to, que este colegio no tiene"
    assert_not_includes codigos, "FSN", "Soberanía Nacional es de 4to y 5to"
  end

  # ⚠️ Preescolar NO se califica por materias: tiene dos áreas de aprendizaje y
  # se evalúa por componentes, en escala literal.
  test "preescolar no recibe ninguna materia" do
    resultado = sembrar(:preescolar)

    assert_equal 0, resultado.total, "sembrarle «Matemática» a un 2do Nivel es un error de dominio"
  end

  # ⚠️ «Matemática» (primaria) y «Matemáticas» (bachillerato) proponen las dos
  # `MAT`, y `subjects.code` es único por colegio. Son la misma materia con dos
  # nombres: se reutiliza, como hace el importador de pensum.
  test "un colegio completo no duplica la materia que comparte código" do
    sembrar(:primaria, :secundaria)

    con_el_colegio(@colegio) do
      %w[MAT CN EF].each do |compartido|
        assert_equal 1, Subject.where(code: compartido).count,
                     "#{compartido} lo proponen primaria y bachillerato: tiene que ser UNA materia"
      end
    end
  end

  test "la materia compartida cuelga de los grados de LOS DOS niveles" do
    sembrar(:primaria, :secundaria)

    assert_includes materias_de("3er Grado"), "MAT"
    assert_includes materias_de("3er Año"), "MAT"
  end

  # Un colegio que agrega bachillerato dos años después vuelve a pasar por acá.
  test "es idempotente y no toca lo que ya existe" do
    sembrar(:primaria)
    antes = con_el_colegio(@colegio) { Subject.order(:code).pluck(:code, :name) }

    segunda = con_el_colegio(@colegio) { SembrarMaterias.para(@colegio) }

    assert_empty segunda.materias, "no debería crear ninguna de nuevo"
    assert_equal 0, segunda.asignaciones, "ni duplicar el pensum de un grado"
    assert_equal antes, con_el_colegio(@colegio) { Subject.order(:code).pluck(:code, :name) }
  end

  test "agregar un nivel después suma solo lo que falta" do
    sembrar(:primaria)

    segunda = sembrar(:primaria, :secundaria)

    assert segunda.materias.any?, "el bachillerato trae materias nuevas"
    assert_includes materias_de("1er Año"), "CAS"
  end

  # ⚠️ Lo que se siembra es lo que se CALIFICA, no las cuatro «áreas de
  # aprendizaje» del currículo. Daniel: «las materias que se califican, no las
  # cuatro áreas».
  test "primaria recibe materias de libreta, no las áreas del currículo" do
    sembrar(:primaria)

    # ⚠️ Por el GETTER y no por `pluck`: la materia se guarda en MAYÚSCULA y se
    # lee en Tipo Título (`MOR-188`), y `pluck` va derecho a la columna.
    nombres = con_el_colegio(@colegio) { Subject.all.map(&:name) }
    assert_includes nombres, "Matemática"
    assert_includes nombres, "Ciencias Naturales"
    assert_not nombres.any? { |n| n.include?("Comunicación y Cultura") },
               "las áreas anchas del currículo dan un boletín que nadie reconoce"
  end

  # ⚠️ Decisión de Daniel: el arranque NO crea departamentos.
  test "no crea ningún departamento" do
    sembrar(:primaria, :secundaria)

    con_el_colegio(@colegio) do
      assert_equal 0, Department.count
      assert Subject.all.all? { |m| m.department_id.nil? }
    end
  end

  # El 6to Año es el de la especialidad: sus materias las decide el colegio
  # según qué técnico gradúa, y no hay un pensum nacional que proponer.
  test "el 6to año de la media técnica no recibe materias propuestas" do
    sembrar(:media_tecnica)

    assert_empty materias_de("6to Año")
    assert_includes materias_de("5to Año"), "CT", "pero los cinco años del bachillerato sí"
  end
end
