# Qué niveles dicta el colegio, y con eso sus grados (MOR-153, MOR-154).
#
# ## La pantalla que borra catorce formularios
#
# Antes, un director recién llegado creaba sus grados uno por uno: catorce veces
# escribir un nombre y elegir un nivel en un desplegable. Catorce formularios
# para escribir información que **no es suya** — la fija el Reglamento de la LOE
# y es idéntica en los 3.900 colegios del país.
#
# Acá marca hasta tres casillas.
#
# ## ⚠️ Por qué pregunta la escala de primaria en la MISMA pantalla
#
# Crear seis grados de primaria de un golpe es elegir, sin decirlo, que todos
# sus boletines salgan por literales. Hay colegios de primaria que califican del
# 1 al 20, y ese colegio se enteraría **en diciembre**, con los boletines
# impresos. La pregunta cuesta un renglón acá y una reimpresión allá.
#
# Bachillerato no se pregunta: por reglamento es siempre numérico.
class NivelesController < ApplicationController
  before_action :require_direccion!

  def edit
    @colegio = Current.school
    @niveles = @colegio.niveles
    @grados = Grade.en_orden.to_a
  end

  def update
    @colegio = Current.school
    resultado = SembrarGrados.para(@colegio, niveles: params[:niveles])
    aplicar_escala_de_primaria(resultado.creados)

    redirect_to dashboards_administrador_path, notice: mensaje(resultado)
  end

  private

  # La escala solo se toca en los grados RECIÉN creados: un colegio que agrega
  # bachillerato dos años después no puede ver cómo le cambian la escala a una
  # primaria que ya tiene tres años de boletines emitidos.
  def aplicar_escala_de_primaria(creados)
    return unless params[:escala_de_primaria] == "numerica"

    creados.select(&:primaria?).each { |grado| grado.update!(escala: :numerica) }
  end

  def mensaje(resultado)
    return "No se creó ningún grado: marque al menos un nivel." if resultado.total.zero?

    if resultado.creados.empty?
      "Esos niveles ya estaban cargados. No se creó ningún grado nuevo."
    else
      "Listo: #{contar_grados(resultado.creados.size)} creados. " \
        "Ya puede armar las secciones de cada uno."
    end
  end

  def contar_grados(cuantos) = helpers.contar(cuantos, "grado", "grados")
end
