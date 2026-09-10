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

    # Los cuatro niveles de encabezado, y qué dice cada uno.
    #
    # ⚠️ Hasta la etapa ② esto era un INVENTARIO DE DEUDA: siete formas de
    # título, y la mayoritaria servía para dos cosas distintas separadas solo
    # por qué etiqueta escribió cada quien. Ahora hay una sola pieza —
    # `shared/cabecera`— y `nivel:` es una decisión que se toma, no un descuido
    # que se hereda.
    TITULOS = [
      { nivel: "H1", como: 'render "shared/cabecera", titulo: "Alumnos"',
        que_dice: "Qué es esta PANTALLA. Una sola por pantalla, y es lo que un " \
                  "lector de pantalla anuncia como encabezado de nivel 1." },
      { nivel: "H2", como: 'render "shared/cabecera", titulo: "El colegio", nivel: 2',
        que_dice: "Qué es esta TARJETA, dentro de una pantalla que ya tiene su H1." },
      { nivel: "detalle", como: 'render "shared/cabecera", titulo: "…", detalle: "1er Grado A · Matemática"',
        que_dice: "Dónde estoy parado. Acompaña al título sin competir con él." },
      { nivel: "detalle destacado", como: "…, detalle_destacado: true",
        que_dice: "Invierte el peso: en «Competencias e indicadores» el título dice " \
                  "lo mismo siempre y el detalle es lo que hay que leer rápido." }
    ].freeze

    def index
      @tonos   = TONOS
      @titulos = TITULOS
    end
  end
end
