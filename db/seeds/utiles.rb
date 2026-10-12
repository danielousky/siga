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

# ── Las tres puertas de la muestra ───────────────────────────────────────────
#
# El director, el profesor y la representante con que se entra al colegio de
# muestra (`Muestra::CUENTAS`). Los correos salen de ahí y no se escriben acá:
# la pantalla de entrada busca a la persona por ESE correo, y dos copias del
# mismo texto son una puerta que un día deja de abrir.
#
# Son las mismas en desarrollo y en la muestra: lo que se prueba en local es lo
# que ve quien entra a `demo.sigaeducando.com`.
CORREO_DEL_DIRECTOR        = Muestra.cuenta("director").correo
CORREO_DEL_PROFESOR        = Muestra.cuenta("profesor").correo
CORREO_DE_LA_REPRESENTANTE = Muestra.cuenta("representante").correo

# ── El calendario de la siembra ──────────────────────────────────────────────
#
# Los años escolares se cuentan DESDE HOY, y no están escritos con su número.
#
#     HISTÓRICO   hace dos años   solo las definitivas, importadas del sistema viejo
#     ANTERIOR    el año pasado   completo en SIGA: tres lapsos cerrados y sus boletines
#     EN CURSO    este año        hasta HOY: lo evaluado, la asistencia de estas semanas
#     SIGUIENTE   el que viene    solo en vacaciones: la estructura copiada, sin alumnos
#
# ## Por qué
#
# Estaban escritos —2024-2025, 2025-2026, 2026-2027— y funcionó mientras la
# siembra y el calendario coincidieron. El 12 de octubre de 2026 la muestra
# abría en un año «finalizado el 31 de julio»: no se podía pasar lista de hoy,
# ni cargar una nota en un lapso abierto, ni ver una cuota por vencer. Un
# colegio que se enseña funcionando tiene que estar funcionando HOY.
#
# Y como la muestra se vuelve a sembrar cada noche, el colegio avanza solo: en
# noviembre tendrá un mes más de asistencia y otra evaluación calificada; en
# enero, el primer lapso cerrado con sus boletines; en agosto, el año terminado
# y la promoción esperando.
#
# ⚠️ Determinista igual: dos siembras del MISMO día dan exactamente lo mismo.
# Lo que cambia de un día al otro es lo que cambiaría en un colegio.
HOY = Date.current

ANIO_EN_CURSO = begin
  arranque = Date.new(HOY.year, AcademicPeriod::COMIENZA[:mes], AcademicPeriod::COMIENZA[:dia])
  HOY >= arranque ? HOY.year : HOY.year - 1
end

def habil?(dia) = !(dia.saturday? || dia.sunday?)

# El mismo día si es de clases; si no, el lunes que sigue.
def dia_habil(dia)
  dia += 1 until habil?(dia)
  dia
end

def dias_habiles(desde, hasta) = desde > hasta ? [] : (desde..hasta).select { |d| habil?(d) }

# En qué está un lapso HOY.
def situacion_del_lapso(lapso)
  return :terminado if lapso.ends_on < HOY
  return :corriendo if lapso.starts_on <= HOY

  :por_empezar
end

# Un momento del día para fechar lo que pasó: las diez de la mañana de ese día.
def a_las_diez(dia) = dia.in_time_zone.change(hour: 10)

# ── Códigos de documentos, siempre los mismos ────────────────────────────────
#
# El código de un boletín o de una constancia lo sortea el modelo, y está bien:
# en un colegio nadie tiene que poder adivinarlo. Acá se FIJA, a partir de algo
# estable —el alumno y el lapso—, porque la muestra se vuelve a sembrar cada
# noche: un código sorteado cambiaría con cada siembra, y el que alguien anotó
# ayer para enseñar `/verificar` hoy no existiría.
ALFABETO_DE_CODIGOS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".chars.freeze

def codigo_fijo(prefijo, *semillas)
  azar = Random.new(Digest::MD5.hexdigest(semillas.join("/")).to_i(16) % (2**31))
  "#{prefijo}-" + Array.new(2) { Array.new(4) { ALFABETO_DE_CODIGOS[azar.rand(ALFABETO_DE_CODIGOS.size)] }.join }.join("-")
