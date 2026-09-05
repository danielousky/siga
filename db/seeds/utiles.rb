# Lo que comparten los pasos de la siembra (MOR-224).
#
# ## Por qué el archivo está partido
#
# `db/seeds.rb` llegó a 1.216 líneas con la demo vieja —dos colegios chicos— y
# la nueva siembra un colegio COMPLETO: quince grados, los tres niveles, la
# Media Técnica y trescientos sesenta alumnos. En un archivo solo, encontrar
# dónde se decide algo cuesta más que cambiarlo.
#
# El orden de los pasos es el orden en que un colegio se arma de verdad, y no
# es negociable: no hay secciones sin grados, ni notas sin inscripciones.
#
# ## SEMILLA: el cajón de lo que se va creando
#
# Los archivos se cargan con `load`, así que comparten métodos y constantes
# pero **no** variables locales. `SEMILLA` es el único estado que viaja entre
# pasos: cada uno guarda lo que el siguiente necesita.
SEMILLA = {}

# ⚠️ Determinista, siempre. Los seeds tienen que dar EXACTAMENTE lo mismo en
# cada corrida: un dato que cambia de una siembra a otra hace que la demo que
# alguien mostró ayer no exista hoy, y que un bug no se pueda reproducir.

# Todo adulto tiene cédula de identidad: la escolar existe justamente para quien
# todavía no la tiene.
def documento_de_prueba(email)
  "V-#{(Digest::MD5.hexdigest(email).to_i(16) % 20_000_000 + 5_000_000)}"
end

def sexo_para(nombre)
  # Suficiente para datos de prueba: los nombres de la lista que terminan en
  # `a` son femeninos, salvo los que no.
  %w[Andrés Rafael Nicolás Tomás Elías Josué].include?(nombre) ? :male :
    (nombre.end_with?("a") ? :female : :male)
end

def sin_acentos(texto)
  texto.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
end

# ── Nombres ──────────────────────────────────────────────────────────────────
#
# ⚠️ El apellido NO puede salir del mismo índice que el nombre.
#
# Así estaba, y de las 1.600 combinaciones posibles solo aparecían las 40 de la
# diagonal: en 360 alumnos, cada nombre repetido nueve veces. La lista mostraba
# «Blanco, José» tres veces seguidas y parecía un error del sistema en plena
# demostración.
#
# `k*7` mezcla —7 es coprimo con 40, así que recorre la lista entera— y `k/40`
# desplaza el arranque en cada vuelta.
NOMBRES = %w[
  Álvaro Sofía Miguel Laura Andrés Valentina Carlos Isabella José María
  Luis Ana Diego Camila Rafael Daniela Fernando Paula Gabriel Natalia
  Sebastián Valeria Eduardo Lucía Omar Paola Héctor Gabriela Erick Verónica
  Nicolás Adriana Tomás Mariana Elías Fabiana Josué Andreína Ismael Rebeca
].freeze

APELLIDOS = %w[
  López Ramos Pérez Guzmán Mora Reyes Salinas Vargas Blanco Cruz
  Fuentes Jiménez Herrera Suárez Castillo Mendoza Rojas Torres García Silva
  Díaz Romero Fernández Ortega Soto Cabrera Medina Ríos Vega Parra
  Colmenares Bastidas Quintero Marcano Bermúdez Aponte Villalba Nieves Ochoa Zambrano
].freeze

def nombre_para(k)   = NOMBRES[k % NOMBRES.size]
def apellido_para(k) = APELLIDOS[(k * 7 + k / APELLIDOS.size) % APELLIDOS.size]
def segundo_apellido_para(k) = APELLIDOS[(k * 11 + 3) % APELLIDOS.size]

# ── Identidad de un alumno ───────────────────────────────────────────────────

