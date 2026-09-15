# Lo que necesitan las pantallas de pagos.
module PagosHelper
  # ⚠️ Con el punto de miles y la coma decimal, que es como se escribe en
  # Venezuela: «1.250,00 $». `number_to_currency` con el locale por defecto
  # pondría «$1,250.00», que se lee al revés — y en una pantalla de dinero eso
  # no es un detalle de estilo.
  #
  # ⚠️ Y el símbolo va DETRÁS, separado. Delante es la convención gringa; acá el
  # precio se dice «cuarenta y cinco dólares».
  def numero_en_dolares(monto)
    number_to_currency(monto.to_f, unit: "$", format: "%n %u",
                                   separator: ",", delimiter: ".", precision: 2)
  end

  # El color del estado de un cobro.
  #
  # ⚠️ El color lo lleva el DATO, nunca el control (§ regla de color, MOR-135).
  # Acá el dato es «este mes está pagado / vencido / esperando», y por eso son
  # pastillas de texto y no botones de colores.
  TONOS = { pagado: "estado-pagado", en_revision: "estado-en-revision",
            en_mora: "estado-en-mora", por_vencer: "estado-por-vencer" }.freeze

  ETIQUETAS = { pagado: "Pagado", en_revision: "En revisión",
                en_mora: "Vencido", por_vencer: "Por vencer" }.freeze

  def pastilla_de_cobro(cobro)
    estado = cobro.estado
    tag.span(ETIQUETAS.fetch(estado), class: "pastilla-de-cobro #{TONOS.fetch(estado)}")
  end

  ESTADOS_DEL_REPORTE = { "en_revision" => "En revisión", "validado" => "Validado",
                          "rechazado" => "Rechazado" }.freeze

  def pastilla_de_reporte(reporte)
    tag.span(ESTADOS_DEL_REPORTE.fetch(reporte.estado, reporte.estado),
             class: "pastilla-de-cobro estado-#{reporte.estado.dasherize}")
  end

  # ⚠️ El calendario del reporte NO ofrece el año pasado.
  #
  # Daniel: *«el calendario no debe incluir fechas del año pasado… del último
  # mes hacia adelante»*. Se acota en el propio `<input type="date">`, así que
  # el dedazo de año —«03/09/2025» en vez de 2026— no llega ni a enviarse.
  def limites_del_calendario_de_pago
    { min: PaymentReport.desde, max: PaymentReport.hasta }
  end
end
