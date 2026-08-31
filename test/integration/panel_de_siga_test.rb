require "test_helper"

# El panel de la plataforma tiene que dejar HACER cosas (MOR-157).
#
# ## El error que motivó esto, y por qué no lo atrapaba nada
#
# El botón «Dar de alta» se dibujaba como el TEXTO `/siga/colegios/new` y
# enlazaba a la página actual con la clase convertida en query string. Estaba
# escrito así:
#
#     = link_to new_siga_colegio_path, class: "btn btn-primary" if algo do
#
# El `if` modificador se lleva el `do`: Ruby lo aplica al `link_to`, el bloque
# queda huérfano, y `link_to` toma su primer argumento como el texto del enlace
# en vez del destino.
#
# **No explota.** La página devuelve 200, el HTML es válido, y ningún test que
# mire códigos de respuesta lo nota. Solo se ve mirando el botón — y dejó a
# Daniel sin poder dar de alta un colegio.
class PanelDeSigaTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    @fundador = Current.sin_aislamiento do
      persona = User.create!(first_name: "Equipo", last_name: "Siga",
                             email: "fundador@siga.test", password: "123123",
                             document: "V-10101010", document_type: :cedula_v)
      SigaStaff.create!(user: persona, role: :fundador)
      persona
    end
    sign_in @fundador
  end

  # ⚠️ El enlace tiene que LLEVAR a algún lado, no solo existir.
  test "el botón de dar de alta apunta al formulario, no a la página actual" do
    [ siga_root_path, siga_colegios_path ].each do |ruta|
      get ruta

      assert_response :success
      enlace = css_select("a[href='#{new_siga_colegio_path}']").first

      assert enlace, "#{ruta} no tiene ningún enlace a #{new_siga_colegio_path}"
      assert_no_match(%r{/siga/colegios/new}, enlace.text,
                      "el enlace muestra la RUTA como texto: el `if` modificador " \
                      "se llevó el bloque y `link_to` la tomó como etiqueta")
    end
  end

  # La consecuencia del mismo error, vista desde el otro lado: si el `do` queda
  # huérfano, la clase termina en la query string del destino.
  test "ningún enlace del panel lleva sus clases CSS en la URL" do
    [ siga_root_path, siga_colegios_path, siga_solicitudes_path, siga_cartera_index_path ].each do |ruta|
      get ruta

      sucios = css_select("a").map { |a| a["href"] }.compact.select { |h| h.include?("class=") }

      assert_empty sucios,
                   "#{ruta} tiene enlaces con la clase metida en la URL: #{sucios.join(', ')}"
    end
  end

  # Y la prueba de que se puede hacer el trabajo, no solo verlo.
  test "se da de alta un colegio con su director y su ubicación" do
    assert_difference -> { Current.sin_aislamiento { School.count } }, 1 do
      post siga_colegios_path, params: {
        school: { name: "U.E. Nueva", dea_code: "PD00777", location: "Barquisimeto", entidad_federal: "Lara",
                  municipio: "Iribarren", parroquia: "Catedral",
                  direccion: "Av. Lara", telefono: "0251-555-9988" },
        director: { first_name: "Rosa", last_name: "Mendoza", email: "rosa@nueva.test",
                    document: "V-19876543", document_type: "cedula_v" }
      }
    end

    colegio = Current.sin_aislamiento { School.find_by!(dea_code: "PD00777") }

    assert_redirected_to siga_colegio_path(colegio)
    assert_equal "Lara", colegio.entidad_federal
    assert_equal "Catedral", colegio.parroquia
    assert_equal "0251-555-9988", colegio.telefono
    assert Current.sin_aislamiento { Admin.exists?(school_id: colegio.id) },
           "el colegio quedó sin director: nadie puede entrar"
  end

  # ⚠️ El catálogo de municipios está INCOMPLETO y se escribió sin fuente
  # oficial. No puede impedirle a un colegio registrarse: uno que no puede
  # registrarse no vuelve. Por eso cada desplegable termina en «No está en la
  # lista» y lo escrito a mano gana.
  test "un municipio que no está en el catálogo se guarda igual" do
    post siga_colegios_path, params: {
      school: { name: "U.E. Del Interior", dea_code: "PD00888", location: "Un pueblo", entidad_federal: "Lara",
                municipio: DivisionPolitica::OTRO, municipio_libre: "Un Municipio Nuevo",
                parroquia: DivisionPolitica::OTRO, parroquia_libre: "Una Parroquia Nueva" },
      director: { first_name: "Ana", last_name: "Suárez", email: "ana@interior.test",
                  document: "V-11223344", document_type: "cedula_v" }
    }

    colegio = Current.sin_aislamiento { School.find_by!(dea_code: "PD00888") }

    assert_equal "Un Municipio Nuevo", colegio.municipio
    assert_equal "Una Parroquia Nueva", colegio.parroquia
  end

  # Lo que NUNCA puede pasar: que el centinela llegue a la base y un documento
  # del MPPE salga diciendo que el colegio queda en «__otro__».
  test "el centinela del desplegable no se guarda nunca" do
    post siga_colegios_path, params: {
      school: { name: "U.E. Sin Municipio", dea_code: "PD00889", location: "X", entidad_federal: "Lara",
                municipio: DivisionPolitica::OTRO, municipio_libre: "" },
      director: { first_name: "Luis", last_name: "Pérez", email: "luis@sinmun.test",
                  document: "V-11223355", document_type: "cedula_v" }
    }

    colegio = Current.sin_aislamiento { School.find_by!(dea_code: "PD00889") }

    assert_nil colegio.municipio,
               "se guardó «#{DivisionPolitica::OTRO}» como si fuera el nombre de un municipio"
  end

  # ⚠️ Los campos existían en la base desde los documentos del MPPE y NINGÚN
  # formulario los pedía: había datos obligatorios que ningún humano podía
  # cargar, y los documentos salían incompletos.
  test "los dos formularios del colegio piden la ubicación completa" do
    get new_siga_colegio_path
    %w[entidad_federal municipio parroquia direccion telefono].each do |campo|
      assert_select "[name='school[#{campo}]']", { minimum: 1 },
                    "el alta de SIGA no pide #{campo}"
    end

    sign_out @fundador
    sign_in @a.director
    get colegio_path
    %w[entidad_federal municipio parroquia direccion telefono].each do |campo|
      assert_select "[name='school[#{campo}]']", { minimum: 1 },
                    "la ficha del colegio no pide #{campo}"
    end
  end
end
