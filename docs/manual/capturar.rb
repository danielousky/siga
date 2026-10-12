# Captura las pantallas de SIGA para el manual.
require "capybara"; require "capybara/dsl"; require "selenium-webdriver"; require "fileutils"

# Las PNG crudas. `optimizar.sh` las pasa a JPEG en opt/, que es de donde lee armar.py.
M = File.expand_path("png", __dir__)
FileUtils.mkdir_p(M)

Capybara.register_driver(:cr) do |app|
  o = Selenium::WebDriver::Chrome::Options.new
  o.add_argument("--headless=new"); o.add_argument("--window-size=1280,900")
  o.add_argument("--force-device-scale-factor=1"); o.add_argument("--hide-scrollbars")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: o)
end
Capybara.default_driver = :cr
Capybara.app_host = "http://localhost:3000"
Capybara.default_max_wait_time = 10
include Capybara::DSL

def entrar(correo)
  visit "/"
  click_on "Cerrar sesión" if page.has_link?("Cerrar sesión", wait: 1)
  sleep 0.6
  visit "/users/sign_in"
  fill_in "Correo electrónico", with: correo
  fill_in "Contraseña", with: "123123"
  click_button "Iniciar sesión"
  sleep 1.5
end

# ⚠️ Una pantalla de error de Rails SE GUARDA IGUAL: `save_screenshot` no mira
# qué hay en la página. Un id que quedó en nil dio un "Routing Error" que viajó
# hasta el manual publicado y se descubrió leyéndolo. Por eso se revisa antes.
DELATA_UN_ERROR = [
  "Routing Error", "Application Trace", "Full Trace",
  "ActionController::", "ActiveRecord::", "NoMethodError",
  "We're sorry, but something went wrong", "Content missing"
].freeze

ALTO_NORMAL = 900

# `alto:` para las pantallas que no caben en 900 px —el plan de evaluación, el
# resumen del arranque—: recortarlas deja fuera justo lo que hay que enseñar.
def foto(nombre, ruta = nil, espera: 1.2, alto: ALTO_NORMAL, &bloque)
  page.driver.browser.manage.window.resize_to(1280, alto) if alto != ALTO_NORMAL
  visit(ruta) if ruta
  sleep espera
  bloque&.call

  texto = page.text.to_s
  if (culpable = DELATA_UN_ERROR.find { |m| texto.include?(m) })
    puts "  ✗ #{nombre}: la página es un ERROR (#{culpable}) — #{ruta}"
    return
  end

  page.save_screenshot("#{M}/#{nombre}.png")
  puts "  ✓ #{nombre}"
rescue StandardError => e
  puts "  ✗ #{nombre}: #{e.class} #{e.message.to_s[0, 70]}"
ensure
  page.driver.browser.manage.window.resize_to(1280, ALTO_NORMAL) if alto != ALTO_NORMAL
end

PRIM, INI, MED, ACT, INS, ALU, REP = 76, 73, 85, 571, 717, 675, 11
ANIO_NUEVO = 107   # 2026-2027 — el año al que se COPIA y al que se promueve
SIN_PLAN   = 80    # 3er Grado A · Ciencias Naturales, todavía sin competencias
PROF, PROFINI = "maestra.ochoa@bolivar.edu", "maestra.colmenares@bolivar.edu"

puts "── público"
foto("registro", "/registrarse")
foto("registro_sugerencias", nil, espera: 0.3) do
  fill_in "school[name]", with: "san jose"; sleep 2
end
foto("portada", "/")

# ⚠️ La puesta en marcha SOLO se ve en un colegio que todavía no terminó de
# armarse, y los seeds ya están completos: hay que registrar uno de cero. El
# sufijo de la hora evita chocar con el índice único del correo si se corre dos
# veces el mismo día.
puts "── la puesta en marcha"
SELLO = Time.now.strftime("%m%d%H%M")
# ⚠️ Sale IMPRESO en tres capturas, así que tiene que parecer un colegio de
# verdad. Lo que lo identifica como desechable NO es el nombre: es el correo
# de quien lo registró, que termina en @siga.test.
NOMBRE_DE_PRUEBA = "U E P CENTRO EDUCATIVO SANTA ROSA DE LIMA".freeze
CORREO_DE_PRUEBA = "manual#{SELLO}@siga.test".freeze
visit "/registrarse"
fill_in "user[first_name]", with: "Daniel"
fill_in "user[last_name]",  with: "Moros"
fill_in "user[email]",      with: CORREO_DE_PRUEBA
fill_in "user[password]",   with: "123123"
fill_in "user[password_confirmation]", with: "123123"
fill_in "school[name]", with: NOMBRE_DE_PRUEBA
check "nivel_preescolar"
check "nivel_primaria"
check "nivel_secundaria"
click_button "Crear mi colegio"
sleep 2.5

