# Los bancos de Venezuela, con el código de cuatro dígitos que usan el pago
# móvil y las transferencias (spec: `docs/specs/pagos-de-la-familia.md`).
#
# Daniel: *«el banco de origen, que debe ser un list… debe llevar los bancos
# venezolanos»*.
#
# ## ⚠️ Se guarda el CÓDIGO, no el nombre
#
# Los bancos se fusionan, se renombran y cambian de marca; el código de cuatro
# dígitos lo asigna el sistema de pagos y sobrevive a todo eso. Guardar «Banco
# Occidental de Descuento» deja un dato que dentro de tres años no se puede
# casar con nada; guardar «0116» sigue siendo el mismo banco aunque se llame
# distinto.
#
# ## ⚠️ Y por eso la lista no es una tabla
#
# No la edita nadie, no cambia sin un despliegue del BCV de por medio, y una
# tabla obligaría a sembrarla en cada colegio. Es una constante, como
# `GradoOficial`.
class Banco
  # En el orden en que la gente los busca: primero los grandes.
  TODOS = {
    "0102" => "Banco de Venezuela",
    "0134" => "Banesco",
    "0105" => "Mercantil",
    "0108" => "BBVA Provincial",
    "0191" => "BNC · Banco Nacional de Crédito",
    "0114" => "Bancaribe",
    "0115" => "Banco Exterior",
    "0175" => "Banco Bicentenario",
    "0163" => "Banco del Tesoro",
    "0172" => "Bancamiga",
    "0174" => "Banplus",
    "0171" => "Banco Activo",
    "0151" => "BFC · Banco Fondo Común",
    "0138" => "Banco Plaza",
    "0104" => "Venezolano de Crédito",
    "0128" => "Banco Caroní",
    "0137" => "Sofitasa",
    "0157" => "DelSur",
    "0156" => "100 % Banco",
    "0168" => "Bancrecer",
    "0169" => "Mi Banco",
    "0146" => "Bangente",
    "0166" => "Banco Agrícola de Venezuela",
    "0177" => "Banfanb"
  }.freeze

  CODIGOS = TODOS.keys.freeze

  class << self
    # Lo que come un `select`: «0102 · Banco de Venezuela».
    def para_elegir = TODOS.map { |codigo, nombre| [ "#{codigo} · #{nombre}", codigo ] }

    # ⚠️ Devuelve el código cuando no lo conoce, en vez de nil. Un banco que no
    # esté en la lista —uno nuevo, o una fusión que no alcanzamos a cargar— no
    # puede hacer desaparecer el dato de la pantalla de la oficina.
    def nombre(codigo) = TODOS[codigo.to_s] || codigo.to_s

    def conocido?(codigo) = TODOS.key?(codigo.to_s)
  end
end
