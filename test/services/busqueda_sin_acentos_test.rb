require "test_helper"

# El buscador que encuentra a López escribiendo "lopez".
#
# Ver MOR-137.
class BusquedaSinAcentosTest < ActiveSupport::TestCase
  # ══════════════════════════════════════════════════════════════════════════
  # El mapa de acentos
  # ══════════════════════════════════════════════════════════════════════════

  # `translate()` empareja carácter por carácter y **descarta en silencio** lo
  # que sobre del origen. Un mapa desparejo no da error: da resultados raros en
  # las últimas letras, que son justo las menos probadas.
  test "los dos lados del mapa miden lo mismo" do
    assert_equal BusquedaSinAcentos::ACENTOS.length,
                 BusquedaSinAcentos::LLANAS.length,
                 "el mapa quedó desparejo: translate() descartaría letras sin avisar"
  end

  # Postgres tiene que contar CARACTERES, no bytes: en UTF-8 cada vocal acentuada
  # ocupa dos bytes, y si contara bytes el mapa quedaría corrido.
  test "postgres cuenta caracteres y no bytes" do
    largo = ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql(["SELECT length(?)", BusquedaSinAcentos::ACENTOS])
    )

    assert_equal BusquedaSinAcentos::ACENTOS.length, largo
  end

  test "aplana los acentos que se ven en un apellido venezolano" do
    {
      "López" => "lopez", "PÉREZ" => "perez", "Guzmán" => "guzman",
      "Núñez" => "nunez", "Díaz" => "diaz", "Gonçalves" => "goncalves",
      "Müller" => "muller", "Ramos" => "ramos"
    }.each do |escrito, esperado|
      assert_equal esperado, aplanar(escrito), "#{escrito} no se aplanó como se esperaba"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La condición
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ Hay UN bind POR PALABRA desde que la búsqueda es palabra por palabra
  # (MOR-183): «López Guzmán» son dos condiciones unidas por AND, no un término
  # entero contra cada columna. Lo que no cambió es lo que este test protege:
  # nada del término llega al SQL interpolado.
  test "el término va por bind y nunca interpolado" do
    sql, binds = BusquedaSinAcentos.condicion(%w[users.last_name], "'; DROP TABLE users; --")

    assert_not_includes sql, "DROP"
    assert_includes binds.values.join, "DROP"
  end

  # Cada palabra tiene que aparecer en ALGÚN campo, y todas a la vez: escribir
  # más ACOTA, que es lo que uno espera de un buscador.
  test "cada palabra es su propia condición, unidas por AND" do
    sql, binds = BusquedaSinAcentos.condicion(%w[users.last_name users.second_last_name], "López Guzmán")

    assert_equal 2, binds.size
    assert_includes sql, " AND "
    assert_equal [ "%López%", "%Guzmán%" ], binds.values
  end

  # Un término vacío no filtra nada, y sobre todo no revienta.
  test "sin término, la condición no descarta a nadie" do
    sql, = BusquedaSinAcentos.condicion(%w[users.last_name], "   ")

    assert_equal "1=1", sql
  end

  # Los campos SÍ se interpolan, así que tienen que parecer nombres de columna.
  # Hoy salen de constantes del código; el día que alguien los tome de un
  # parámetro, esto rompe antes de llegar a la base.
  test "un campo que no parece una columna no se interpola" do
    ["users.name; DROP TABLE users", "(SELECT 1)", "users.name OR 1=1"].each do |sucio|
      assert_raises(BusquedaSinAcentos::CampoInvalido, "#{sucio.inspect} pasó la validación") do
        BusquedaSinAcentos.condicion([sucio], "algo")
      end
    end
  end

  test "sin campos donde buscar, avisa" do
    assert_raises(ArgumentError) { BusquedaSinAcentos.condicion([], "algo") }
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contra la base, que es donde importa
  # ══════════════════════════════════════════════════════════════════════════

  test "encuentra el apellido con tilde escribiéndolo sin tilde" do
    escenario = escenario_academico

    con_el_colegio(escenario.colegio) do
      alumna = User.create!(first_name: "Ana", last_name: "López", password: "123123",
                            email: "ana.lopez@acentos.test", document: "V-1")
      Student.create!(user: alumna, school: escenario.colegio, school_card: "AC-1")

      %w[lopez López LOPEZ Lopez lópez].each do |escrito|
        encontrados = Student.joins(:user)
                             .where(*BusquedaSinAcentos.condicion(%w[users.last_name], escrito))

        assert_equal 1, encontrados.count, "buscando #{escrito.inspect} no apareció López"
      end
    end
  end

  # El caso que hacía traicionero al bug: los apellidos SIN tilde siempre
  # funcionaron, así que probar con "Ramos" daba una falsa tranquilidad.
  test "el apellido sin tilde sigue funcionando igual" do
    escenario = escenario_academico

    con_el_colegio(escenario.colegio) do
      alumno = User.create!(first_name: "Beto", last_name: "Ramos", password: "123123",
                            email: "beto.ramos@acentos.test", document: "V-2")
      Student.create!(user: alumno, school: escenario.colegio, school_card: "AC-2")

      %w[ramos Ramos RAMOS].each do |escrito|
        encontrados = Student.joins(:user)
                             .where(*BusquedaSinAcentos.condicion(%w[users.last_name], escrito))

        assert_equal 1, encontrados.count, "buscando #{escrito.inspect} no apareció Ramos"
      end
    end
  end

  # Lo que se normaliza es la COMPARACIÓN. El apellido de esa persona lleva
  # tilde, y así tiene que salir en el boletín y en la certificación del MPPE.
  test "lo guardado conserva sus tildes" do
    escenario = escenario_academico

    con_el_colegio(escenario.colegio) do
      alumna = User.create!(first_name: "Ana", last_name: "Núñez", password: "123123",
                            email: "ana.nunez@acentos.test", document: "V-3")
      Student.create!(user: alumna, school: escenario.colegio, school_card: "AC-3")

      encontrada = Student.joins(:user)
                          .where(*BusquedaSinAcentos.condicion(%w[users.last_name], "nunez"))
                          .first

      assert_equal "NÚÑEZ", encontrada.user.last_name,
                   "la búsqueda no puede tocar el dato guardado"
    end
  end

  private

  def aplanar(palabra)
    ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql(
        ["SELECT translate(lower(?), ?, ?)",
         palabra, BusquedaSinAcentos::ACENTOS, BusquedaSinAcentos::LLANAS]
      )
    )
  end
end
