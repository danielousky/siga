# Lo que necesitan las pantallas de pagos.
module PagosHelper
  # ⚠️ Con el punto de miles y la coma decimal, que es como se escribe en
  # Venezuela: «1.250,00 $». `number_to_currency` con el locale por defecto
  # pondría «$1,250.00», que se lee al revés — y en una pantalla de dinero eso
  # no es un detalle de estilo.
  #
  # ⚠️ Y el símbolo va DETRÁS, separado. Delante es la convención gringa; acá el
  # precio se dice «cuarenta y cinco dólares».
  def numero_en_dolares(monto) = importe(monto, unidad: "$")

  # ⚠️ Al REPRESENTANTE se le muestra el número sin unidad.
  #
  # Daniel: *«hay un vacío legal en el país que en este momento se está
  # discutiendo… lo más salomónico es ocultarle al representante la unidad de
  # pago»*. En la práctica el colegio expresa sus cuentas en dólares y la
  # familia transfiere en bolívares; mientras eso no esté resuelto, SIGA no
  # afirma una moneda que no puede respaldar.
  #
  # ⚠️ Adentro SÍ lleva el «$»: es la unidad de cuenta del colegio, y quien
  # cobra tiene que verla para poder avalar la equivalencia.
  def importe_para_la_familia(monto) = importe(monto, unidad: nil)

  # Lo que dice el VOUCHER: bolívares, porque es lo que se transfirió.
  #
  # ⚠️ Y no se compara con lo que se debe. Son monedas distintas, y quien hace
  # el puente es la persona de finanzas al validar: avalar un pago ES decir
  # «estos bolívares cubren estos dólares». Por eso SIGA no guarda ninguna tasa
  # —no le hace falta— y el día que se resuelva el vacío legal no hay nada que
  # migrar: la equivalencia siempre estuvo en el acto de validar.
  def importe_transferido(monto) = importe(monto, unidad: "Bs")

  private

  def importe(monto, unidad:)
    numero = number_with_precision(monto.to_f, precision: 2, separator: ",", delimiter: ".")
    unidad ? "#{numero} #{unidad}" : numero
  end

  public

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
