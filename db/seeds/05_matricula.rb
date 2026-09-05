# Alumnos, representantes e inscripciones (MOR-224).
paso "🎓 Alumnos"

# ⚠️ Cuatro alumnos van FIJOS, y no es capricho: alguien depende de ellos.
#
#     alvaro.lopez001@bolivar.edu   es una credencial que los brokers usan en
#                                   producción ahora mismo
#     los cinco casos de notas      el paso de evaluación los busca por puesto
#                                   dentro de «1er Año A»
#
# Sin fijarlos, cambiar la lista de apellidos —o el orden de los grados, que es
# justo lo que cambió acá— les mueve el correo y la credencial deja de existir.
DESTACADOS = {
  [ "1er Año", "A", 0 ] => { nombre: "Álvaro", apellido: "López", segundo: "Guzmán" },
  [ "1er Año", "A", 1 ] => { nombre: "Sofía",  apellido: "Ramos", segundo: "Mora" },
  [ "1er Año", "A", 2 ] => { nombre: "Miguel", apellido: "Pérez", segundo: "Reyes" }
}.freeze

# El correo es de bachillerato para arriba, y no es un detalle de los datos de
# prueba: es la regla del dominio hecha visible (MOR-142). Un niño de 3er Grado
# tiene ocho años y no tiene correo; quien consulta sus notas es su madre. El
# bachiller de 5to Año sí puede tener uno.
#
# Así se cargan ~250 personas sin correo de una sola vez, que es exactamente lo
# que el índice único plano no permitía.
def sembrar_alumnos!(colegio, secciones, dominio:, desde:)
  Current.school = colegio
  k = desde
  con_correo = 0

  secciones.to_h do |seccion, inscritos|
    grado = seccion.grade
    alumnos = Array.new(inscritos) do |i|
      k += 1
      fijo = DESTACADOS[[ grado.name, seccion.name, i ]] || {}
      nombre   = fijo[:nombre]   || nombre_para(k)
      apellido = fijo[:apellido] || apellido_para(k)
      segundo  = fijo[:segundo]  || segundo_apellido_para(k)

      correo = nil
      if grado.media?
        con_correo += 1
        correo = "#{sin_acentos(nombre)}.#{sin_acentos(apellido)}#{con_correo.to_s.rjust(3, '0')}@#{dominio}"
      end

      nace = nacimiento_para(grado, k)
      alumno!(
        card: "25-#{k.to_s.rjust(4, '0')}", school: colegio,
        cedula_escolar: cedula_escolar_para(k, nace.year),
        first_name: nombre, last_name: apellido, second_last_name: segundo,
        birth_date: nace, sex: sexo_para(nombre), email: correo
      )
    end
    [ seccion, alumnos ]
  end
end

# ⚠️ El contador arranca distinto en cada colegio porque la CÉDULA ESCOLAR es
# única en todo el país, no por colegio. Con los dos arrancando en 1, noventa de
# los alumnos de Bello chocaban contra los de Bolívar.
SEMILLA[:alumnos_bolivar] = sembrar_alumnos!(
  SEMILLA[:bolivar], SEMILLA[:secciones_bolivar], dominio: "bolivar.edu", desde: 0
)
SEMILLA[:alumnos_bello] = sembrar_alumnos!(
  SEMILLA[:bello], SEMILLA[:secciones_bello], dominio: "bello.edu", desde: 1_000
)

Current.school = SEMILLA[:bolivar]
puts "   ✓ #{SEMILLA[:alumnos_bolivar].values.sum(&:size)} alumnos en Bolívar · " \
     "#{SEMILLA[:alumnos_bello].values.sum(&:size)} en Bello"

sin_correo = Current.sin_aislamiento { Student.unscoped.joins(:user).where(users: { email: nil }).count }
puts "     #{sin_correo} sin correo: preescolar y primaria, que es el caso normal"

# ── Inscripciones ────────────────────────────────────────────────────────────
paso "📝 Inscripciones"

INSCRIPCION = Date.new(2025, 9, 16)

# ⚠️ Tres retirados, a propósito y en secciones distintas. Un colegio de
# trescientos sesenta alumnos pierde algunos durante el año, y un retirado NO
# cuenta para la matrícula facturable ni aparece en la planilla de notas — dos
# reglas que sin un solo retirado sembrado no se pueden ver funcionando.
RETIRADOS = { "3er Grado" => [ 25 ], "2do Año" => [ 19 ], "5to Año" => [ 9 ] }.freeze