end

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
#
# ⚠️ `en` es el año en que el alumno CURSA ese grado, no el de hoy: la matrícula
# se siembra en el año anterior y después se promueve, así que con el año de hoy
# todos saldrían un año más jóvenes de lo que su grado dice.
def nacimiento_para(grade, k, en: Date.current.year)
  orden = GradoOficial.orden_de(grade.name) || 1
  edad  = 2 + orden                                # 1er Nivel (orden 1) → 3 años
  Date.new(en - edad, (k % 12) + 1, (k % 28) + 1)
end

# ── Con qué notas sale cada quién ────────────────────────────────────────────
#
# Antes cada nota era un número al azar entre 8 y 20, y el promedio de nueve
# números al azar es siempre catorce: nadie reprobaba nada. Un colegio así no
# tiene reparaciones, ni repitientes, ni un representante preocupado — o sea que
# la mitad de las pantallas no tenían qué mostrar.
#
# Ahora cada alumno tiene un PERFIL, y de cada veinte:
#
#     4  sobresalientes   alrededor de 18
#     9  buenos           alrededor de 15
#     5  regulares        alrededor de 12   ← aplazan la materia difícil, y reparan
#     1  justo            alrededor de 11   ← aplaza dos o tres
#     1  en riesgo        alrededor de 9    ← aplaza casi todo: repara, y aun así puede repetir
#
# Sobre eso, cada área pesa distinto —Matemática y Física cuestan dos puntos,
# Educación Física regala dos— y cada evaluación se mueve dos puntos para
# arriba o para abajo. Todo sale del número del alumno: la misma siembra da las
# mismas notas.
PERFILES = ([ 18 ] * 4 + [ 15 ] * 9 + [ 12 ] * 5 + [ 11, 9 ]).freeze

DIFICULTAD = { "MAT" => -2, "FIS" => -2, "QUI" => -1, "ING" => -1, "PRG" => -1,
               "EDF" => 2, "ART" => 1, "EST" => 1, "GCR" => 1, "OYC" => 1 }.freeze

# El número con que nació el alumno en la siembra: el final de su carnet.
def numero_de(alumno) = alumno.school_card.to_s[/\d+\z/].to_i

# 7 es coprimo con 20: recorre los veinte perfiles antes de repetir, así que
# cualquier sección de veinte alumnos tiene los cuatro tipos.
def base_del_alumno(k) = PERFILES[(k * 7) % PERFILES.size]

# Un número entre 0 y `de - 1`, siempre el mismo para las mismas semillas.
#
# ⚠️ Con un resumen (MD5) y no con una cuenta —`k * 13 % 20`—: los alumnos de
# un mismo perfil comparten el resto de dividir su número, así que cualquier
# cuenta sobre ese número los trata igual. Pasó: de ochenta y dos materias por
# reparar, setenta y tres «sacaron» la misma suerte y aprobaron todas.
def suerte(*semillas, de:)
  Digest::MD5.hexdigest(semillas.join("/")).to_i(16) % de
end

# Entre -2 y 2, y siempre igual para las mismas semillas.
def vaiven(*semillas) = suerte(*semillas, de: 5) - 2

def nota_de(k, codigo, lapso, evaluacion, base: nil)
  ((base || base_del_alumno(k)) + DIFICULTAD.fetch(codigo, 0) + vaiven(k, codigo, lapso, evaluacion)).clamp(1, 20)
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

# La del equipo de SIGA, que en la muestra no es la pública
# (`SeedGuard#clave_del_equipo`).
CLAVE_DEL_EQUIPO_CIFRADA = Devise::Encryptor.digest(User, CLAVE_DEL_EQUIPO).freeze

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
    # Ya cifrada: veintinueve docentes cifrando cada uno su clave eran diez
    # segundos de siembra para llegar a la misma.
    u.encrypted_password = CLAVE_CIFRADA
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

# Anuncia un paso, y dice cuánto tardó el anterior.
#
# El tiempo no es curiosidad: la siembra corre en cada `bin/ci` y cada noche en
# la muestra, y cuando se pone lenta hay que saber DÓNDE antes de tocar nada
# (`CLAUDE.md`: «antes de optimizar, se mira dónde se va el tiempo»).
def paso(titulo)
  ahora = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  puts format("     · %.1f s", ahora - $inicio_del_paso) if $inicio_del_paso
  $inicio_del_paso = ahora

  puts ""
  puts titulo
end
