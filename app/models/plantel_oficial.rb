# Un plantel del catálogo del MPPE, para SUGERIR al registrarse.
#
#     PlantelOficial.buscar("san jose")
#     #=> [#<PlantelOficial nombre: "U.E.P. COLEGIO SAN JOSÉ", dea_code: "PD01234567">, …]
#
# ## ⚠️ Sugiere, no decide
#
# Daniel: *«lo que hablo es de SUGERIR, no quiere decir que sea la verdad;
# SIEMPRE podrá modificar los datos»*. Lo que esta tabla dice llena los campos
# y ahí termina su trabajo: manda lo que escriba quien se registra.
#
# El catálogo es público —el MPPE publica los códigos— pero lo compilamos
# nosotros y está incompleto. Que lo esté no puede costarle el registro a nadie:
# «mi colegio no está en la lista» es un camino de primera, no un rincón. Es la
# misma regla que `DivisionPolitica::OTRO`.
#
# ## Cómo se actualiza
#
# El catálogo vive en `db/catalogos/planteles.csv`, se versiona con el código y
# se siembra con `bin/rails catalogo:planteles`. Actualizarlo es reemplazar el
# archivo: ninguna pantalla cambia.
class PlantelOficial < ApplicationRecord
  self.table_name = "planteles_oficiales"

  # ⚠️ NO es `SchoolScoped`, a propósito. Ver la migración: quien se está
  # registrando todavía no tiene colegio, y es justo para él que existe esto.

  validates :nombre, presence: true

  before_validation :calcular_la_busqueda

  # Cuántos se ofrecen. Más de una docena deja de ser una sugerencia y pasa a
  # ser una lista que hay que leer entera.
  SUGERENCIAS = 8

  # ── El directorio público ─────────────────────────────────────────────────
  #
  # El catálogo es data pública que compilamos nosotros, y publicarlo es la
  # única palanca real de tráfico orgánico que tiene SIGA: «colegios en Baruta»
  # es lo que un director escribe en Google, y hoy lo contesta un directorio
  # ajeno. Decisión de Daniel: *«el costo es bajo y lo sacamos de la web
  # (público), entonces considero que podemos publicarlo»*.
  #
  # ⚠️ Solo se publica el que se puede UBICAR Y NOMBRAR: hacen falta el
  # municipio —o no hay dónde colgarlo en el árbol— y el código DEA, que es lo
  # que hace única su URL. Son 13.434 de 15.954. Los otros 2.520 siguen
  # sirviendo para sugerir al registrarse, que es para lo que se compilaron.
  scope :publicables, -> {
    where.not(municipio: [ nil, "" ]).where.not(dea_code: [ nil, "" ])
  }

  # ⚠️ El slug lleva el NOMBRE y el CÓDIGO, y los dos hacen falta.
  #
  # El nombre, porque una URL que se lee rankea y una de números no: quien
  # busca «colegio san josé baruta» tiene que reconocer el enlace. El código,
  # porque hay decenas de «U.E. Bolívar» y sin él dos colegios distintos
  # pelearían por la misma dirección.
  #
  #     u-e-p-colegio-san-jose-pd01234567
  #     └─────── nombre ────────┘└─ DEA ─┘
  # ⚠️ `nil` sin código: un plantel que no se publica no tiene URL, y devolver
  # una a medias —«colegio-de-prueba-»— haría que `por_slug` resolviera
  # cualquier cosa por la cola vacía.
  def slug = dea_code.present? ? "#{nombre.parameterize}-#{dea_code.downcase}" : nil

  # ⚠️ Se resuelve por el CÓDIGO, no por el nombre: el nombre del slug es
  # decoración para el buscador y puede cambiar —una tilde, una abreviatura— sin
  # que el enlace de nadie se rompa. Lo que identifica es la cola.
  def self.por_slug(slug)
    codigo = slug.to_s.rpartition("-").last
    return nil if codigo.blank?

    publicables.find_by(dea_code: codigo.upcase)
  end

  # ⚠️ La entidad se normaliza al leerla, y no es cosmética: en el catálogo
  # conviven «Bolívar» y «Bolivar», «Táchira» y «Tachira». Sin normalizar, el
  # directorio mostraría treinta estados y seis de ellos serían fantasmas.
  def entidad = EntidadFederal.normalizar(entidad_federal) || entidad_federal

  # ⚠️ Se busca PALABRA POR PALABRA, con AND entre ellas (`MOR-183`).
  #
  # «san jose caracas» tiene que encontrar al colegio aunque «caracas» esté en
  # otra parte del nombre. Con el término entero contra la columna, escribir más
  # dejaba de acotar y empezaba a no encontrar nada.
  #
  # ⚠️ Y cada palabra casa por PRINCIPIO DE PALABRA, no en cualquier parte.
  #
  # Con `LIKE '%san%'`, buscar «san jose» devolvía «José Manuel **Sán**chez
  # Ostos» — porque «Sánchez» contiene «san»— y empujaba fuera de las ocho
  # sugerencias a los colegios que de verdad se llaman San José. En una lista de
  # dieciséis mil, el ruido de las palabras cortas se come el resultado.
  #
  # Prefijo sí: quien escribe «colegi» tiene que encontrar «Colegio».
  def self.buscar(termino, limite: SUGERENCIAS)
    palabras = Normaliza.para_comparar(termino).to_s.split.reject(&:blank?)
    return none if palabras.empty?

    # ⚠️ Por CÓDIGO también, y era un agujero: quien tiene el papel del MPPE
    # delante escribe el código, no el nombre. Buscar «OD04890203» —un código
    # que está en la propia lista— no devolvía nada, porque `busqueda` solo
    # llevaba el nombre y el estado.
    #
    # Va como camino aparte y no mezclado en `busqueda`: con el código adentro,
    # escribir «pd» —que es prefijo de la mitad de los códigos privados— traería
    # miles de planteles que no tienen nada que ver con lo que se buscó.
    return por_codigo(palabras.join, limite) if parece_un_codigo?(palabras)

    consulta = palabras.reduce(all) do |scope, palabra|
      scope.where("busqueda LIKE :inicio OR busqueda LIKE :dentro",
                  inicio: "#{palabra}%", dentro: "% #{palabra}%")
    end

    consulta.order(Arel.sql(relevancia(palabras)), :nombre).limit(limite)
  end

  # Un código DEA es una o dos letras y una ristra de dígitos: «OD04890203».
  #
  # ⚠️ Se exigen al menos TRES dígitos para no confundirlo con un nombre. Hay
  # planteles que se llaman «Escuela 24 de Julio», y buscar «24» tiene que
  # seguir siendo una búsqueda por nombre.
  FORMA_DE_CODIGO = /\A[a-z]{0,2}\d{3,}\z/

  def self.parece_un_codigo?(palabras) = palabras.one? && palabras.first.match?(FORMA_DE_CODIGO)

  # Por PREFIJO, para que sirva mientras se teclea y para el que copió solo un
  # pedazo del código.
  def self.por_codigo(codigo, limite)
    where("LOWER(dea_code) LIKE ?", "#{codigo}%").order(:nombre).limit(limite)
  end
  private_class_method :parece_un_codigo?, :por_codigo

  # ⚠️ Primero los que casan la PALABRA ENTERA, y no es un lujo.
  #
  # «san» es prefijo de «Sánchez», así que ningún filtro por prefijo puede
  # separarlos: buscar «san jose» traía «José Manuel **Sán**chez Ostos» y
  # empujaba fuera de las ocho sugerencias a los colegios que de verdad se
  # llaman San José. Lo que los separa no es filtrar más: es ORDENAR.
  #
  # Cada palabra que casa entera suma uno. El que casa las dos va arriba del que
  # casa una.
  def self.relevancia(palabras)
    sumandos = palabras.map do |palabra|
      sanitize_sql_array([
        "(CASE WHEN busqueda LIKE ? OR busqueda LIKE ? OR busqueda = ? THEN 1 ELSE 0 END)",
        "#{palabra} %", "% #{palabra} %", palabra
      ])
    end

    "(#{sumandos.join(' + ')}) DESC"
  end
  private_class_method :relevancia

  # Cómo se ve en la lista de sugerencias: «Distrito Capital · privado».
  def procedencia
    [ entidad_federal, municipio, dependencia ].compact_blank.join(" · ")
  end

  # ⚠️ La PRIMERA letra del código dice de quién depende el plantel, y sale
  # gratis: `P` privado, `O` oficial. Es lo que distingue a dos colegios que se
  # llaman parecido en el mismo municipio.
  DEPENDENCIAS = { "P" => "privado", "O" => "oficial" }.freeze

  def dependencia = DEPENDENCIAS[dea_code.to_s[0]]

  private

  def calcular_la_busqueda
    self.busqueda = [ Normaliza.para_comparar(nombre), Normaliza.para_comparar(entidad_federal) ]
                      .compact_blank.join(" ")
  end
end
