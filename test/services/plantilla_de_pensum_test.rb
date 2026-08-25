require "test_helper"

# La plantilla de materias y profesores, y el mapeo que la lee (MOR-126, tanda 2).
#
# El viaje de ida y vuelta —generar la plantilla y volver a leerla con el mapeo
# automático— es lo que destapó los cuatro bugs de la tanda 1. Se repite acá
# porque la planilla de pensum tiene la trampa de nombrar a una sola persona: sin
# la palabra «profesor» que desempate, cualquier columna suelta puede caer en el
# casillero equivocado.
class PlantillaDePensumTest < ActiveSupport::TestCase
  test "la plantilla se entiende a sí misma" do
    hoja = leer(PlantillaDePensum.new.to_stream)

    hoja.encabezados.each do |encabezado|
      esperada = ColumnasDePensum::TODAS.find { |c| c.titulo == encabezado }
      reconocida = ColumnasDePensum.para(encabezado)

      assert_not_nil reconocida, "no reconoce su propia columna «#{encabezado}»"
      assert_equal esperada.clave, reconocida.clave,
                   "«#{encabezado}» se lee como #{reconocida.clave} y debería ser #{esperada.clave}"
    end
  end

  test "la plantilla trae exactamente las columnas definidas" do
    assert_equal ColumnasDePensum.titulos, leer(PlantillaDePensum.new.to_stream).encabezados
  end

  # La forma de esta planilla es lo que más se pregunta: una fila es una materia
  # EN UNA SECCIÓN. Los dos primeros ejemplos lo enseñan sin que haya que leer.
  test "los ejemplos muestran la misma materia en dos secciones" do
    filas = leer(PlantillaDePensum.new.to_stream).filas

    assert_equal 3, filas.size
    assert_equal [ "MAT", "MAT" ], filas.first(2).map { |f| f["CÓDIGO DE LA MATERIA"] }
    assert_equal [ "1er Año A", "1er Año B" ], filas.first(2).map { |f| f["SECCIÓN"] }
  end

  # El tercer ejemplo deja el código vacío a propósito: enseña que la columna es
  # opcional sin tener que decirlo.
  test "un ejemplo deja el código en blanco" do
    assert_nil leer(PlantillaDePensum.new.to_stream).filas.third["CÓDIGO DE LA MATERIA"]
  end

  test "el nombre del archivo lo distingue del de matrícula" do
    colegio = escenario_academico(nombre: "U.E. Santa Rosa").colegio

    assert_match(/\Apensum-u-e-santa-rosa.*\.xlsx\z/,
                 PlantillaDePensum.new(colegio: colegio).nombre_de_archivo)
  end

  # ── el mapeo automático ───────────────────────────────────────────────────

  test "reconoce los encabezados de una planilla de colegio de verdad" do
    {
      "AÑO/SECC"        => :seccion,
      "SECCIÓN"         => :seccion,
      "ASIGNATURA"      => :materia,
      "MATERIA"         => :materia,
      "CÓDIGO"          => :codigo,
      "DEPARTAMENTO"    => :departamento,
      "PROFESOR"        => :profesor,
      "DOCENTE"         => :profesor,
      "CEDULA PROFESOR" => :cedula_del_profesor,
      "C.I."            => :cedula_del_profesor,
      "CORREO"          => :correo_del_profesor,
      "EMAIL"           => :correo_del_profesor
    }.each do |encabezado, clave|
      assert_equal clave, ColumnasDePensum.para(encabezado)&.clave,
                   "«#{encabezado}» no se reconoce como #{clave}"
    end
  end

  # Acá no hay dos personas que desempatar como en matrícula, así que una columna
  # suelta como «CÉDULA» es del profesor: no hay nadie más en esta planilla.
  test "una cédula sin dueño explícito es la del profesor" do
    %w[CÉDULA CEDULA DOCUMENTO].each do |escrito|
      assert_equal :cedula_del_profesor, ColumnasDePensum.para(escrito)&.clave
    end
  end

  test "lo que no reconoce lo deja fuera en vez de adivinar" do
    [ "Nº", "HORAS", "OBSERVACIONES", "", "   " ].each do |encabezado|
      assert_nil ColumnasDePensum.para(encabezado), "«#{encabezado}» no debería mapearse"
    end
  end

  # ⚠️ La diferencia con la matrícula, y es del modelo: `EntraAlSistema` exige el
  # correo del profesor. Un representante sin correo se carga; un profesor no.
  test "el correo es obligatorio acá y no lo es en matrícula" do
    assert ColumnasDePensum[:correo_del_profesor].obligatorio?
    assert_not ColumnasDeMatricula[:correo_del_representante].obligatorio?
  end

  test "las obligatorias son las que el importador no puede deducir" do
    assert_equal %i[seccion materia profesor cedula_del_profesor correo_del_profesor],
                 ColumnasDePensum.obligatorias.map(&:clave)
  end

  private

  def leer(stream)
    archivo = Tempfile.new([ "plantilla", ".xlsx" ])
    archivo.binmode
    archivo.write(stream.read)
    archivo.close
    @temporales ||= []
    @temporales << archivo

    Planilla.new(archivo.path)
  end

  teardown { Array(@temporales).each { |a| a.unlink rescue nil } }
end
