require "test_helper"

# La plantilla que el colegio descarga, y el mapeo automático que la lee.
#
# Van juntas a propósito: la prueba que más vale es que la herramienta entienda
# el archivo que ella misma escribe. Las dos veces que el mapeo falló, fue eso
# lo que lo destapó, no un test escrito de antemano.
class PlantillaDeMatriculaTest < ActiveSupport::TestCase
  # ── el viaje de ida y vuelta ──────────────────────────────────────────────

  test "la plantilla se entiende a sí misma" do
    hoja = leer(PlantillaDeMatricula.new.to_stream)

    hoja.encabezados.each do |encabezado|
      esperada = ColumnasDeMatricula::TODAS.find { |c| c.titulo == encabezado }
      reconocida = ColumnasDeMatricula.para(encabezado)

      assert_not_nil reconocida, "no reconoce su propia columna «#{encabezado}»"
      assert_equal esperada.clave, reconocida.clave,
                   "«#{encabezado}» se lee como #{reconocida.clave} y debería ser #{esperada.clave}"
    end
  end

  test "trae ejemplos que se pueden copiar" do
    hoja = leer(PlantillaDeMatricula.new.to_stream)

    assert_equal 3, hoja.filas.size
    assert_equal "DE LA CRUZ MARÍN JOSÉ LUIS", hoja.filas.first["APELLIDOS Y NOMBRES DEL ALUMNO"]
  end

  # Los tres ejemplos enseñan algo distinto, y el segundo es el que más dudas
  # ahorra: dos hermanos con la MISMA representante y la misma cédula.
  test "los ejemplos muestran dos hermanos con una sola representante" do
    filas = leer(PlantillaDeMatricula.new.to_stream).filas
    cedulas = filas.first(2).map { |f| f["CÉDULA DEL REPRESENTANTE"] }

    assert_equal 1, cedulas.uniq.size
  end

  test "el nombre del archivo lleva el del colegio" do
    colegio = escenario_academico(nombre: "U.E. Santa Rosa").colegio

    assert_match(/\Amatricula-u-e-santa-rosa.*\.xlsx\z/,
                 PlantillaDeMatricula.new(colegio: colegio).nombre_de_archivo)
  end

  # ── el mapeo automático ───────────────────────────────────────────────────

  test "reconoce los encabezados de una planilla de colegio de verdad" do
    {
      "APELLIDOS Y NOMBRES"  => :nombre_completo,
      "C.I."                 => :documento,
      "CEDULA ESCOLAR"       => :cedula_escolar,
      "F. NACIM."            => :fecha_de_nacimiento,
      "SEXO"                 => :sexo,
      "AÑO/SECC"             => :seccion,
      "REPRESENTANTE"        => :representante,
      "CORREO REPRESENTANTE" => :correo_del_representante,
      "TELEFONO"             => :telefono_del_representante
    }.each do |encabezado, clave|
      assert_equal clave, ColumnasDeMatricula.para(encabezado)&.clave,
                   "«#{encabezado}» no se reconoce como #{clave}"
    end
  end

  # ⚠️ Primer bug que destapó el viaje de ida y vuelta.
  #
  # «APELLIDOS Y NOMBRES DEL REPRESENTANTE» contiene «apellidos y nombres», que
  # es sinónimo del nombre del ALUMNO y estaba declarado primero. El importador
  # habría cargado el nombre de la madre en el campo del hijo.
  test "distingue el nombre del alumno del nombre del representante" do
    assert_equal :nombre_completo,
                 ColumnasDeMatricula.para("APELLIDOS Y NOMBRES DEL ALUMNO").clave
    assert_equal :representante,
                 ColumnasDeMatricula.para("APELLIDOS Y NOMBRES DEL REPRESENTANTE").clave
  end

  # ⚠️ Segundo bug. En «CORREO REPRESENTANTE» hay dos señales: «correo» dice QUÉ
  # campo es y «representante» dice DE QUIÉN. Compitiendo, ganaba la segunda por
  # ser más larga, y el correo se leía como el nombre.
  test "la palabra que marca de quién es no se come a la que dice qué es" do
    assert_equal :correo_del_representante, ColumnasDeMatricula.para("CORREO REPRESENTANTE").clave
    assert_equal :cedula_del_representante, ColumnasDeMatricula.para("CEDULA REPRESENTANTE").clave
    assert_equal :telefono_del_representante, ColumnasDeMatricula.para("TELEFONO REPRESENTANTE").clave
  end

  test "no le importan los acentos, las mayúsculas ni la puntuación" do
    %w[SECCIÓN seccion Sección SECCION].each do |escrito|
      assert_equal :seccion, ColumnasDeMatricula.para(escrito).clave
    end

    assert_equal :documento, ColumnasDeMatricula.para("C.I.").clave
    assert_equal :documento, ColumnasDeMatricula.para("ci").clave
  end

  # Una planilla trae columnas que a SIGA no le sirven —el número de orden, las
  # observaciones del colegio—. Ignorarlas es correcto; inventarles un destino
  # sería peor.
  test "lo que no reconoce lo deja fuera en vez de adivinar" do
    [ "Nº", "OBSERVACIONES", "N° DE ORDEN", "", "   " ].each do |encabezado|
      assert_nil ColumnasDeMatricula.para(encabezado), "«#{encabezado}» no debería mapearse"
    end
  end

  # ── la definición única ───────────────────────────────────────────────────

  # Una columna que no está en la plantilla es una columna que el colegio nunca
  # va a llenar. Son la misma lista a propósito.
  test "la plantilla trae exactamente las columnas definidas" do
    hoja = leer(PlantillaDeMatricula.new.to_stream)

    assert_equal ColumnasDeMatricula.titulos, hoja.encabezados
  end

  test "las obligatorias son las que el importador no puede deducir" do
    assert_equal %i[nombre_completo seccion representante cedula_del_representante],
                 ColumnasDeMatricula.obligatorias.map(&:clave)
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
