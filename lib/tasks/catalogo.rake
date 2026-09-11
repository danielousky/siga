# El catálogo de planteles del MPPE, que se siembra de un CSV versionado.
#
#     bin/rails catalogo:planteles
#
# ⚠️ El archivo vive en `db/catalogos/planteles.csv` y se versiona CON el
# código, no se descarga al desplegar. Un catálogo que se baja en el arranque
# hace que el registro dependa de que un tercero esté en pie — y el registro es
# la puerta del producto.
#
# Actualizarlo es reemplazar el archivo y volver a correr esto. Ninguna pantalla
# cambia.
namespace :catalogo do
  ARCHIVO = Rails.root.join("db/catalogos/planteles.csv")

  desc "Siembra el catálogo de planteles desde db/catalogos/planteles.csv"
  task planteles: :environment do
    unless File.exist?(ARCHIVO)
      abort "✗ No está #{ARCHIVO.relative_path_from(Rails.root)}"
    end

    filas = CSV.read(ARCHIVO, headers: true)
    puts "· Leyendo #{filas.size} planteles…"

    # ⚠️ Se borra y se vuelve a escribir, en una transacción.
    #
    # Un catálogo actualizado puede QUITAR planteles —un colegio que cerró— y
    # actualizar fila por fila los dejaría ahí para siempre. Y dentro de una
    # transacción porque a mitad de camino el catálogo estaría partido, que es
    # peor que el viejo entero.
    PlantelOficial.transaction do
      PlantelOficial.delete_all

      filas.each_slice(1_000) do |tanda|
        PlantelOficial.insert_all!(tanda.filter_map { |fila| fila_a_plantel(fila) })
      end
    end

    puts "✓ #{PlantelOficial.count} planteles · #{PlantelOficial.where.not(dea_code: nil).count} con código DEA"
  end

  # ⚠️ `insert_all!` NO dispara callbacks, así que `busqueda` se calcula acá.
  # Es a propósito: sembrar dieciséis mil filas de a una tarda un minuto largo.
  def fila_a_plantel(fila)
    nombre = fila["nombre"].to_s.strip
    return nil if nombre.blank?

    entidad = fila["estado"].to_s.strip.presence
    ahora = Time.current

    { dea_code: fila["dea"].to_s.strip.presence,
      nombre: nombre,
      entidad_federal: entidad,
      busqueda: [ Normaliza.para_comparar(nombre), Normaliza.para_comparar(entidad) ].compact_blank.join(" "),
      created_at: ahora, updated_at: ahora }
  end
end