# ⚠️ ALTA: esta pantalla es un resumen largo —grados, materias, años, lapsos— y
# a 900 px se corta justo donde empieza «Lo que sigue».
foto("arranque_listo", "/arranque/listo", alto: 1080)
foto("plan_de_arranque", "/dashboards/administrador", alto: 1800)

# La franja aparece al entrar a un paso DESDE el plan: el `?recorrido=` se
# consume, se guarda en una cookie y la URL queda limpia.
foto("franja_de_arranque", "/materias?recorrido=materias")

# ⚠️ Y se recoge lo que se ensució. Cada corrida registra un colegio, y a la
# tercera la base de desarrollo tiene tres que nadie pidió — `bin/ci` los
# enumera y hay que borrarlos a mano.
#
# Se borra por CORREO DEL REGISTRADOR, no por nombre: el nombre es el de un
# colegio creíble —sale impreso en las capturas— y podría ser el de alguien.
puts "── limpieza"
system("bin/rails", "runner", File.expand_path("borrar_el_de_prueba.rb", __dir__),
       CORREO_DE_PRUEBA) || puts("  ✗ quedó «#{NOMBRE_DE_PRUEBA}» en la base")

puts "── dirección"
entrar("director.bolivar@mail.com")
foto("panel", "/dashboards/administrador")
foto("colegio", "/colegio")
foto("niveles", "/niveles")
foto("grados", "/grados")
foto("materias", "/materias")
foto("departamentos", "/departamentos")
foto("anios", "/academic_periods")
foto("lapsos", "/lapsos")
foto("secciones", "/secciones")
foto("seccion_nueva", "/secciones/new")
foto("alumnos", "/alumnos")
foto("alumno_nuevo", "/alumnos/new")
foto("alumno_ficha", "/alumnos/#{ALU}")
foto("representantes", "/representantes")
foto("representante_ficha", "/representantes/#{REP}")
foto("profesores", "/profesores")
foto("administradores", "/administradores")
foto("inscripciones", "/inscripciones")
foto("inscribir", "/inscripciones/new")
foto("importar", "/importaciones")
foto("importar_nuevo", "/importaciones/new?tipo=matricula")
foto("importar_pegar", nil, espera: 0.3) { click_on "Pegar la lista"; sleep 0.8 }
foto("boletines", "/boletines")
foto("constancias", "/constancias")
foto("rubrica", "/rubrica")
foto("auditoria", "/dashboards/actividad")
foto("cuenta", "/cuenta")
foto("buscar", "/alumnos?q=lopez")
foto("copiar_estructura", "/academic_periods/#{ANIO_NUEVO}/copiar")
foto("promover", "/academic_periods/#{ANIO_NUEVO}/promover")
foto("asistencia_reporte", "/asistencia/reporte")
foto("carga_de_notas", "/carga-de-notas")
foto("informes", "/secciones/#{PRIM}/informes")
foto("seccion_alumnos", "/secciones/#{PRIM}/alumnos")
foto("resumen_final", "/secciones/#{MED}/alumnos")

puts "── profesor"
entrar(PROF)
foto("profe_panel", "/dashboards/profesor")
foto("profe_libreta", "/secciones/#{PRIM}?area=241")
foto("profe_planificar", "/secciones/#{PRIM}/planificar?area=241")
foto("profe_notas", "/evaluaciones/#{ACT}/notas")
foto("profe_asistencia", "/secciones/#{PRIM}/asistencia")
foto("profe_ficha_alumno", "/secciones/#{PRIM}/alumnos/#{INS}")

# El plan entero no cabe en 900 px: la competencia, sus indicadores y las
# evaluaciones que la miden son lo que hay que enseñar, y quedaban cortadas.
foto("plan_competencias", "/secciones/#{PRIM}/planificar?area=241", alto: 1150)

# Una sección SIN plan: el estado vacío explica qué es una competencia y qué es
# un indicador, que es justo lo que hay que enseñar.
foto("plan_vacio", "/secciones/#{SIN_PLAN}/planificar?area=241")

puts "── Educación Inicial"
entrar(PROFINI)
foto("inicial_calificar", "/secciones/#{INI}")
foto("inicial_alumnos", "/secciones/#{INI}/alumnos")

puts "── representante"
entrar("maria.perez@familia.test")
foto("familia", "/representante")

puts "── alumno"
entrar("alvaro.lopez001@bolivar.edu")
foto("alumno_portal", "/dashboards/estudiante")
foto("alumno_notas", "/dashboards/notas")

puts "══ listo"
