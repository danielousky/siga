require "test_helper"

# Cada controlador del colegio está en UNA lista de la frontera de lo gratis
# (`RespetaLaSuscripcion`, spec `docs/specs/del-registro-al-cobro.md`).
#
# ## Por qué existe
#
# La lista de lo que pide la suscripción se escribió el 27 de agosto de 2026
# nombrando lo que existía ese día, y todo lo que se construyó después quedó
# afuera sin que nada avisara: cerrar el lapso —que emite boletines y les
# escribe a las familias—, reparaciones, valoraciones de Inicial, informes,
# la cobranza, la descarga del boletín, las listas en Excel y los correos. Con
# un preescolar se operaba completo sin pagar, y ningún test lo veía porque
# ninguno sabía que esos controladores existían.
#
# Ahora quien agrega un controlador tiene que decidir dónde va. No decidirlo no
# pasa el CI.
class FronteraDeLoGratisTest < ActiveSupport::TestCase
  LISTAS = {
    "SIEMPRE_ABIERTO"      => RespetaLaSuscripcion::SIEMPRE_ABIERTO,
    "LA_ENTRADA"           => RespetaLaSuscripcion::LA_ENTRADA,
    "CON_SUSCRIPCION"      => RespetaLaSuscripcion::CON_SUSCRIPCION,
    "SOLO_CON_SUSCRIPCION" => RespetaLaSuscripcion::SOLO_CON_SUSCRIPCION
  }.freeze

  # Los controladores a los que se llega por una ruta y que pasan por la
  # frontera: los que heredan de `ApplicationController`. Los de `/siga`, los de
  # Active Storage y los de Rails no la cruzan —no tienen colegio—.
  def controladores_del_colegio
    Rails.application.routes.routes.filter_map { |ruta| ruta.defaults[:controller] }.uniq.select do |nombre|
      clase = "#{nombre.camelize}Controller".safe_constantize
      clase && clase < ApplicationController
    end.sort
  end

  test "cada controlador del colegio está en una lista de la frontera" do
    sin_lista = controladores_del_colegio.reject { |nombre| LISTAS.values.any? { |lista| lista.include?(nombre) } }

    assert_empty sin_lista,
                 "Sin lista, en gratis queda CERRADO —es la red—, pero esto es una decisión " \
                 "que alguien tiene que tomar. ¿Es entrada, operar o salida?\n  #{sin_lista.join("\n  ")}"
  end

  test "y en una sola" do
    en_dos = controladores_del_colegio.select { |nombre| LISTAS.values.count { |lista| lista.include?(nombre) } > 1 }

    assert_empty en_dos, "Un controlador en dos listas se comporta según cuál se mire primero:\n  #{en_dos.join("\n  ")}"
  end

  # Una lista que nombra un controlador que ya no existe es una lista que nadie
  # revisa: el día que vuelva a existir, con otro trabajo, entra clasificado
  # por error.
  test "y ninguna lista nombra un controlador que no existe" do
    fantasmas = LISTAS.values.flatten - controladores_del_colegio

    assert_empty fantasmas, "Estas listas nombran controladores sin ruta:\n  #{fantasmas.join("\n  ")}"
  end

  # ⚠️ La plantilla del importador es el único archivo que sale sin suscripción.
  # Si deja de existir, la excepción quedaría abriendo otra cosa con su nombre.
  test "el archivo libre existe" do
    RespetaLaSuscripcion::ARCHIVOS_LIBRES.each do |controlador, accion|
      clase = "#{controlador.camelize}Controller".constantize

      assert clase.action_methods.include?(accion), "#{controlador}##{accion} ya no existe"
    end
  end
end
