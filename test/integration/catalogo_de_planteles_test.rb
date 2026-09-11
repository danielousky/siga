require "test_helper"

# El catálogo del MPPE SUGIERE el colegio mientras se escribe su nombre.
#
#     [ san jose                        ]
#     ┌───────────────────────────────────┐
#     │ U.E.P. COLEGIO SAN JOSÉ  PD012345 │
#     │ Distrito Capital · privado        │
#     └───────────────────────────────────┘
#              ↓ al elegir
#     se rellenan nombre y código, Y SE PUEDEN CAMBIAR
#
# ## ⚠️ Sugiere, no decide
#
# Daniel: *«es sugerencia, no verdad»*. Lo elegido llena los campos y ahí
# termina: se registra lo que quede escrito. Con eso el código DEA deja de ser
# un problema sin volver a pedirse —no se escribe, llega con el colegio— y quien
# no está en el catálogo se registra igual.
class CatalogoDePlantelesTest < ActionDispatch::IntegrationTest
  setup do
    PlantelOficial.create!(nombre: "U.E.P. COLEGIO SAN JOSÉ", dea_code: "PD01234567",
                           entidad_federal: "Distrito Capital")
    PlantelOficial.create!(nombre: "U.E.N. SAN JOSÉ OBRERO", dea_code: "OD07654321",
                           entidad_federal: "Miranda")
    PlantelOficial.create!(nombre: "COLEGIO SANTA ROSA", dea_code: "PD09999999",
                           entidad_federal: "Carabobo")
  end

  # ── Buscar ────────────────────────────────────────────────────────────────

  # ⚠️ PÚBLICA: quien busca su colegio todavía no tiene cuenta. Es el registro.
  test "las sugerencias se pueden pedir sin haber entrado" do
    get planteles_path(q: "san jose")

    assert_response :success
    assert_select ".sugerencia-nombre", /SAN JOSÉ/
  end

  # ⚠️ Sin acentos: en Venezuela eso deja fuera a media matrícula. «san jose»
  # tiene que encontrar a «SAN JOSÉ».
  test "encuentra sin acentos y sin mayúsculas" do
    get planteles_path(q: "san jose")

    assert_select ".sugerencia", 2
  end

  # ⚠️ Palabra por palabra, con AND: escribir MÁS tiene que acotar (`MOR-183`).
  test "escribir más acota, no deja de encontrar" do
    get planteles_path(q: "san jose miranda")

    assert_select ".sugerencia", 1
    assert_select ".sugerencia-nombre", /OBRERO/
  end

  # ⚠️ La PALABRA ENTERA va primero, y esto es lo que hace usable la lista.
  #
  # «san» es prefijo de «Sánchez», así que ningún filtro por prefijo puede
  # separarlos: buscar «san jose» traía «José Manuel Sánchez Ostos» y empujaba
  # fuera de las ocho sugerencias a los colegios que de verdad se llaman San
  # José. Lo que los separa no es filtrar más: es ORDENAR.
  test "el que casa la palabra entera va arriba del que solo la empieza" do
    PlantelOficial.create!(nombre: "C E I B JOSÉ MANUEL SÁNCHEZ OSTOS", dea_code: "OD09990405",
                           entidad_federal: "Apure")

    orden = PlantelOficial.buscar("san jose").map(&:nombre)
    sanchez = orden.index("C E I B JOSÉ MANUEL SÁNCHEZ OSTOS")

    # Los DOS que se llaman San José van antes que el que solo empieza igual.
    # ⚠️ Entre ellos desempata el alfabeto, y por eso no se afirma cuál va
    # primero: afirmarlo sería probar el orden alfabético, no la relevancia.
    assert_operator orden.index("U.E.P. COLEGIO SAN JOSÉ"), :<, sanchez
    assert_operator orden.index("U.E.N. SAN JOSÉ OBRERO"), :<, sanchez
  end

  test "el código y de dónde es viajan con cada sugerencia" do
    get planteles_path(q: "santa rosa")

    assert_select ".sugerencia-dea", "PD09999999"
    # La primera letra del código dice la dependencia, y sale gratis.
    assert_select ".sugerencia-detalle", /Carabobo · privado/
  end

  # ── No encontrarlo no bloquea nada ────────────────────────────────────────

  # ⚠️ El catálogo está incompleto A PROPÓSITO, y que lo esté no puede costarle
  # el registro a nadie. Es la misma regla de `DivisionPolitica::OTRO`.
  test "si no está, lo dice y no estorba" do
    get planteles_path(q: "colegio que no existe")

    assert_response :success
    assert_select ".sugerencia", 0
    assert_select ".sugerencias-vacio", /se registra igual/
  end

  test "un colegio que no está en el catálogo se registra igual" do
    assert_difference -> { Current.sin_aislamiento { School.count } }, 1 do
      post registrarse_path, params: {
        user: { first_name: "Rosa", last_name: "Mendoza", email: "rosa@fuera.test",
                password: "clave-larga-123", password_confirmation: "clave-larga-123" },
        school: { name: "U.E. QUE NO ESTÁ EN EL CATÁLOGO" },
        niveles: [ "primaria" ]
      }
    end
  end

  # ── El registro ───────────────────────────────────────────────────────────

  test "el registro busca el colegio mientras se escribe" do
    get registrarse_path

    assert_response :success
    assert_select "input[name='school[name]'][data-catalogo-de-planteles-target=nombre]"
    assert_select "turbo-frame#sugerencias_de_planteles"
  end

  # ⚠️ El código aparece SOLO si se eligió del catálogo. Quien no encuentra su
  # colegio no lo ve nunca: no tiene por qué buscarlo.
  test "el código DEA empieza escondido" do
    get registrarse_path

    assert_select "[data-catalogo-de-planteles-target=campoDelDea][hidden]"
  end

  # ⚠️ Y es un campo de texto normal, no un dato fijo: se corrige o se borra.
  # No viaja ningún «id del plantel» por detrás — se registra lo que se escriba.
  test "lo sugerido se puede cambiar" do
    get registrarse_path

    assert_select "input[type=text][name='school[dea_code]']"
    assert_select "input[name='school[plantel_oficial_id]']", count: 0
  end
end
