require "test_helper"

# Los catorce grados oficiales, sembrados de una vez (MOR-153).
class SembrarGradosTest < ActiveSupport::TestCase
  # ⚠️ Un colegio VACÍO, no el escenario académico completo.
  #
  # `escenario_academico` ya crea un «1er Año» con su sección, así que todo
  # conteo exacto —«creó seis»— daría siete y el test mentiría sobre lo que pasó.
  # Acá lo que se prueba es el arranque desde cero, que es el caso real: un
  # colegio recién dado de alta.
  setup do
    @colegio = School.create!(name: "Colegio del Catálogo", dea_code: "CAT-#{Process.pid}",
                              location: "Caracas")
  end

  test "marcar los tres niveles crea los catorce grados con su nivel correcto" do
    con_el_colegio(@colegio) do
      SembrarGrados.para(@colegio, niveles: GradoOficial::NIVELES)

      grados = @colegio.grades.en_orden.to_a

      assert_equal GradoOficial.nombres, grados.map(&:name),
                   "los grados no salieron en el orden en que un niño los cursa"
      assert_equal 3, grados.count(&:preescolar?)
      assert_equal 6, grados.count(&:primaria?)
      assert_equal 5, grados.count(&:secundaria?)
    end
  end

  # La palabra distingue el nivel, y de ahí sale la escala del boletín.
  test "el nivel y la escala salen del NOMBRE, no de un desplegable" do
    con_el_colegio(@colegio) do
      SembrarGrados.para(@colegio, niveles: GradoOficial::NIVELES)

      assert_equal "primaria",   @colegio.grades.find_by(name: "4to Grado").level
      assert_equal "secundaria", @colegio.grades.find_by(name: "4to Año").level

      assert @colegio.grades.find_by(name: "2do Nivel").escala_literal?,
             "en preescolar la calificación es cualitativa: un maternal con notas " \
             "del 1 al 20 es indefendible delante de una madre"
      assert @colegio.grades.find_by(name: "3er Año").escala_numerica?
    end
  end

  # ⚠️ Un colegio que dicta primaria agrega bachillerato dos años después y
  # vuelve a pasar por acá. Lo que ya existe tiene alumnos adentro.
  test "sembrar dos veces no duplica ni toca lo que ya existe" do
    con_el_colegio(@colegio) do
      primera = SembrarGrados.para(@colegio, niveles: [ :primaria ])
      assert_equal 6, primera.creados.size

      segunda = SembrarGrados.para(@colegio, niveles: [ :primaria, :secundaria ])

      assert_equal 6, segunda.ya_estaban.size, "volvió a crear los de primaria"
      assert_equal 5, segunda.creados.size
      assert_equal 11, @colegio.grades.where(name: GradoOficial.nombres).count
    end
  end

  # Un grado cargado a mano o traído por una importación, escrito distinto, no
  # puede terminar duplicado.
  test "un grado ya cargado con otra escritura no se duplica" do
    con_el_colegio(@colegio) do
      Grade.create!(school: @colegio, name: "1ER AÑO")

      resultado = SembrarGrados.para(@colegio, niveles: [ :secundaria ])

      assert_equal 4, resultado.creados.size
      assert_equal 1, resultado.ya_estaban.size
      assert_equal 1, @colegio.grades.where("lower(name) LIKE '1%año'").count
    end
  end

  # Desmarcar un nivel NO puede borrar grados: tienen secciones y alumnos.
  test "sembrar sin un nivel no borra los grados de ese nivel" do
    con_el_colegio(@colegio) do
      SembrarGrados.para(@colegio, niveles: [ :primaria, :secundaria ])
      antes = @colegio.grades.count

      SembrarGrados.para(@colegio, niveles: [ :secundaria ])

      assert_equal antes, @colegio.grades.count,
                   "desmarcar un nivel borró grados: podían tener alumnos adentro"
    end
  end

  # El colegio no declara qué dicta: se deduce de lo que tiene.
  # El colegio no declara qué dicta: se deduce de lo que tiene cargado.
  test "los niveles del colegio se deducen de sus grados" do
    con_el_colegio(@colegio) do
      assert_empty @colegio.niveles, "un colegio sin grados no dicta nada todavía"

      SembrarGrados.para(@colegio, niveles: [ :secundaria, :preescolar ])

      assert_equal [ :preescolar, :secundaria ], @colegio.niveles,
                   "los niveles salen en orden pedagógico, no en el que se pidieron"
      assert @colegio.dicta?(:preescolar)
      assert_not @colegio.dicta?(:primaria)
    end
  end
end

