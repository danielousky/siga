require "test_helper"

# Que cada controlador declarado en `index.js` exista, y al revés.
#
# ## Por qué vale un test propio
#
# Un `import` que no resuelve **mata la aplicación Stimulus entera**, no solo su
# controlador: el módulo falla al cargar y ninguno se registra. El síntoma es
# que pantallas que no tienen nada que ver dejan de funcionar —el filtro de la
# barra, el borrado en línea, el campo con error— y nada apunta al archivo que
# falta.
#
# Pasó el 5 de septiembre de 2026: un heredoc que no llegó a escribirse dejó
# `carga_informes_controller.js` sin crear mientras `index.js` ya lo importaba.
# Ocho tests de sistema fallaron en pantallas ajenas antes de que se viera.
#
# ⚠️ Y el registro es MANUAL (importmap, sin Node): no hay nada que descubra los
# archivos solo, así que las dos listas se desparejan sin que nadie avise.
class ControladoresDeStimulusTest < ActiveSupport::TestCase
  INDICE  = Rails.root.join("app/javascript/controllers/index.js")
  CARPETA = Rails.root.join("app/javascript/controllers")

  test "cada import de index.js tiene su archivo" do
    faltantes = importados.reject { |nombre| CARPETA.join("#{nombre}.js").exist? }

    assert_empty faltantes,
                 "`index.js` importa controladores que no existen: #{faltantes.join(', ')}. " \
                 "Un import roto NO falla solo: mata la aplicación Stimulus entera y con ella " \
                 "todas las pantallas con JavaScript."
  end

  test "cada controlador de la carpeta está registrado" do
    en_disco = Dir[CARPETA.join("*_controller.js")].map { |ruta| File.basename(ruta, ".js") }
    sin_registrar = en_disco - importados

    assert_empty sin_registrar,
                 "estos controladores existen y nadie los registra en `index.js`, así que " \
                 "Stimulus nunca los conecta y su `data-controller` no hace nada: " \
                 "#{sin_registrar.join(', ')}"
  end

  # ⚠️ El nombre del registro tiene que coincidir con el del archivo, en kebab:
  # `application.register("carga-notas", …)` ↔ `carga_notas_controller.js`. Si
  # no coinciden, el archivo carga, el controlador se registra con otro nombre,
  # y el `data-controller` de la vista no encuentra nada — en silencio.
  test "el nombre registrado coincide con el del archivo" do
    desparejos = registros.reject do |nombre, clase|
      esperado = clase.sub(/Controller\z/, "").underscore.tr("_", "-")
      nombre == esperado
    end

    assert_empty desparejos,
                 "el nombre con el que se registran no coincide con su clase: #{desparejos.inspect}"
  end

  private

  def indice = @indice ||= INDICE.read

  # `import CargaNotasController from "controllers/carga_notas_controller"`
  def importados
    indice.scan(/from\s+["']controllers\/([\w\/]+)["']/).flatten
  end

  # `application.register("carga-notas", CargaNotasController)`
  def registros
    indice.scan(/application\.register\(\s*["']([\w-]+)["']\s*,\s*(\w+)\s*\)/).to_h
  end
end
