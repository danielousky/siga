require "test_helper"

# El colegio de muestra (spec `docs/specs/del-registro-al-cobro.md`, § 4.3).
#
#     EN LA MUESTRA                          EN EL SITIO DE VERDAD
#     la portada son tres puertas            la portada es la portada
#     un clic abre la sesión, sin clave      entrar sin clave NO EXISTE: 404
#     el registro manda al sitio de verdad   el registro registra
#     nada se indexa, y no sale correo       todo como siempre
#
# La mitad de la derecha importa tanto como la de la izquierda: un endpoint que
# abre una sesión sin contraseña es lo peor que podría existir en el sistema de
# un colegio, y lo único que lo separa de él es una variable de entorno.
class ColegioDeMuestraTest < ActionDispatch::IntegrationTest
  include ColegioDeMuestra

  setup do
    @a, @b = dos_colegios_completos
    montar_la_muestra(@a, @b)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Fuera de la muestra: no existe
  # ══════════════════════════════════════════════════════════════════════════

  test "fuera de la muestra, entrar con un clic no existe" do
    post entrar_a_la_muestra_path(rol: "director")

    assert_response :not_found
    get dashboards_administrador_path
    assert_redirected_to new_user_session_path, "nadie quedó con la sesión abierta"
  end

  # Las cuentas existen —en desarrollo las siembran los seeds— y aun así no abre.
  test "ni aunque la cuenta exista y el rol sea el correcto" do
    assert Muestra.usuario_de(Muestra.cuenta("director")), "el escenario tiene que tener la puerta montada"

    post entrar_a_la_muestra_path(rol: "director")

    assert_response :not_found
  end

  test "fuera de la muestra, /muestra no existe si nadie dijo dónde vive" do
    get muestra_path

    assert_response :not_found
  end

  # Dónde vive es un ajuste de `/siga` (`Setup`), y no la variable
  # `SIGA_MUESTRA_URL` que fue hasta el 12 de octubre de 2026.
  test "y si se dijo dónde vive, manda allá" do
    Setup.create!(nombre: "url_de_la_muestra", valor: "https://demo.sigaeducando.com")

    get muestra_path

    assert_redirected_to "https://demo.sigaeducando.com"
  end

  test "fuera de la muestra, la portada sigue siendo la portada" do
    get root_path

    assert_response :success
    assert_select ".portada-tesis", text: /El colegio que usted imagina/
    assert_select ".muestra-puerta", count: 0
  end

  # ══════════════════════════════════════════════════════════════════════════
  # En la muestra: las puertas
  # ══════════════════════════════════════════════════════════════════════════

  test "en la muestra, la portada son las puertas" do
    en_la_muestra { get root_path }

    assert_response :success
    assert_select ".muestra-puerta", count: Muestra::CUENTAS.size
    Muestra::CUENTAS.each do |cuenta|
      assert_select ".muestra-puerta-correo", text: cuenta.correo
      assert_select "form[action=?]", entrar_a_la_muestra_path(rol: cuenta.clave)
    end
    assert_select ".muestra-clave strong", text: Muestra::CLAVE
  end

  test "las otras miradas también están, cada una con su entrada" do
    en_la_muestra { get root_path }

    assert_select ".muestra-otra", count: Muestra::OTRAS.size
    Muestra::OTRAS.each { |cuenta| assert_select "form[action=?]", entrar_a_la_muestra_path(rol: cuenta.clave) }
  end

  # La muestra invita a registrar el colegio en el sitio de verdad, no aquí.
  test "las puertas mandan a registrarse al sitio de verdad" do
    en_la_muestra { get root_path }

    assert_select "a[href=?]", Muestra.url_del_registro, minimum: 2
    assert_select "a[href=?]", new_user_registration_path, count: 0
  end

  test "un clic abre la sesión del director, sin pedir la clave" do
    en_la_muestra do
      post entrar_a_la_muestra_path(rol: "director")
      assert_redirected_to root_path

      follow_redirect!
      assert_redirected_to dashboards_administrador_path

      follow_redirect!
      assert_response :success
      assert_select ".aviso-muestra", text: /Colegio de muestra/
    end
  end

  test "y la del profesor lleva a su panel" do
    en_la_muestra do
      post entrar_a_la_muestra_path(rol: "profesor")
      follow_redirect!

      assert_redirected_to dashboards_profesor_path
    end
  end

  test "entrar deja el rastro en la bitácora, como cualquier entrada" do
    en_la_muestra { post entrar_a_la_muestra_path(rol: "director") }

    con_el_colegio(@a.colegio) do
      entrada = ActivityLog.where(action: "login").order(:id).last

      assert_equal @a.director, entrada&.user
    end
  end

  # No se entra «como quien uno diga»: solo por las puertas de la lista.
  test "una puerta que no está en la lista no abre nada" do
    en_la_muestra do
      post entrar_a_la_muestra_path(rol: "fundador")

      assert_redirected_to muestra_path
      get dashboards_administrador_path
      assert_redirected_to new_user_session_path
    end
  end

  test "ni se entra pasando el correo de otra persona" do
    en_la_muestra do
      post entrar_a_la_muestra_path(rol: @b.director.email)

      assert_redirected_to muestra_path
    end
  end

  # ⚠️ El tercer cerrojo: ESE rol en ESE colegio. Una cuenta con el correo de la
  # puerta pero sin el rol —o en otro colegio— no es la de la muestra.
  test "una cuenta con el correo de la puerta pero sin su rol no abre" do
    con_el_colegio(@a.colegio) { @a.registro_de_admin.delete }

    en_la_muestra do
      post entrar_a_la_muestra_path(rol: "director")

      assert_redirected_to muestra_path
      follow_redirect!
      assert_select ".alert", text: /no está disponible/
    end
  end

  test "ni si el colegio no es el de la muestra" do
    Current.sin_aislamiento { @a.colegio.update_columns(dea_code: "OTRO001") }

    en_la_muestra do
      post entrar_a_la_muestra_path(rol: "director")

      assert_redirected_to muestra_path
    end
  end

  # Cambiar de rol es salir y volver a entrar: el segundo no hereda al primero.
  test "entrar por otra puerta cambia de persona" do
    en_la_muestra do
      post entrar_a_la_muestra_path(rol: "director")
      post entrar_a_la_muestra_path(rol: "profesor")
      follow_redirect!

      assert_redirected_to dashboards_profesor_path
      get dashboards_administrador_path
      assert_response :redirect, "el profesor no hereda el panel del director"
    end
  end

  test "con la sesión abierta, /muestra lleva al panel y no dibuja las puertas adentro" do
    en_la_muestra do
      post entrar_a_la_muestra_path(rol: "director")
      get muestra_path

      assert_redirected_to root_path
    end
  end

  test "«cambiar de rol» cierra la sesión y deja en las puertas" do
    en_la_muestra do
      post entrar_a_la_muestra_path(rol: "director")
      get dashboards_administrador_path
      assert_select "form[action=?] button", destroy_user_session_path, text: "Cambiar de rol"

      delete destroy_user_session_path
      follow_redirect!

      assert_select ".muestra-puerta", count: Muestra::CUENTAS.size
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # En la muestra: lo que NO pasa
  # ══════════════════════════════════════════════════════════════════════════

  # Su base se borra cada noche: el colegio que alguien creara amanecería borrado.
  test "en la muestra no se registra nadie: va al sitio de verdad" do
    en_la_muestra do
      get new_user_registration_path
      assert_redirected_to Muestra.url_del_registro

      assert_no_difference -> { cantidad(School) } do
        # El alta no tiene nombre de ruta: es un POST a la misma dirección del formulario.
        post new_user_registration_path, params: { user: { email: "alguien@colegio.test" } }
      end
      assert_redirected_to Muestra.url_del_registro
    end
  end

  test "la muestra no se indexa: ni una página" do
    en_la_muestra do
      get robots_path
      assert_equal "User-agent: *\nDisallow: /\n", response.body

      get root_path
      assert_select "meta[name=robots][content=?]", "noindex, nofollow"

      get sitemap_path
      assert_no_match(/<loc>/, response.body, "el mapa de la muestra no enseña ninguna dirección")
    end
  end

  test "fuera de la muestra, los buscadores entran como siempre" do
    get robots_path
    assert_match(/Allow: \//, response.body)

    get root_path
    assert_select "meta[name=robots]", count: 0
  end

  test "«iniciar sesión» de la muestra enseña el atajo y la clave" do
    en_la_muestra { get new_user_session_path }

    assert_select ".acceso-muestra", text: /#{Muestra::CLAVE}/
    assert_select ".acceso-muestra a[href=?]", root_path
  end

  test "y fuera de la muestra no dice ninguna clave" do
    get new_user_session_path

    assert_select ".acceso-muestra", count: 0
    assert_no_match(/#{Muestra::CLAVE}/, response.body)
  end

  # La franja solo existe en la muestra: en un colegio de verdad asustaría.
  test "fuera de la muestra, el panel no lleva la franja" do
    sign_in @a.director
    get dashboards_administrador_path

    assert_response :success
    assert_select ".aviso-muestra", count: 0
  end
end
