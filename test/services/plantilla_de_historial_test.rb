require "test_helper"

# La plantilla de notas anteriores y el mapeo que la lee (MOR-126, tanda 3).
#
# El viaje de ida y vuelta —generar la plantilla y volver a leerla con el mapeo
# automático— es lo que destapó los cuatro bugs de la tanda 1. Acá tiene una
# trampa propia: hay CUATRO columnas de lapso que se parecen entre sí, y una
# «DEFINITIVA» que también es una nota.
class PlantillaDeHistorialTest < ActiveSupport::TestCase
  test "la plantilla se entiende a sí misma" do
    hoja = leer(PlantillaDeHistorial.new.to_stream)

    hoja.encabezados.each do |encabezado|
      esperada = ColumnasDeHistorial::TODAS.find { |c| c.titulo == encabezado }
      reconocida = ColumnasDeHistorial.para(encabezado)

      assert_not_nil reconocida, "no reconoce su propia columna «#{encabezado}»"
      assert_equal esperada.clave, reconocida.clave,
                   "«#{encabezado}» se lee como #{reconocida.clave} y debería ser #{esperada.clave}"
    end
  end

  test "la plantilla trae exactamente las columnas definidas" do
    assert_equal ColumnasDeHistorial.titulos, leer(PlantillaDeHistorial.new.to_stream).encabezados
  end

  # ⚠️ Cuatro columnas que se parecen. «LAPSO 1» no puede leerse como «LAPSO 4».
  test "cada lapso cae en su propio casillero" do
    (1..ColumnasDeHistorial::LAPSOS).each do |n|
      assert_equal :"lapso_#{n}", ColumnasDeHistorial.para("LAPSO #{n}").clave
    end
  end

  test "reconoce cómo nombra los lapsos un colegio de verdad" do
    {
      "1er LAPSO"    => :lapso_1,
      "2do LAPSO"    => :lapso_2,
      "L3"           => :lapso_3,
      "MOMENTO 1"    => :lapso_1,
      "TRIMESTRE 2"  => :lapso_2,
      "DEFINITIVA"   => :definitiva,
      "PROMEDIO ANUAL" => :definitiva,
      "REPARACIÓN"   => :reparacion,
      "AÑO ESCOLAR"  => :ano_escolar,
      "PERÍODO"      => :ano_escolar,
      "AÑO/SECC"     => :seccion,
      "ASIGNATURA"   => :materia,
      "CEDULA ESCOLAR" => :cedula_escolar,
      "C.I."         => :documento
    }.each do |encabezado, clave|
      assert_equal clave, ColumnasDeHistorial.para(encabezado)&.clave,
                   "«#{encabezado}» no se reconoce como #{clave}"
    end
  end

  # Los tres ejemplos enseñan lo que más se pregunta.
  test "los ejemplos muestran un alumno con dos materias del mismo año" do
    filas = leer(PlantillaDeHistorial.new.to_stream).filas

    assert_equal 3, filas.size
    assert_equal 1, filas.first(2).map { |f| f["CÉDULA ESCOLAR"] }.uniq.size
    assert_not_equal filas.first["MATERIA"], filas.second["MATERIA"]
  end

  # Y el tercero trae la nota en LETRA: el historial de primaria viene así.
  test "un ejemplo trae la nota en literal" do
    assert_equal "B", leer(PlantillaDeHistorial.new.to_stream).filas.third["LAPSO 1"]
  end

  test "el nombre del archivo lo distingue de los otros dos" do
    colegio = escenario_academico(nombre: "U.E. Santa Rosa").colegio

    assert_match(/\Ahistorial-u-e-santa-rosa.*\.xlsx\z/,
                 PlantillaDeHistorial.new(colegio: colegio).nombre_de_archivo)
  end

  # ⚠️ Sin identificador no se sabe de quién es la nota, pero NINGUNO de los dos
  # es obligatorio por separado: un alumno de primaria tiene cédula escolar y no
  # cédula, y un bachiller al revés. La exigencia es de FILA, no de columna.
  test "ni la cédula ni la cédula escolar son obligatorias por sí solas" do
    assert_not ColumnasDeHistorial[:documento].obligatorio?
    assert_not ColumnasDeHistorial[:cedula_escolar].obligatorio?
  end

  test "las obligatorias son las que el importador no puede deducir" do
    assert_equal %i[nombre_completo ano_escolar seccion materia],
                 ColumnasDeHistorial.obligatorias.map(&:clave)
  end

  test "lo que no reconoce lo deja fuera en vez de adivinar" do
    [ "Nº", "OBSERVACIONES", "HORAS", "", "   " ].each do |encabezado|
      assert_nil ColumnasDeHistorial.para(encabezado), "«#{encabezado}» no debería mapearse"
    end
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
