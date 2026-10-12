require "digest"

# =============================================================================
# SIGA · Datos de demostración
# =============================================================================
#
# Un colegio venezolano COMPLETO —los tres niveles más la Media Técnica, quince
# grados, trescientos sesenta alumnos— y un segundo colegio chico que existe
# para que el aislamiento se pueda probar.
#
# El detalle de cada paso está en su propio archivo, bajo `db/seeds/`. El orden
# es el orden en que un colegio se arma de verdad y no es negociable: no hay
# secciones sin grados, ni notas sin inscripciones.
#
# =============================================================================
# GUARD DE ENTORNO — leer antes de tocar nada de acá abajo
# =============================================================================
#
# Este archivo crea cuentas con una contraseña conocida, y una de ellas tiene el
# rol `fundador`: máximo privilegio. Un `db:seed` contra la base de un colegio
# real —un deploy mal configurado, un comando en la terminal equivocada— no
# necesita ningún ataque para hacer daño. Y como la siembra es idempotente, ni
# siquiera fallaría: sembraría en silencio.
#
# El guard es por LISTA BLANCA y no por lista negra. Un `staging` con datos
# reales tiene el mismo problema y no es `production`.
#
# ## La puerta para la demo pública
#
# Una demo SÍ necesita estos datos, así que hay una salida — pero cuesta
# escribirla y no tiene default:
#
#     SIGA_ENTORNO_DEMO=1 SIGA_SEED_PASSWORD=<algo-que-no-sea-123123> bin/rails db:seed
#
# Ver MOR-104. La lógica vive en `lib/seed_guard.rb` para poder TESTEARLA: un
# guard sin test es una intención, no un control.
guard = SeedGuard.new

begin
  CLAVE_DE_PRUEBA = guard.clave
  # La del equipo de SIGA va aparte: en la muestra no es la pública. Ver
  # `SeedGuard#clave_del_equipo`.
  CLAVE_DEL_EQUIPO = guard.clave_del_equipo
rescue SeedGuard::EntornoNoPermitido, SeedGuard::FaltaLaClave => e
  abort "\n#{e.message}"
end

CORREO_DESARROLLADOR = guard.correo_desarrollador

# La siembra carga DOS colegios, así que necesita ver la plataforma entera. Sin
# esto el RLS la dejaría en cero filas y el segundo colegio no se crearía.
#
# El `at_exit` garantiza que la conexión no quede con el bypass puesto aunque la
# siembra falle a la mitad.
Current.tenant_scope_disabled = true
ActiveRecord::Base.connection.execute("SET siga.bypass_rls = 'on'")
at_exit do
  Current.tenant_scope_disabled = false
  ActiveRecord::Base.connection.execute("SET siga.bypass_rls = 'off'") rescue nil
end

# La siembra no anota cada consulta en el registro.
#
# Son decenas de miles —9.492 notas, cada una con sus recálculos— y en
# desarrollo cada renglón lleva además el archivo y la línea que lo pidió
# (`verbose_query_logs`): armar eso cuesta más que la consulta misma. Nadie lee
# ese registro, y pesaba la mitad de lo que tarda sembrar.
#
# `SIEMBRA_CON_REGISTRO=1 bin/rails db:seed` lo devuelve, para el día que haya
# que ver qué consulta hace un paso.
unless ENV["SIEMBRA_CON_REGISTRO"].present?
  nivel_del_registro = Rails.logger.level
  Rails.logger.level = :warn
  at_exit { Rails.logger.level = nivel_del_registro }
end

puts "🌱 Sembrando datos de demostración..."

# ⚠️ El orden importa y por eso está escrito, no deducido de `Dir.glob`: un
# archivo nuevo que se cuele entre dos pasos rompería la cadena en silencio.
%w[
  utiles
  01_colegios
  02_pensum
  03_personal
  04_estructura
  05_matricula
  06_evaluacion
  07_promocion
  08_en_curso
  09_dia_a_dia
  10_resumen
].each { |paso| load Rails.root.join("db/seeds/#{paso}.rb") }
