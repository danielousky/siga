module Siga
  # El catálogo vivo del sistema de diseño.
  #
  # ## Por qué existe
  #
  # Daniel, 8 de septiembre de 2026: *«ayer hice una captura de por lo menos
  # cinco tipos de títulos principales. Eso es inconcebible… un framework vale,
  # nuestro propio framework… que ya automáticamente diga
  # `%table.table.table-condense` y coloque la tabla como es. No tengas que
  # estar pensando tú: cómo hago la tabla, qué borde le pongo».*
  #
  # La auditoría le dio la razón por más: contó cinco títulos y hay **siete**,
  # más dos escritos a mano con `style:` inline. Y el diagnóstico no era que
  # faltara el framework —hay 709 clases en 9.548 líneas— sino que **era
  # opcional**: la cabecera correcta la usaban 14 pantallas de 84.
  #
  # ## ⚠️ El catálogo se dibuja con los HELPERS DE VERDAD
  #
  # Ni una línea de HTML escrita a mano acá. Un catálogo copiado es una octava
  # forma de hacer las cosas —la peor, porque además dice ser la buena—, y el
  # día que `boton` cambie, la muestra seguiría mostrando lo de antes.
  #
  # Por eso la vista llama a `boton`, a `cabecera_de_lista` y a `icono` igual
  # que cualquier pantalla: si algo se rompe, se rompe acá primero.
  #
  # ## Y por qué vive en /siga y no en /estilo
  #
  # Decisión de Daniel: *«solo el equipo de SIGA»*. Heredando de
  # `Siga::BaseController` la puerta ya está puesta —un director rebota con «No
  # tienes acceso a esta sección»— y no hay que escribir ninguna autorización
  # nueva. Está en producción y se puede mirar desde el teléfono, que es la
  # mitad del punto: los tonos hay que verlos donde se van a usar.
  class EstiloController < BaseController
    # Los seis tonos, con el verbo que le da nombre a cada uno.
    #
    # ⚠️ Vive acá y no en la vista para que el test pueda recorrerlo: la lista
    # de tonos es la definición del sistema, y una vista no se puede preguntar.
    TONOS = [
      { tono: :guardar,   verbo: "Queda guardado",   ejemplo: "Agregar",
        icono: :agregar,  cuando: "El alta, el submit de un formulario, «Guardar cambios». " \
                                  "El + es lo único que dice «y además nace algo nuevo»." },
      { tono: :accion,    verbo: "Mucho de una vez", ejemplo: "Copiar de otro año",
        icono: :calendario, cuando: "Copiar la estructura, promover alumnos, confirmar una " \
                                  "importación de 360 filas, cargar las notas de una sección." },
      { tono: :documento, verbo: "Algo sale",        ejemplo: "Emitir y descargar",
        icono: :descargar, cuando: "Un papel que el colegio entrega: boletín, constancia, " \
                                   "la forma 31059." },
      { tono: :ver,       verbo: "Mirar sin tocar",  ejemplo: "Ver",
        icono: :ver,      cuando: "Ir al detalle. Suave a propósito: aparece una vez por " \
                                  "fila y en sólido convierte un listado en una pared." },
      { tono: :secondary, verbo: "Volver atrás",     ejemplo: "Volver",
        icono: :volver,   cuando: "Cancelar, limpiar un filtro, volver al listado." },
      { tono: :danger,    verbo: "Destruye",         ejemplo: "Eliminar",
        icono: :borrar,   cuando: "Sin tono de color: se señala por peso y posición, porque " \
                                  "en SIGA un número en rojo es un niño aplazado (MOR-135)." }
    ].freeze

    # ⚠️ Las SIETE formas de título que hay hoy. Es un inventario de deuda, no
    # un catálogo aprobado — la unificación es la etapa ②, y meterla acá sería
    # inventar clases que todavía no existen.
    #
    # Se lista igual porque es exactamente lo que Daniel vio en su captura, y
    # verlo junto es lo que hace evidente el problema: siete maneras de decir
    # «esto es esta pantalla».
    TITULOS_DE_HOY = [
      { clase: "card-academic-header > h1", usos: 110,
        donde: "El mayoritario. Un h1 pelado dentro de un div: sin detalle, " \
               "sin controles, sin nada." },
      { clase: "cabecera-de-lista-titulo", usos: 14,
        donde: "El bueno. Trae título, detalle, buscador, filtros, importador " \
               "y el [+ Agregar] con su tooltip." },
      { clase: "acceso-titulo", usos: 6, donde: "Las pantallas de Devise." },
      { clase: "arranque-listo-titulo", usos: 5, donde: "El arranque de un colegio nuevo." },
      { clase: "ficha-nombre", usos: 4, donde: "Las fichas de persona." },
      { clase: "solicitud-titulo", usos: 2, donde: "El sitio público." },
      { clase: "portada-tesis", usos: 1, donde: "La portada del PDF." },
      { clase: "style= inline", usos: 2,
        donde: "⚠️ Georgia y #1e4a7a escritos a mano dentro de la vista. " \
               "El caso más grave, y son dos líneas." }
    ].freeze

    def index
      @tonos   = TONOS
      @titulos = TITULOS_DE_HOY
    end
  end
end
