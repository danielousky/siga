require "test_helper"

# La escala literal A–E de primaria (MOR-129).
#
# Lo que este test tiene que sostener, además de los cortes: que **nada de esto
# tocó la base**. El literal se calcula al mostrarlo; lo guardado sigue siendo el
# entero del 1 al 20 del Art. 108.
class EscalaLiteralTest < ActiveSupport::TestCase
  # ══════════════════════════════════════════════════════════════════════════
  # Los cortes, tal como los dio Cyndi
  # ══════════════════════════════════════════════════════════════════════════

  # Uno por uno los veinte, sin dejar hueco. Un rango mal escrito no se nota en
  # el medio: se nota en el borde, y el borde de esta escala es la diferencia
  # entre aprobar y repetir el año.
  LITERALES = {
    20 => "A", 19 => "A",
    18 => "B", 17 => "B",
    16 => "C", 15 => "C", 14 => "C",
    13 => "D", 12 => "D", 11 => "D", 10 => "D",
    9 => "E", 8 => "E", 7 => "E", 6 => "E", 5 => "E",
    4 => "E", 3 => "E", 2 => "E", 1 => "E"
  }.freeze

  LITERALES.each do |nota, letra|
    test "#{nota} es #{letra}" do
      assert_equal letra, EscalaLiteral.para(nota)
    end
  end

  # El corte de aprobación cae en 10, **igual que en media general** (Art. 108).
  # No son dos sistemas: es el mismo umbral con otra etiqueta.
  test "la frontera de la reprobación coincide con la del Artículo 108" do
    assert_equal "E", EscalaLiteral.para(9),  "9 tiene que ser E: está por debajo de 10"
    assert_equal "D", EscalaLiteral.para(10), "10 aprueba, así que no puede ser E"

    assert_not EscalaLiteral.aprobado?(9)
    assert EscalaLiteral.aprobado?(10)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Sin nota no es cero, y tampoco es E
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Es la misma regla que se sostiene en las tres capas desde MOR-93: una materia
  # sin corregir no está reprobada, está sin corregir. Confundirlas acá le pone
  # una E —"reprobado"— a un alumno al que nadie evaluó todavía.

  test "sin nota no devuelve literal" do
    [nil, ""].each do |vacio|
      assert_nil EscalaLiteral.para(vacio), "#{vacio.inspect} no puede dar una letra"
      assert_nil EscalaLiteral.mostrar(vacio, escala: :literal)
    end
  end

  test "sin nota tampoco está aprobado ni reprobado" do
    assert_not EscalaLiteral.aprobado?(nil)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Cómo se escribe
  # ══════════════════════════════════════════════════════════════════════════

  test "en escala numérica se muestra el número pelado" do
    assert_equal "19", EscalaLiteral.mostrar(19, escala: :numerica)
    assert_equal "9",  EscalaLiteral.mostrar(9,  escala: :numerica)
  end

  # Las dos cosas juntas, y no es redundancia: el literal porque es lo que exige
  # el papel oficial, el número porque es lo que la familia entiende.
  test "en escala literal manda el número y la letra acompaña" do
    assert_equal "19 (A)", EscalaLiteral.mostrar(19, escala: :literal)
    assert_equal "9 (E)",  EscalaLiteral.mostrar(9,  escala: :literal)
  end

  test "la escala llega igual como símbolo o como texto" do
    assert_equal "19 (A)", EscalaLiteral.mostrar(19, escala: :literal)
    assert_equal "19 (A)", EscalaLiteral.mostrar(19, escala: "literal")
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El grado, que es de donde cuelga la escala
  # ══════════════════════════════════════════════════════════════════════════

  test "un grado nuevo de primaria nace con la escala literal" do
    escenario = escenario_academico(nivel: :primaria)

    con_el_colegio(escenario.colegio) do
      grado = Grade.create!(name: "3er Grado", level: :primaria)

      assert grado.escala_literal?, "un grado de primaria tiene que nacer por literal"
    end
  end

  test "un grado nuevo de media nace con la escala numérica" do
    escenario = escenario_academico(nivel: :primaria)

    con_el_colegio(escenario.colegio) do
      grado = Grade.create!(name: "4to Año", level: :secundaria)

      assert grado.escala_numerica?, "un grado de media tiene que nacer por número"
    end
  end

  # El caso que motivó ponerla en el grado y no en el colegio: Cyndi describe un
  # colegio con primaria Y bachillerato, y señala la incoherencia entre los dos
  # regímenes como un problema real. Con la escala en `School` ese colegio no se
  # podría representar.
  test "un mismo colegio sostiene las dos escalas a la vez" do
    escenario = escenario_academico(nivel: :primaria)

    con_el_colegio(escenario.colegio) do
      primaria = Grade.create!(name: "5to Grado", level: :primaria)
      media    = Grade.create!(name: "3er Año",   level: :secundaria)

      assert primaria.escala_literal?
      assert media.escala_numerica?
    end
  end

  # ⚠️ Acá había un test que afirmaba lo contrario: que la escala se podía
  # declarar contra el nivel, justificado en que la certificación EMG de media
  # general tiene dos áreas por literal.
  #
  # El propio ejemplo lo desmiente. Creaba esto:
  #
  #     Grade.create!(name: "Orientación y Convivencia", level: :secundaria, escala: :literal)
  #
  # «Orientación y Convivencia» **no es un grado: es una materia.** El caso que
  # justificaba la excepción estaba modelado como `Grade` cuando es un
  # `Subject`, y `escala` vive en el grado — así que declararlo literal habría
  # puesto en literal a Matemática también.
  #
  # Si esas áreas hacen falta algún día, la escala tiene que vivir en
  # `GradeSubject`. Al nivel donde el campo existe hoy, la respuesta es única.
  test "en secundaria la escala es siempre numérica" do
    escenario = escenario_academico(nivel: :primaria)

    con_el_colegio(escenario.colegio) do
      grado = Grade.new(name: "3er Año", level: :secundaria, escala: :literal)

      assert_not grado.valid?
      assert_match(/siempre es numérica/, grado.errors[:escala].to_sentence)
    end
  end

  # La primaria sí elige: hay colegios que califican por número desde primer
  # grado. Por eso solo se valida un lado.
  test "en primaria la escala se puede declarar contra el default" do
    escenario = escenario_academico(nivel: :primaria)

    con_el_colegio(escenario.colegio) do
      grado = Grade.create!(name: "4to Grado", level: :primaria, escala: :numerica)

      assert grado.escala_numerica?, "el nivel da el default, no la última palabra"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que NO cambió, que es la mitad del valor del issue
  # ══════════════════════════════════════════════════════════════════════════

  test "la base sigue guardando el entero del 1 al 20" do
    escenario = escenario_academico(nivel: :primaria)

    con_el_colegio(escenario.colegio) do
      escenario.grado.update!(escala: :literal)
      actividad = actividad(escenario, lapso: escenario.lapso(1), peso: 100, descripcion: "Examen")
      nota(actividad, escenario.alumno, 19)

      guardado = ActivityGrade.find_by(evaluation_activity: actividad, student: escenario.alumno)

      assert_equal 19, guardado.score,
                   "cambiar la escala no puede cambiar lo que se guarda"
    end
  end

  test "la base sigue rechazando una nota fuera de 1 a 20" do
    escenario = escenario_academico(nivel: :primaria)

    con_el_colegio(escenario.colegio) do
      escenario.grado.update!(escala: :literal)
      actividad = actividad(escenario, lapso: escenario.lapso(1), peso: 100, descripcion: "Examen")

      invalida = ActivityGrade.new(evaluation_activity: actividad, student: escenario.alumno, score: 25)

      assert_not invalida.valid?, "el CHECK del Art. 108 tiene que seguir en pie"
    end
  end
end
