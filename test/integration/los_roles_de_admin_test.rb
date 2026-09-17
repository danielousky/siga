require "test_helper"

# Quién puede qué, en un colegio (MOR-208 revisado).
#
# Daniel, definiendo el modelo: *«Directivo (Director: ve y hace todo, inclusive
# crear otros admins y usuarios), Finanzas: para la parte de cobranzas y pagos
# (no ve mucho más de eso), y el otro el que vendría siendo el académico, que
# hace las gestiones generales del plantel (secretarias, coordinadores, control
# de estudio)»*.
#
#     DIRECTIVO   desarrollador · director · asistente
#     ACADÉMICO   coordinador · secretaria
#     FINANZAS    finanzas
#
# ⚠️ El ENUM no se toca: *«no es un rol nuevo… hay que revisar lo que se le
# permite a cada quien»*. Lo que cambia es el reparto.
class LosRolesDeAdminTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(nombre: "Colegio de Roles")
  end

  # ── la tabla se lee de un vistazo ─────────────────────────────────────────

  # ⚠️ Lo primero: que la tabla CUBRA a todos los roles del enum. Un rol nuevo
  # sin lugar en ella no puede nada y nadie se entera hasta que su dueño llama.
  test "todo rol del enum aparece en algún permiso" do
    repartidos = ApplicationController::PERMISOS.values.flatten.uniq

    sin_nada = Admin.roles.keys - repartidos

    assert_empty sin_nada,
      "roles que no pueden NADA: #{sin_nada.join(', ')}. Si es a propósito, " \
      "dilo en la tabla con una lista vacía."
  end

  # ── el directivo ──────────────────────────────────────────────────────────

  test "el directivo ve y hace todo" do
    entrar_como_admin(:director)

    { "alumnos" => students_path, "profesores" => teachers_path,
      "administradores" => admins_path, "secciones" => sections_path,
      "años escolares" => academic_periods_path, "documentos" => report_cards_path,
      "pagos" => finanzas_path, "auditoría" => dashboards_activity_logs_path }.each do |que, ruta|
      get ruta
      assert_response :success, "un director no puede entrar a #{que}"
    end
  end

  # ── el académico ──────────────────────────────────────────────────────────

  # ⚠️ Esto es lo que se agregó: *«lo que tenemos es agregarle a Coordinador y
  # Secretaria esas funciones»*.
  [ :coordinador, :secretaria ].each do |rol|
    test "#{rol} hace la gestión del plantel" do
      entrar_como_admin(rol)

      { "alumnos" => students_path, "secciones" => sections_path,
        "años escolares" => academic_periods_path,
        "documentos" => report_cards_path }.each do |que, ruta|
        get ruta
        assert_response :success, "#{rol} no puede entrar a #{que}"
      end
    end

    # ⚠️ Lo que distingue al directivo: crear a la gente que entra al sistema.
    test "#{rol} NO crea usuarios ni ve la bitácora" do
      entrar_como_admin(rol)

      [ teachers_path, admins_path, dashboards_activity_logs_path ].each do |ruta|
        get ruta
        assert_response :redirect, "#{rol} no debería entrar a #{ruta}"
      end
    end

    # ⚠️ El dinero es otra gaveta.
    test "#{rol} NO valida pagos" do
      entrar_como_admin(rol)

      get finanzas_path

      assert_response :redirect
    end
  end

  # ⚠️ Cerrar la calificación es de ACADÉMICO, no del director. Daniel:
  # *«control de estudio es quien cierra la calificación»*.
  test "el académico libera boletines" do
    entrar_como_admin(:coordinador)

    get revisar_boletines_path(seccion: @esc.seccion.id, lapso: @esc.lapso(1).id)

    assert_response :success
  end

  # ── finanzas ──────────────────────────────────────────────────────────────

  test "finanzas cobra y no toca la estructura académica" do
    entrar_como_admin(:finanzas)

    get finanzas_path
    assert_response :success

    [ students_path, sections_path, teachers_path, academic_periods_path ].each do |ruta|
      get ruta
      assert_response :redirect, "finanzas no debería entrar a #{ruta}"
    end
  end

  # ── el menú dice lo mismo que el controller ───────────────────────────────

  # ⚠️ Dos listas de roles se desparejan, y el síntoma es una entrada de menú
  # que lleva a un «esta parte la administra la dirección».
  test "lo que el menú ofrece es lo que el controller deja entrar" do
    Admin.roles.each_key do |rol|
      entrar_como_admin(rol.to_sym)
      get dashboards_administrador_path

      css_select("a.sidebar-nav-link").map { |a| a["href"] }.uniq.each do |ruta|
        next if ruta.blank? || ruta.start_with?("http")
        # El propio panel: es a donde rebota quien no tiene permiso, así que
        # como destino no prueba nada.
        next if ruta == dashboards_administrador_path

        get ruta
        # ⚠️ Un 302 NO es siempre un rebote de permisos: `/asistencia` con UNA
        # sección redirige a esa sección, que es un atajo deliberado. Lo que
        # este test persigue es el «no tienes permiso», así que se sigue el
        # redirect y se mira dónde se cae.
        follow_redirect! while response.redirect?

        assert_not_equal dashboards_administrador_path, path,
                         "el menú de #{rol} ofrece #{ruta} y el controller lo rebota"
        assert_response :success
      end
    end
  end

  private

  def entrar_como_admin(rol)
    usuario = con_el_colegio(@esc.colegio) do
      u = usuario("adm-#{rol}", @esc.colegio.id)
      Admin.create!(user: u, school: @esc.colegio, role: rol)
      u
    end
    sign_in usuario
  end
end
