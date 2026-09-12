# Municipios y parroquias de Venezuela (MOR-159).
#
# ## Por qué existe
#
# La entidad federal ya era una lista cerrada. El municipio y la parroquia eran
# campos de texto, y eso produce «Libertador», «Mcpio. Libertador» y «LIBERTADOR»
# para el mismo lugar — en datos que salen IMPRESOS en los documentos del MPPE.
#
# Escribir a mano es el último recurso, no el primero: se elige el estado y el
# municipio se despliega solo.
#
# ## De dónde salen los datos (11 de septiembre de 2026)
#
# Del **INE**, que es la fuente oficial: la División Político Territorial, con
# sus códigos `EEMMPP` —entidad, municipio, parroquia—. Se bajó del servicio
# público de la DPT y vive en `db/catalogos/division_politica.csv`.
#
#     24 entidades · 334 municipios · 1.123 parroquias
#
# ⚠️ Hasta hoy este catálogo **estaba escrito de memoria** y el comentario que
# había acá lo admitía: «no se contrastó contra una fuente oficial… puede tener
# nombres mal escritos, municipios que faltan y parroquias que no están. Antes
# de dar esto por bueno: bajar el catálogo del INE y reemplazar el hash». Es
# justo lo que se hizo, y la estructura no cambió — por eso ninguna pantalla se
# tocó.
#
# ⚠️ `OTRO` SIGUE EXISTIENDO, y no por desconfianza del INE: la DPT cambia
# —se crean municipios y parroquias— y un catálogo que envejece nunca puede
# impedirle a un colegio registrarse. Ese sigue siendo el modo de fallar que hay
# que evitar: un colegio que no puede registrarse no vuelve.
#
# ⚠️ Y por eso también los nombres pasan por `EntidadFederal.normalizar`: el
# INE escribe «Falcón» y una planilla importada puede traer «EDO. FALCON». Lo
# que se guarda es siempre el nombre canónico.
class DivisionPolitica
  OTRO = "__otro__".freeze

  CATALOGO = Rails.root.join("db/catalogos/division_politica.csv")

  # entidad => { municipio => [parroquias] }
  #
  # ⚠️ Se arma UNA vez, al cargar la clase. Son 1.123 filas: leerlas en cada
  # petición sería trabajo repetido para un dato que no cambia hasta el próximo
  # despliegue.
  MUNICIPIOS = begin
    require "csv"

    CSV.read(CATALOGO, headers: true).each_with_object({}) do |fila, mapa|
      entidad = EntidadFederal.normalizar(fila["estado"]) || fila["estado"]
      municipio = fila["municipio"].to_s.strip
      next if municipio.blank?

      parroquias = (mapa[entidad] ||= {})[municipio] ||= []
      parroquia = fila["parroquia"].to_s.strip
      parroquias << parroquia if parroquia.present?
    end.tap do |mapa|
      # Sin municipios propios, pero es una entidad federal y el selector la
      # ofrece: quien la elija escribe su municipio a mano.
      mapa["Dependencias Federales"] ||= {}
    end.freeze
  end

  # código `EEMM` → { entidad, municipio }. Lo arma del mismo CSV.
  POR_CODIGO = begin
    require "csv"

    CSV.read(CATALOGO, headers: true).each_with_object({}) do |fila, mapa|
      entidad = EntidadFederal.normalizar(fila["estado"]) || fila["estado"]
      mapa[fila["co_parroquia"].to_s[0, 4]] ||= { entidad: entidad, municipio: fila["municipio"].to_s.strip }
    end.freeze
  end

  # Los estados que tienen UN SOLO municipio. Distrito Capital y La Guaira, y
  # eso importa: ahí el MPPE numera subdivisiones propias —02, 03, 04, 05— que
  # no son municipios, y todas caen igual en el único que hay.
  DE_UN_SOLO_MUNICIPIO = POR_CODIGO.group_by { |codigo, _| codigo[0, 2] }
                                   .select { |_, ms| ms.map { |_, d| d[:municipio] }.uniq.one? }
                                   .transform_values { |ms| ms.first.last }
                                   .freeze

  class << self
    # Dónde queda un plantel, según su código DEA.
    #
    #     ubicacion_del_codigo("OD04890203")  #=> { entidad: "Amazonas", municipio: "Atures" }
    #
    # ⚠️ Devuelve `nil` si el código no corresponde a ningún municipio oficial.
    # Nunca adivina: un municipio equivocado que se ve plausible es peor que
    # ninguno, porque nadie corrige lo que no nota.
    # ⚠️ Un código COMPLETO, y por eso el largo mínimo: leyendo los cuatro
    # últimos de un código a medio escribir sale una ubicación cualquiera —
    # «PD0515» daría Aragua/Urdaneta, que no tiene nada que ver.
    LARGO_MINIMO_DEL_DEA = 8

    def ubicacion_del_codigo(dea)
      codigo = dea.to_s.strip
      return nil if codigo.length < LARGO_MINIMO_DEL_DEA

      cola = codigo[-4, 4]
      return nil if cola.blank? || !cola.match?(/\A\d{4}\z/)

      POR_CODIGO[cola] || DE_UN_SOLO_MUNICIPIO[cola[0, 2]]
    end

    def municipios_de(entidad) = MUNICIPIOS.fetch(entidad.to_s, {}).keys

    def parroquias_de(entidad, municipio)
      MUNICIPIOS.dig(entidad.to_s, municipio.to_s) || []
    end

    # Lo que come el JavaScript del desplegable en cascada: un solo objeto, sin
    # una petición por cada cambio de estado. Son ~20 KB — menos que un icono.
    def como_json_para_el_navegador = MUNICIPIOS.to_json

    # ⚠️ Nunca se rechaza un lugar que no esté en el catálogo. Ver la nota de
    # arriba: el catálogo está incompleto y no puede impedir un registro.
    def conocido?(entidad, municipio) = municipios_de(entidad).include?(municipio.to_s)
  end
end
