require "test_helper"

# La División Político Territorial, ahora del INE y no de memoria.
#
# ## ⚠️ Lo que este catálogo decía de sí mismo
#
# *«Lo que hay acá se escribió de memoria y no se contrastó contra una fuente
# oficial… Antes de dar esto por bueno: bajar el catálogo del INE y reemplazar
# el hash. La estructura no cambia; los datos sí.»*
#
# Es exactamente lo que se hizo: los códigos `EEMMPP` del INE, bajados de su
# servicio público. La estructura no cambió, así que ninguna pantalla se tocó.
class DivisionPoliticaOficialTest < ActiveSupport::TestCase
  test "están los 24 estados, sus municipios y sus parroquias" do
    # Venezuela tiene 335 municipios y ~1.150 parroquias.
    assert_operator DivisionPolitica::MUNICIPIOS.values.sum(&:size), :>=, 330
    assert_operator DivisionPolitica::MUNICIPIOS.values.flat_map(&:values).sum(&:size), :>=, 1_100
  end

  # ⚠️ Los nombres se guardan con sus acentos: salen IMPRESOS en los documentos
  # del MPPE. La capa del INE los trae sin acentuar —«Andres Bello», «Brion»— y
  # la ortografía se recuperó del catálogo anterior.
  test "los nombres conservan sus acentos" do
    assert_includes DivisionPolitica.municipios_de("Miranda"), "Andrés Bello"
    assert_includes DivisionPolitica.municipios_de("Miranda"), "Brión"
  end

  test "los nombres de estado casan con los que ofrece el selector" do
    fuera = DivisionPolitica::MUNICIPIOS.keys - EntidadFederal::TODAS

    assert_empty fuera, "estados que el selector no ofrece: #{fuera.join(', ')}"
  end

  # ── El código DEA lleva la ubicación adentro ──────────────────────────────
  #
  #     O D 0489 02 03
  #             │  │  └── municipio dentro del estado ── «03» = Atures
  #             │  └───── entidad federal (código INE) ── «02» = Amazonas
  #             └──────── el registro ante la zona educativa

  test "del código DEA sale el estado y el municipio" do
    assert_equal({ entidad: "Amazonas", municipio: "Atures" },
                 DivisionPolitica.ubicacion_del_codigo("OD04890203"))
    assert_equal({ entidad: "Trujillo", municipio: "Valera" },
                 DivisionPolitica.ubicacion_del_codigo("OD09512120"))
  end

  # ⚠️ Distrito Capital y La Guaira tienen UN SOLO municipio, y el MPPE usa ahí
  # códigos 02, 03, 04, 05 que son subdivisiones suyas. Todos caen en el único
  # que hay, y eso no es una suposición: es aritmética.
  test "un estado de un solo municipio resuelve cualquiera de sus códigos" do
    %w[PD05150101 PD05150102 PD05150105].each do |codigo|
      assert_equal({ entidad: "Distrito Capital", municipio: "Libertador" },
                   DivisionPolitica.ubicacion_del_codigo(codigo))
    end
  end

  # ⚠️ NUNCA adivina. Un municipio equivocado que se ve plausible es peor que
  # ninguno: nadie corrige lo que no nota, y ese dato sale impreso.
  test "un código que no corresponde a nada devuelve nil" do
    assert_nil DivisionPolitica.ubicacion_del_codigo("XX999999")
    assert_nil DivisionPolitica.ubicacion_del_codigo("")
    assert_nil DivisionPolitica.ubicacion_del_codigo(nil)
  end

  # ⚠️ Y un código A MEDIO ESCRIBIR tampoco: leyendo los cuatro últimos de
  # «PD0515» sale Aragua/Urdaneta, que no tiene nada que ver con lo que se
  # estaba escribiendo.
  test "un código incompleto no resuelve nada" do
    assert_nil DivisionPolitica.ubicacion_del_codigo("PD0515")
  end
end