# La CÉDULA ESCOLAR generada acá es SINTÉTICA y se nota a propósito.
#
# La real la asigna el MPPE y codifica nacionalidad, año de nacimiento y los
# últimos ocho dígitos de la cédula de la MADRE. No hay algoritmo público, así
# que inventarlo daría números que parecen válidos y no lo son — peor que uno
# que se ve claramente de prueba.
#
# Lo que sí respeta es lo estructural, que es lo que el sistema soporta: doce
# caracteres, ÚNICA EN TODO EL PAÍS (no por colegio) y derivada del año de
# nacimiento.
def cedula_escolar_para(k, anio_nacimiento)
  "V#{anio_nacimiento}#{(k * 37 + 1_000_000).to_s.rjust(7, '0')[0, 7]}"
end

# La edad sale del GRADO, y el MPPE la verifica contra la partida de nacimiento:
# no es decorativa. Sale del catálogo oficial y no del enum `level`, porque
# dentro de bachillerato un 1er Año y un 5to Año se llevan cuatro años.
#
#     1er Nivel  ≈ 3 años      1er Grado ≈ 6      1er Año ≈ 12      6to Año ≈ 17
def nacimiento_para(grade, k)
  orden = GradoOficial.orden_de(grade.name) || 1
  edad  = 2 + orden                                # 1er Nivel (orden 1) → 3 años
  Date.new(Date.current.year - edad, (k % 12) + 1, (k % 28) + 1)
end

# ⚠️ La contraseña se cifra UNA vez y se reparte.
#
# `config.stretches = 12` fuera de test, o sea ~250 ms por contraseña. Con
# trescientos sesenta alumnos y sus representantes, dejar que Devise cifre cada
# uno se lleva **más de un minuto** de la siembra — y `bin/ci` corre los seeds
# de punta a punta en cada corrida.
#
# Todos comparten la misma clave de demostración, así que comparten el mismo
# digest sin perder nada. Los doce stretches siguen puestos para la app: esto es
# el sembrador, no el registro.
CLAVE_CIFRADA = Devise::Encryptor.digest(User, CLAVE_DE_PRUEBA).freeze

# ── Altas ────────────────────────────────────────────────────────────────────

# ⚠️ Se busca por CARNET y, si no, por CÉDULA ESCOLAR. Nunca por correo.
#
# Desde `MOR-142` la mayoría de los alumnos no tiene correo, y
# `find_or_create_by!(email: nil)` **encuentra al primer alumno sin correo que
# haya** y lo devuelve como si fuera éste: trescientos alumnos colapsados en
# uno. La cédula escolar sirve porque es única en todo el país y no se deriva
# del nombre — cambiar la lista de apellidos no la mueve.
def alumno!(card:, school:, cedula_escolar:, **atributos)
  existente = Student.find_by(school_card: card, school: school)
  if existente
    existente.user.update!(cedula_escolar: cedula_escolar, **atributos)
    return existente
  end

  usuario = Current.sin_aislamiento { User.find_by(cedula_escolar: cedula_escolar) }
  usuario ||= User.new(cedula_escolar: cedula_escolar, **atributos).tap do |u|
    # Contraseña SOLO si va a entrar. Sin correo no hay forma de hacérsela
    # llegar y «Olvidé mi contraseña» no tiene a dónde escribir.
    u.encrypted_password = CLAVE_CIFRADA if atributos[:email].present?
    u.save!
  end
  Student.create!(user: usuario, school_card: card, school: school)
end

def profesor!(email:, nombre:, apellido:, documento:, colegio:)
  usuario = User.find_or_create_by!(email: email) do |u|
    u.password = u.password_confirmation = CLAVE_DE_PRUEBA
    u.first_name = nombre
    u.last_name  = apellido
    u.document   = documento
    # Un profesor SIEMPRE tiene cédula de identidad y NUNCA cédula escolar: la
    # escolar existe para quien todavía no tiene la nacional.
    u.document_type = :cedula_v
    u.birth_date    = Date.new(1985, (documento.gsub(/\D/, "").to_i % 12) + 1, 15)
    u.sex           = sexo_para(nombre)
  end
  Teacher.find_or_create_by!(user: usuario, school: colegio)
end

def paso(titulo)
  puts ""
  puts titulo
end
