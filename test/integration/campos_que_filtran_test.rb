require "test_helper"

# Un `campo-filtrado` sin su `action` no filtra NADA (MOR-170).
#
# ## Por qué esto es un test y no un comentario
#
# `filtrar` es un método: alguien tiene que llamarlo. El controlador se conecta,
# limpia UNA vez lo que venía escrito, y después se queda mirando. Sin
# `input->campo-filtrado#filtrar`:
#
#     · el atributo `data-controller` está
#     · el `permite-value` está
#     · Stimulus conecta sin quejarse
#     · y se puede teclear «1.0.}+}}+QWE@@¡"£¡.∞ÑÑÑ.»
#
# Nada falla. No hay error de consola, no hay excepción, no hay log. Se descubre
# escribiendo en el campo — Daniel lo encontró así, en el de referencia de un
# pago.
#
# ⚠️ Y se mira el HTML, no el navegador, a propósito: un test de sistema prueba
# UN campo, y lo que hace falta es que NINGUNO se quede sin su acción. Son seis
# hoy y van a ser más.
class CamposQueFiltranTest < ActiveSupport::TestCase
  VISTAS = Rails.root.join("app/views")

  test "todo campo con campo-filtrado declara su action" do
    sin_accion = campos_filtrados.reject { |_, texto| texto.include?("campo-filtrado#filtrar") }

    assert_empty sin_accion.map(&:first),
      "campos que declaran `campo-filtrado` y NO lo llaman: el controlador se " \
      "conecta, no filtra nada y nadie se entera.\n  " +
      sin_accion.map(&:first).join("\n  ")
  end

  # ⚠️ Lo primero: comprobar que se está comprobando algo. Si el buscador deja
  # de encontrar campos —porque cambió el nombre del controlador— el test de
  # arriba pasaría sin mirar ninguno.
  test "la lista de campos filtrados no está vacía" do
    assert_operator campos_filtrados.size, :>=, 4,
                    "no se encontró ningún campo con `campo-filtrado`: ¿cambió el nombre?"
  end

  private

  # Cada declaración de `campo-filtrado` con el trozo de vista que la rodea.
  #
  # ⚠️ Se mira la LÍNEA LÓGICA, no la física: un `text_field` con ocho opciones
  # se parte en varias líneas, y el `action` suele quedar en la última.
  def campos_filtrados
    Dir[VISTAS.join("**/*.haml")].flat_map do |vista|
      lineas_logicas(File.read(vista)).filter_map.with_index do |trozo, i|
        [ "#{vista.delete_prefix(VISTAS.to_s + '/')}:#{i + 1}", trozo ] if declara_el_controlador?(trozo)
      end
    end
  end

  # Junta con la anterior toda línea que continúa una llamada: la que empieza
  # con un argumento suelto o la que cierra un hash.
  def lineas_logicas(fuente)
    fuente.lines.each_with_object([]) do |linea, juntas|
      if juntas.any? && linea.match?(/\A\s+[a-z_]+:|\A\s*[}\)]/) && !linea.strip.start_with?("-#")
        juntas[-1] += linea
      else
        juntas << linea
      end
    end
  end

  # ⚠️ Solo donde se DECLARA, no donde se menciona: los comentarios del propio
  # `sections/_form` explican el controlador y no son campos.
  def declara_el_controlador?(trozo)
    trozo.include?("campo-filtrado") &&
      trozo.match?(/controller:\s*"campo-filtrado"|controller:\s*'campo-filtrado'/)
  end
end
