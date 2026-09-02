require "test_helper"

# El andamiaje completo de un colegio nuevo (MOR-208).
#
# Lo que este test sostiene no es cada pieza —cada una tiene el suyo— sino que
# JUNTAS dejen un colegio que puede empezar a trabajar.
class SembrarElColegioTest < ActiveSupport::TestCase
  HOY = Date.new(2026, 9, 20)

  setup do
    @colegio = Current.sin_aislamiento do
      School.create!(name: "U.E. Andamiaje", dea_code: "PDAND#{Process.pid}",
                     entidad_federal: "Lara", municipio: "Iribarren")
    end
  end

  def sembrar(*niveles, hoy: HOY)
    con_el_colegio(@colegio) { SembrarElColegio.para(@colegio, niveles: niveles, hoy: hoy) }
  end

  # ⚠️ LA prueba de que el orden es correcto: las materias se cuelgan de los
  # grados, así que los grados van primero. Si `SembrarMaterias` no recargara la
  # asociación, acá quedarían materias creadas y CERO asignadas — un colegio con
  # pensum y sin poder cargar una nota, sin ningún error a la vista.
  test "las materias quedan colgadas de los grados recién creados" do
    resultado = sembrar(:primaria)

    assert_operator resultado.materias.asignaciones, :>, 0
    con_el_colegio(@colegio) do
      assert Grade.all.all? { |g| g.subjects.any? },
             "un grado sin materias no puede cargar una nota"
    end
  end

  test "un colegio de primaria queda listo para trabajar" do
    resultado = sembrar(:primaria)

    assert_equal 6, resultado.resumen[:grados]
    assert_equal 6, resultado.resumen[:materias]
    assert_equal 5, resultado.resumen[:anios]
    assert_equal 15, resultado.resumen[:lapsos]
  end

  # ⚠️ El resumen cuenta lo que HAY, no lo que se creó: la pantalla del paso 2
  # contesta «¿con qué cuenta su colegio?», no «¿qué acabo de hacer?».
  test "el resumen no cambia al correrlo de nuevo" do
    primera = sembrar(:primaria, :secundaria)
    segunda = sembrar(:primaria, :secundaria)

    assert_equal primera.resumen, segunda.resumen
    assert primera.algo_nuevo?
    assert_not segunda.algo_nuevo?, "la segunda pasada no creó nada"
  end

  # Y coincide con la base: no puede haber dos maneras de llegar al mismo número,
  # la que se muestra y la que es verdad.
  test "el resumen coincide con lo que hay en la base" do
    resultado = sembrar(:primaria, :secundaria)

    con_el_colegio(@colegio) do
      assert_equal Grade.count, resultado.resumen[:grados]
      assert_equal Subject.count, resultado.resumen[:materias]
      assert_equal AcademicPeriod.count, resultado.resumen[:anios]
      assert_equal EvaluationMoment.count, resultado.resumen[:lapsos]
    end
  end

  # ⚠️ Decisión de Daniel: el arranque no crea departamentos.
  test "no crea departamentos" do
    sembrar(:primaria, :secundaria)

    con_el_colegio(@colegio) { assert_equal 0, Department.count }
  end

  # Marcar Media Técnica siembra también el bachillerato: no hay sexto año sin
  # los cinco anteriores.
  test "la media técnica arrastra el bachillerato" do
    sembrar(:media_tecnica)

    con_el_colegio(@colegio) do
      assert_equal 6, Grade.count, "los cinco años más el sexto"
      assert Grade.exists?(name: "1er Año")
    end
  end

  # Un preescolar no recibe materias, pero sí sus grados y sus años.
  test "un preescolar queda con grados y años, sin materias" do
    resultado = sembrar(:preescolar)

    assert_equal 3, resultado.resumen[:grados]
    assert_equal 0, resultado.resumen[:materias]
    assert_equal 5, resultado.resumen[:anios]
  end

  # ⚠️ Si algo falla, no puede quedar media siembra: un colegio con grados y sin
  # años confunde más que uno vacío, porque nadie sabe qué le falta.
  test "si algo falla no queda nada a medias" do
    con_el_colegio(@colegio) do
      # Los años se siembran ÚLTIMOS: si revientan ahí, los grados y las materias
      # ya se escribieron y tienen que deshacerse con ellos.
      # ⚠️ Se reemplaza el método a mano y se restaura en el `ensure`: este
      # proyecto no carga `minitest/mock`, y agregarlo por un solo test es traer
      # una dependencia para no escribir cuatro líneas.
      original = SembrarAniosEscolares.method(:para)
      SembrarAniosEscolares.define_singleton_method(:para) do |*|
        raise ActiveRecord::StatementInvalid, "falla simulada"
      end

      begin
        assert_raises(ActiveRecord::StatementInvalid) do
          SembrarElColegio.para(@colegio, niveles: [ :primaria ], hoy: HOY)
        end
      ensure
        SembrarAniosEscolares.define_singleton_method(:para, original)
      end

      assert_equal 0, Grade.count, "los grados tienen que haberse deshecho con el resto"
      assert_equal 0, Subject.count
    end
  end
end