def inscribir!(colegio, por_seccion)
  Current.school = colegio

  por_seccion.each do |seccion, alumnos|
    retirados = RETIRADOS.fetch(seccion.grade.name, []) if seccion.name == "A"
    retirados ||= []

    alumnos.each_with_index do |alumno, i|
      Enrollment.find_or_create_by!(student: alumno, section: seccion) do |e|
        e.enrollment_date = INSCRIPCION
        e.status = retirados.include?(i) ? :retirado : :regular
      end
    end
  end
end

inscribir!(SEMILLA[:bolivar], SEMILLA[:alumnos_bolivar])
inscribir!(SEMILLA[:bello],   SEMILLA[:alumnos_bello])

total_inscripciones = Current.sin_aislamiento { Enrollment.unscoped.count }
retirados = Current.sin_aislamiento { Enrollment.unscoped.where(status: :retirado).count }
puts "   ✓ #{total_inscripciones} inscripciones · #{retirados} retirados"

# ── Representantes ───────────────────────────────────────────────────────────
#
# Todos los alumnos tienen quien responda por ellos, porque así es un colegio:
# una lista de alumnos sin representantes no se parece a nada.
#
# Los casos que importan y que antes había que buscar a mano:
#
#     UNA HIJA            entra y cae directo en su boletín
#     DOS HIJOS           en grados distintos, mismo colegio → selector
#     DOS COLEGIOS        un usuario, dos filas de Representative → selector de colegio
#     SIN CORREO          existe, aparece en el listado y NO puede entrar
paso "👨‍👩‍👧 Representantes"

PARENTESCOS = %i[madre padre representante].freeze

def representante!(nombre:, apellido:, telefono:, colegio:, alumnos:,
                   email: nil, parentesco: :madre, con_clave: false)
  # ⚠️ Normalizar ANTES de preguntar. `documento_de_prueba` devuelve
  # «V-12345678», pero en la base vive «12345678»: el modelo le quita la letra y
  # los signos al guardar (MOR-142). Buscar el valor crudo no encuentra nada y
  # la segunda llamada intenta crear a la misma persona otra vez.
  documento = User.normalizar_documento(
    documento_de_prueba(email.presence || "#{nombre}.#{apellido}.#{colegio.id}"), :cedula_v
  )

  usuario = Current.sin_aislamiento { User.find_by(document: documento) }
  usuario ||= User.create!(
    first_name: nombre, last_name: apellido, email: email,
    document: documento, document_type: :cedula_v,
    sex: parentesco == :padre ? :male : :female,
    # Sin correo no hay contraseña: nadie se la podría hacer llegar y «Olvidé mi
    # contraseña» no tiene a dónde escribir. Queda esperando el código de
    # activación (MOR-143), que es el estado en que un importador deja a medio
    # colegio.
    encrypted_password: (CLAVE_CIFRADA if email.present?)
  )

  rep = Representative.find_or_create_by!(user: usuario, school: colegio) { |r| r.phone = telefono }
  Array(alumnos).each do |alumno|
    # ⚠️ PRINCIPAL solo si el alumno no tiene ya uno. La validación es del
    # modelo —«ya hay otro representante principal para este alumno»— y es
    # correcta: alguien tiene que ser el contacto, y tiene que ser uno solo.
    # Un segundo vínculo es la tía que también puede retirarlo del colegio.
    ya_tiene = StudentRepresentative.exists?(student: alumno, principal: true)
    StudentRepresentative.find_or_create_by!(representative: rep, student: alumno) do |v|
      v.parentesco = parentesco
      v.principal  = !ya_tiene
    end
  end
  rep
end

# El teléfono lleva su guion puesto: cuatro de código y siete de número. Solo un
# MÓVIL ofrece WhatsApp (MOR-181), así que la lista mezcla móviles y fijos — un
# colegio real tiene los dos, y hay que poder ver que el botón no aparece.
CODIGOS = %w[0414 0424 0412 0416 0426 0212 0241].freeze

def telefono_para(k) = "#{CODIGOS[k % CODIGOS.size]}-#{(1_000_000 + k * 7919) % 10_000_000}"

