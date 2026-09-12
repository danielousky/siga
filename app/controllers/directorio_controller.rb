# El directorio público de planteles de Venezuela.
#
#     /colegios                          los estados
#     /colegios/miranda                  sus municipios
#     /colegios/miranda/baruta           los planteles de ese municipio
#     /colegios/miranda/baruta/u-e-…     la ficha de uno
#
# ## Para qué existe
#
# Es la única palanca real de tráfico orgánico que tiene SIGA. Una portada sola
# no rankea —una página no compite con nada— pero «colegios en Baruta» y
# «código DEA del colegio San José» son lo que un director escribe en Google, y
# hoy lo contestan directorios ajenos con una tabla fea.
#
# El catálogo que compilamos son 13.434 planteles ubicables: miles de páginas
# **útiles, únicas y ciertas**, que traen a alguien ya interesado y lo dejan a
# un clic de registrar su colegio.
#
# Decisión de Daniel: *«el costo es bajo y lo sacamos de la web (público),
# entonces considero que podemos publicarlo»*.
#
# ## ⚠️ Son páginas de verdad, no un buscador con JavaScript
#
# Un buscador que muestra resultados al escribir no lo indexa nadie: para
# Google no existe lo que aparece después de un evento. Cada nivel tiene que
# ser una URL con su título, su `<h1>` y su texto, **enlazada desde la de
# arriba**. Eso es lo que rankea, y es por lo que esto es un controller con
# cuatro acciones y no un `select` en cascada.
#
# ## ⚠️ Los slugs se resuelven comparando, no con una columna
#
# No hay migración ni columna `slug`. El estado sale de comparar el
# `parameterize` contra las veinticuatro entidades, y el municipio contra los
# quince que tenga ese estado — listas cortas y en memoria. La única búsqueda
# contra la base es el plantel, por su código.
#
# Una columna de slugs habría que mantener al día con cada actualización del
# catálogo, y el catálogo se actualiza reemplazando un CSV.
class DirectorioController < ApplicationController
  skip_before_action :authenticate_user!
  skip_around_action :con_el_colegio_de_la_sesion

  before_action :set_estado, only: [ :estado, :municipio, :plantel ]
  before_action :set_municipio, only: [ :municipio, :plantel ]
  before_action :set_plantel, only: [ :plantel ]

  # Los estados, con cuántos planteles tiene cada uno.
  def index
    @por_estado = planteles.group(:entidad_federal).count
                           .each_with_object(Hash.new(0)) do |(nombre, cuantos), mapa|
      mapa[EntidadFederal.normalizar(nombre) || nombre] += cuantos
    end.sort_by { |entidad, _| Normaliza.para_comparar(entidad).to_s }
    @total = @por_estado.sum(&:last)
  end

  def estado
    @por_municipio = de_la_entidad(@estado).group(:municipio).count
                                           .sort_by { |municipio, _| Normaliza.para_comparar(municipio).to_s }
    @total = @por_municipio.sum(&:last)
  end

  def municipio
    # ⚠️ Ordenado por nombre y NO paginado. El municipio más grande —Libertador,
    # 436 planteles— cabe en una página, y partir una lista en cinco le quita a
    # cada trozo el texto que la hace encontrable: cuatro de cada cinco páginas
    # quedarían con veinte nombres y nada más.
    @planteles = de_la_entidad(@estado).where(municipio: @municipio)
                                       .order(Arel.sql("lower(nombre)"))
    @parroquias = DivisionPolitica.parroquias_de(@estado, @municipio)
  end

  def plantel
    @otros = de_la_entidad(@estado).where(municipio: @municipio)
                                   .where.not(id: @plantel.id)
                                   .order(Arel.sql("lower(nombre)")).limit(12)
  end

  private

  # ⚠️ Sin aislamiento: `planteles_oficiales` no es de ningún colegio —es de la
  # plataforma— y esta pantalla la ve quien no tiene sesión. Ver la migración.
  def planteles = PlantelOficial.publicables

  # ⚠️ Se consulta por las DOS escrituras de la entidad, con y sin tilde: en el
  # catálogo conviven «Bolívar» y «Bolivar». Buscar solo la normalizada perdería
  # los planteles de la otra mitad, en silencio y sin que nada falle.
  def de_la_entidad(entidad)
    escrituras = planteles.distinct.pluck(:entidad_federal).select do |escrita|
      EntidadFederal.normalizar(escrita) == entidad
    end
    planteles.where(entidad_federal: escrituras.presence || entidad)
  end

  def set_estado
    @estado = EntidadFederal::TODAS.find { |e| e.parameterize == params[:estado] }
    raise ActiveRecord::RecordNotFound if @estado.nil?
  end

  def set_municipio
    @municipio = DivisionPolitica.municipios_de(@estado)
                                 .find { |m| m.parameterize == params[:municipio] }
    raise ActiveRecord::RecordNotFound if @municipio.nil?
  end

  # ⚠️ Se comprueba que el plantel esté DONDE DICE LA URL. Sin eso,
  # `/colegios/zulia/maracaibo/<slug de uno de Mérida>` respondería 200 con la
  # ficha correcta bajo un municipio que no es el suyo: dos URL para la misma
  # página, que es justo lo que el canonical existe para evitar.
  def set_plantel
    @plantel = PlantelOficial.por_slug(params[:plantel])
    raise ActiveRecord::RecordNotFound if @plantel.nil?
    raise ActiveRecord::RecordNotFound if @plantel.entidad != @estado
    raise ActiveRecord::RecordNotFound if @plantel.municipio != @municipio
  end
end