# Las secciones van A, B, C — «no es ley pero casi» (MOR-153).
class SiguienteLetraDeSeccionTest < ActiveSupport::TestCase
  setup { @esc = escenario_academico(nombre: "Colegio de las Letras") }

  test "la primera sección de un grado es la A" do
    con_el_colegio(@esc.colegio) do
      grado = Grade.create!(school: @esc.colegio, name: "3er Grado")

      assert_equal "A", Section.siguiente_letra(grade: grado, academic_period: @esc.periodo)
    end
  end

  test "después de la A viene la B, y después de la B la C" do
    con_el_colegio(@esc.colegio) do
      grado = Grade.create!(school: @esc.colegio, name: "3er Grado")
      Section.create!(grade: grado, academic_period: @esc.periodo, name: "A", capacity: 30)
      assert_equal "B", Section.siguiente_letra(grade: grado, academic_period: @esc.periodo)

      Section.create!(grade: grado, academic_period: @esc.periodo, name: "B", capacity: 30)
      assert_equal "C", Section.siguiente_letra(grade: grado, academic_period: @esc.periodo)
    end
  end

  # El «casi» de «no es ley pero casi»: un colegio con sección «Única» no puede
  # recibir una sugerencia deducida de esa palabra.
  test "una sección con nombre propio no confunde la sugerencia" do
    con_el_colegio(@esc.colegio) do
      grado = Grade.create!(school: @esc.colegio, name: "3er Grado")
      Section.create!(grade: grado, academic_period: @esc.periodo, name: "Única", capacity: 30)

      assert_equal "A", Section.siguiente_letra(grade: grado, academic_period: @esc.periodo)
    end
  end

  # La sugerencia es por grado Y por año escolar: el 3er Grado de este año
  # empieza en A aunque el del año pasado haya llegado a la D.
  test "cada año escolar empieza otra vez en la A" do
    con_el_colegio(@esc.colegio) do
      viejo = ano_escolar_viejo(@esc, nombre: "2020-2021")
      grado = Grade.create!(school: @esc.colegio, name: "3er Grado")
      Section.create!(grade: grado, academic_period: viejo, name: "A", capacity: 30)
      Section.create!(grade: grado, academic_period: viejo, name: "B", capacity: 30)

      assert_equal "C", Section.siguiente_letra(grade: grado, academic_period: viejo)
      assert_equal "A", Section.siguiente_letra(grade: grado, academic_period: @esc.periodo)
    end
  end
end

# La Educación Media Técnica son SEIS años (MOR-153).
class MediaTecnicaTest < ActiveSupport::TestCase
  setup do
    @colegio = School.create!(name: "Técnico Industrial", dea_code: "TEC-#{Process.pid}",
                              location: "Valencia")
  end

  # ⚠️ Media Técnica NO es un nivel paralelo: aporta UN grado, no seis. Un
  # colegio técnico dicta 1er a 5to Año igual que cualquier bachillerato.
  # Modelarla completa duplicaría «1er Año» y chocaría contra el índice único.
  test "marcar media técnica siembra los seis años, no uno suelto" do
    con_el_colegio(@colegio) do
      resultado = SembrarGrados.para(@colegio, niveles: [ :media_tecnica ])

      assert_equal 6, resultado.creados.size,
                   "sembró un 6to Año sin los cinco anteriores"
      assert_equal [ "1er Año", "2do Año", "3er Año", "4to Año", "5to Año", "6to Año" ],
                   @colegio.grades.en_orden.map(&:name)
    end
  end

  test "el sexto año es media técnica y los cinco primeros bachillerato" do
    con_el_colegio(@colegio) do
      SembrarGrados.para(@colegio, niveles: [ :media_tecnica ])

      assert_equal "media_tecnica", @colegio.grades.find_by(name: "6to Año").level
      assert_equal "secundaria",    @colegio.grades.find_by(name: "5to Año").level
      assert_equal [ :secundaria, :media_tecnica ], @colegio.niveles
    end
  end

  # ⚠️ Los siete lugares que preguntaban `secundaria?` se habrían quedado ciegos
  # ante el sexto año. El peor en silencio: la 31059 es el documento de la
  # educación MEDIA, y un Técnico Medio no habría podido pedirla.
  test "el sexto año es media, y por eso se califica del 1 al 20" do
    con_el_colegio(@colegio) do
      SembrarGrados.para(@colegio, niveles: [ :media_tecnica ])
      sexto = @colegio.grades.find_by!(name: "6to Año")

      assert sexto.media?, "un Técnico Medio no podría pedir su certificación 31059"
      assert sexto.escala_numerica?
      assert_not sexto.update(escala: :literal),
                 "aceptó calificar por letras un año de bachillerato"
    end
  end

  # Un bachillerato general NO recibe el sexto año.
  test "marcar solo bachillerato deja el colegio en cinco años" do
    con_el_colegio(@colegio) do
      SembrarGrados.para(@colegio, niveles: [ :secundaria ])

      assert_equal 5, @colegio.grades.count
      assert_nil @colegio.grades.find_by(name: "6to Año"),
                 "a un bachillerato general le apareció un sexto año que no dicta"
    end
  end
end
