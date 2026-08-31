# El municipio y la parroquia escritos a mano, cuando no están en el catálogo.
#
# ## Por qué esto vive en un concern y no en cada controller
#
# Los tres formularios que cargan un colegio —el registro abierto, el alta desde
# el panel de SIGA y la ficha que edita el director— comparten el mismo parcial
# de ubicación. Si la traducción del «no está en la lista» se escribiera en cada
# uno, el día que cambie el catálogo van a quedar dos controllers guardando
# `__otro__` como si fuera el nombre de un municipio.
#
# ## ⚠️ Y por qué el texto libre existe
#
# `DivisionPolitica` está incompleto y se escribió sin fuente oficial. Un
# catálogo equivocado **no puede impedirle a un colegio registrarse**: uno que no
# puede registrarse no vuelve. La lista acelera al que está adentro; el texto
# libre es la salida del que no.
module NormalizaLaUbicacion
  extend ActiveSupport::Concern

  private

  # Deja `municipio` y `parroquia` con el nombre que corresponde, venga del
  # desplegable o del campo de texto, y borra los campos auxiliares para que
  # nunca lleguen a `permit` ni a la base.
  def con_la_ubicacion_resuelta(atributos)
    limpios = atributos.to_h

    %w[municipio parroquia].each do |campo|
      libre = limpios.delete("#{campo}_libre")
      next unless limpios[campo] == DivisionPolitica::OTRO

      # `presence`: si eligió «no está en la lista» y no escribió nada, el campo
      # queda VACÍO —que es la verdad— y no con la cadena centinela ni con un
      # `""` que después se imprime como un renglón en blanco en un documento.
      limpios[campo] = libre.to_s.strip.presence
    end

    limpios
  end
end