# ── Los cuatro casos con nombre ──────────────────────────────────────────────
#
# ⚠️ Van ANTES del reparto en masa, y el orden es lo que los sostiene. Sus
# correos son credenciales que alguien está usando, y el modelo admite UN solo
# representante principal por alumno: si el reparto llega primero, María Pérez
# queda como vínculo secundario de su propio hijo.
Current.school = SEMILLA[:bolivar]
primero_de = ->(grado, seccion) {
  SEMILLA[:alumnos_bolivar].find { |s, _| s.grade.name == grado && s.name == seccion }&.last || []
}
un_ano_a = primero_de.("1er Año", "A")
un_grado_a = primero_de.("1er Grado", "A")
bello_1a = SEMILLA[:alumnos_bello].find { |s, _| s.grade.name == "1er Grado" }&.last || []

representante!(email: "carmen.lopez@familia.test", nombre: "Carmen", apellido: "López",
               telefono: "0414-1112233", colegio: SEMILLA[:bolivar],
               alumnos: un_ano_a[0], parentesco: :madre)

representante!(email: "jose.ramos@familia.test", nombre: "José", apellido: "Ramos",
               telefono: "0424-4445566", colegio: SEMILLA[:bolivar],
               alumnos: [ un_ano_a[1], un_grado_a[0] ], parentesco: :padre)

# EL CASO DIFÍCIL: hijos en los DOS colegios. Un usuario, dos filas de
# `Representative` —igual que un profesor que trabaja en dos planteles—. Es lo
# que obliga al selector de colegio, y sin sembrarlo no hay forma de ver si
# funciona.
[ [ SEMILLA[:bolivar], un_ano_a[2] ], [ SEMILLA[:bello], bello_1a[0] ] ].each do |colegio, hijo|
  Current.school = colegio
  representante!(email: "maria.perez@familia.test", nombre: "María", apellido: "Pérez",
                 telefono: "0412-7778899", colegio: colegio, alumnos: hijo, parentesco: :madre)
end

# SIN CORREO, con nombre propio: es el caso que hay que poder señalar en una
# demostración sin buscarlo entre trescientos.
Current.school = SEMILLA[:bello]
representante!(nombre: "Yolanda", apellido: "Guerra", telefono: "0416-3334455",
               colegio: SEMILLA[:bello], alumnos: bello_1a[1], parentesco: :madre)

def sembrar_representantes!(colegio, por_seccion, dominio:, desde:)
  Current.school = colegio
  k = desde

  por_seccion.each do |seccion, alumnos|
    # ⚠️ Los HERMANOS: cada tantos alumnos, uno hereda el representante del
    # anterior. Sin esto, el selector de representado del portal nunca se ve —
    # todos los representantes tendrían exactamente un hijo.
    anterior = nil

    alumnos.each_with_index do |alumno, i|
      k += 1
      # ⚠️ Los casos con nombre ya se sembraron: no se les pisa el vínculo.
      next if StudentRepresentative.exists?(student: alumno)
      if anterior && (i % 7).zero?
        StudentRepresentative.find_or_create_by!(representative: anterior, student: alumno) do |v|
          v.parentesco = :madre
          v.principal  = false
        end
        next
      end

      apellido = alumno.user.last_name
      nombre   = nombre_para(k * 3)
      # ⚠️ Uno de cada cuatro SIN correo. Es lo que produce el importador con
      # una planilla real, y es el estado que el colegio tiene que poder ver:
      # la persona existe, sale en el listado, y no puede entrar hasta que le
      # carguen el correo.
      correo = ((k % 4).zero? ? nil : "#{sin_acentos(nombre)}.#{sin_acentos(apellido)}#{k}@familia.test")

      anterior = representante!(
        nombre: nombre, apellido: apellido, email: correo,
        telefono: telefono_para(k), colegio: colegio, alumnos: alumno,
        parentesco: PARENTESCOS[k % PARENTESCOS.size]
      )
    end
  end
end

sembrar_representantes!(SEMILLA[:bolivar], SEMILLA[:alumnos_bolivar], dominio: "familia.test", desde: 0)
sembrar_representantes!(SEMILLA[:bello],   SEMILLA[:alumnos_bello],   dominio: "familia.test", desde: 5_000)

Current.school = SEMILLA[:bolivar]
totales = Current.sin_aislamiento do
  { reps: Representative.unscoped.count,
    vinculos: StudentRepresentative.unscoped.count,
    sin_correo: Representative.unscoped.joins(:user).where(users: { email: nil }).count }
end
puts "   ✓ #{totales[:reps]} representantes · #{totales[:vinculos]} vínculos"
puts "     #{totales[:sin_correo]} SIN correo: existen, salen en el listado y no pueden entrar"
