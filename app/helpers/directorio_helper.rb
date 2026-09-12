# Lo que necesitan las cuatro pantallas del directorio público.
module DirectorioHelper
  # ⚠️ Los nombres del catálogo vienen con la caja del MPPE, que es un desastre
  # —«Batalla De La Victoria», «U.E.P. COLEGIO SAN JOSE»— y así salen en el
  # `<title>` y en el `<h1>`, que es lo que se lee en un resultado de búsqueda.
  #
  # `Normaliza.titulo` es la misma que ya arregla los nombres de las personas al
  # importar una planilla: respeta las siglas y baja las preposiciones.
  def plantel_en_titulo(nombre) = Normaliza.titulo(nombre)

  # El registro con el colegio ya puesto.
  #
  # ⚠️ Es el remate de todo el directorio: quien llegó a Google buscando su
  # propio colegio abre el formulario con el nombre y el código DEA llenos. Son
  # los dos campos que el catálogo rellena cuando alguien escribe el nombre a
  # mano en el registro — acá se saltan ese paso porque ya sabemos cuál es.
  #
  # ⚠️ Y siguen siendo EDITABLES, como todo lo que viene del catálogo: manda lo
  # que escriba quien se registra, no lo que diga la lista.
  def registrarse_ruta_con(plantel)
    new_user_registration_path(school: { name: plantel_en_titulo(plantel.nombre),
                                         dea_code: plantel.dea_code })
  end
end
