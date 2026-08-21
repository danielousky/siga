require "test_helper"

# Que una persona pueda existir en SIGA sin poder entrar (MOR-142).
#
# Es la precondición del importador: un colegio carga 360 alumnos desde una
# planilla que no trae ni correos ni contraseñas, y ninguno de esos niños va a
# iniciar sesión — el que consulta es su representante.
class UserTest < ActiveSupport::TestCase
  # ── sin credenciales ──────────────────────────────────────────────────────

  test "una persona puede existir sin correo y sin contraseña" do
    alumno = User.create!(first_name: "Álvaro", last_name: "López",
                          cedula_escolar: "V2099001777")

    assert_nil alumno.email
    assert_nil alumno.encrypted_password
    assert_not alumno.puede_entrar?
  end

  # ⚠️ Este es EL test del issue.
  #
  # Antes fallaba en la segunda fila, no en la primera: `users.email` era
  # `DEFAULT '' NOT NULL` con índice único PLANO, y PostgreSQL admite muchos
  # NULL —cada uno es distinto— pero un solo `''`. O sea: el alumno 2 de 360
  # reventaba la importación con una violación de índice único.
  test "muchas personas pueden existir sin correo a la vez" do
    creados = Array.new(50) do |i|
      User.create!(first_name: "Alumno#{i}", last_name: "Prueba",
                   cedula_escolar: "V2099#{i.to_s.rjust(7, '0')}")
    end

    assert_equal 50, User.where(id: creados.map(&:id), email: nil).count
  end

  test "el correo en blanco del formulario se guarda como nulo, no como cadena vacía" do
    # Un `<input type=\"email\">` vacío llega como `""`, y `''` SÍ choca contra
    # el índice único parcial. Esta es la línea que separa las dos cosas.
    alumno = User.create!(first_name: "Vacío", last_name: "Prueba",
                          cedula_escolar: "V2099001888", email: "   ")

    assert_nil alumno.email
  end

  test "una persona sin contraseña no entra, ni con la contraseña vacía" do
    alumno = User.create!(first_name: "Sin", last_name: "Clave",
                          cedula_escolar: "V2099001999")

    assert_not alumno.valid_password?("")
    assert_not alumno.valid_password?("123123")
    assert_not alumno.valid_password?(nil.to_s)
  end

  test "dejar el campo de contraseña en blanco no es un error de validación" do
    persona = User.new(first_name: "Blanco", last_name: "Prueba",
                       cedula_escolar: "V2099002111",
                       password: "", password_confirmation: "")

    assert persona.valid?, persona.errors.full_messages.to_sentence
  end

  # ── lo que NO cambió ──────────────────────────────────────────────────────

  test "el correo repetido se sigue rechazando" do
    User.create!(first_name: "Primera", last_name: "Persona", document: "99000001",
                 document_type: :cedula_v, email: "choque@siga.test", password: "123123")

    segunda = User.new(first_name: "Segunda", last_name: "Persona", document: "99000002",
                       document_type: :cedula_v, email: "choque@siga.test", password: "123123")

    assert_not segunda.valid?
    assert_includes segunda.errors.attribute_names, :email
  end

  test "quien pone contraseña sigue entrando con ella" do
    persona = User.create!(first_name: "Con", last_name: "Clave", document: "99000003",
                           document_type: :cedula_v, email: "con.clave@siga.test",
                           password: "123123")

    assert persona.valid_password?("123123")
    assert persona.puede_entrar?
  end

  test "una contraseña demasiado corta se sigue rechazando" do
    persona = User.new(first_name: "Corta", last_name: "Clave", document: "99000004",
                       document_type: :cedula_v, password: "123")

    assert_not persona.valid?
    assert_includes persona.errors.attribute_names, :password
  end

  test "una persona sin ningún identificador no puede existir" do
    assert_not User.new(first_name: "Nadie", last_name: "Sin Nada").valid?
  end

  # ⚠️ La regresión que rompió producción.
  #
  # `MOR-138` agregó `tiene_algun_identificador` sobre una tabla que YA tenía
  # datos. En producción 298 de 313 filas no lo cumplían, y el efecto no fue un
  # error al crear: fueron 298 usuarios CONGELADOS. Cualquier `save` fallaba,
  # incluido el de Devise al cambiar la contraseña — así que la fila no se podía
  # ni arreglar.
  #
  # `bin/ci` no lo veía porque los seeds regeneran todo desde cero y ahí todos
  # cumplen. Para reproducirlo hay que saltarse la validación al crear, que es
  # exactamente lo que hizo la migración.
  test "una fila que ya existía sin identificador puede cambiar su contraseña" do
    legado = User.new(first_name: "Ramón", last_name: "Díaz", email: "legado@siga.test")
    legado.save!(validate: false)

    assert legado.reset_password("clave-nueva", "clave-nueva"),
           "quedó congelado: #{legado.errors.full_messages.to_sentence}"
    assert legado.reload.valid_password?("clave-nueva")
  end

  test "pero no puede BORRAR el identificador que ya tenía" do
    persona = User.create!(first_name: "Con", last_name: "Cédula",
                           document: "99000010", document_type: :cedula_v)

    persona.document = ""

    assert_not persona.valid?
  end

  test "y una fila nueva sigue necesitando uno" do
    assert_not User.new(first_name: "Nueva", last_name: "SinNada",
                        email: "nueva@siga.test").valid?
  end

  # ── normalización del documento ───────────────────────────────────────────

  test "la cédula se guarda con solo dígitos, la escriban como la escriban" do
    {
      "V-99.345.678" => "99345678",
      "V99345678"    => "99345678",
      " 99345678 "   => "99345678",
      "99.345.678"   => "99345678"
    }.each do |escrita, esperada|
      persona = User.new(document: escrita, document_type: :cedula_v)
      persona.valid?

      assert_equal esperada, persona.document, "#{escrita.inspect} debería normalizar a #{esperada}"
    end
  end

  test "los ceros a la izquierda no hacen dos personas de una" do
    persona = User.new(document: "E-00993456", document_type: :cedula_e)
    persona.valid?

    assert_equal "993456", persona.document
  end

  # ⚠️ La regla de la cédula —"solo dígitos"— aplicada a un pasaporte lo deja
  # identificando a otra persona: `A1234567B` se convertiría en `1234567`.
  test "el pasaporte conserva sus letras" do
    persona = User.new(document: "a1234567b", document_type: :pasaporte)
    persona.valid?

    assert_equal "A1234567B", persona.document
  end

  test "el carné diplomático conserva sus letras" do
    persona = User.new(document: "cd-99 8877", document_type: :carne_diplomatico)
    persona.valid?

    assert_equal "CD998877", persona.document
  end

  # La cédula escolar la define el MPPE: 12 caracteres que empiezan por la
  # nacionalidad. Los guiones son parte del dato, no ruido.
  test "la cédula escolar conserva su formato" do
    persona = User.new(cedula_escolar: " v2015-0000123 ")
    persona.valid?

    assert_equal "V2015-0000123", persona.cedula_escolar
  end

  test "normalizar_documento sirve para BUSCAR, no solo para guardar" do
    # Es lo que necesitan el importador y el alta de representantes: en la base
    # vive `99345678`, y `WHERE document = 'V-99.345.678'` no devuelve nada.
    assert_equal User.normalizar_documento("99345678", :cedula_v),
                 User.normalizar_documento("V-99.345.678", :cedula_v)
  end

  # El importador las va a ver todas: el símbolo lo usa el modelo, la cadena la
  # manda el `<select>`, y el entero es como sale de exportar otra base.
  test "normalizar_documento entiende el tipo venga como venga" do
    [:cedula_v, "cedula_v", 0, "0"].each do |tipo|
      assert_equal "99345678", User.normalizar_documento("V-99.345.678", tipo),
                   "el tipo #{tipo.inspect} debería normalizar igual"
    end
  end

  # ── el correo, cuando el rol sí entra ─────────────────────────────────────

  test "el profesor necesita correo aunque el alumno no" do
    colegio = escenario_academico.colegio

    con_el_colegio(colegio) do
      sin_correo = Teacher.new(school: colegio,
                               user: User.new(first_name: "Prof", last_name: "SinCorreo",
                                              document: "99000005", document_type: :cedula_v))

      assert_not sin_correo.valid?
    end
  end

  test "el director necesita correo" do
    colegio = escenario_academico.colegio

    con_el_colegio(colegio) do
      sin_correo = Admin.new(school: colegio, role: :director,
                             user: User.new(first_name: "Dir", last_name: "SinCorreo",
                                            document: "99000006", document_type: :cedula_v))

      assert_not sin_correo.valid?
    end
  end

  test "el equipo de SIGA necesita correo" do
    sin_correo = SigaStaff.new(role: :operaciones,
                               user: User.new(first_name: "Ops", last_name: "SinCorreo",
                                              document: "99000008", document_type: :cedula_v))

    assert_not sin_correo.valid?
  end

  test "el alumno NO necesita correo" do
    colegio = escenario_academico.colegio

    con_el_colegio(colegio) do
      alumno = Student.new(school: colegio, school_card: "SIN-CORREO-1",
                           user: User.new(first_name: "Alum", last_name: "SinCorreo",
                                          cedula_escolar: "V2099002222"))

      assert alumno.valid?, alumno.errors.full_messages.to_sentence
    end
  end

  test "el representante NO necesita correo: entra si lo tiene" do
    colegio = escenario_academico.colegio

    con_el_colegio(colegio) do
      representante = Representative.new(
        school: colegio,
        user: User.create!(first_name: "Mamá", last_name: "SinCorreo",
                           document: "99000007", document_type: :cedula_v)
      )

      assert representante.valid?, representante.errors.full_messages.to_sentence
    end
  end
end
