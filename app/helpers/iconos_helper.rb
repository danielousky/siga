# Los iconos de SIGA (MOR-149).
#
# ## Por qué un helper y no una gema
#
# El proyecto no tiene Node ni bundler de JavaScript —usa importmap— así que
# `heroicon`, `phosphor-rails` y compañía traen una cadena de dependencias para
# resolver algo que son treinta rutas SVG. Y una gema de iconos agrega un archivo
# de 400 KB del que se usa el 8 %.
#
# ## Por qué inline y no un sprite ni <img>
#
# Un `<img>` no hereda `currentColor`, así que un icono dentro de un botón azul
# tendría que ser otro archivo que el mismo icono dentro de un enlace gris. Con
# SVG en el HTML, el icono toma el color del texto que acompaña y no hay que
# pensar en eso nunca más.
#
# El costo es peso en el HTML: ~250 bytes por icono, ~5 KB en una pantalla con
# veinte. Contra una petición HTTP por archivo y el parpadeo mientras carga, es
# el intercambio correcto para colegios con conexiones lentas.
#
# ## Accesibilidad: un icono no habla solo
#
#     icono(:alumnos)                          decorativo, va al lado de texto
#     icono(:alumnos, titulo: "Alumnos")   ES el nombre del control
#
# Por defecto son `aria-hidden`, porque el caso normal es un icono al lado de una
# palabra: leerlo dos veces le hace perder tiempo a quien usa lector de pantalla.
# Cuando el icono va SOLO —un botón sin texto— hay que pasarle `titulo:`, y ahí
# deja de estar oculto y gana su propio rol.
#
# ## El trazo, y por qué es una sola familia
#
# Todos comparten `viewBox 0 0 24 24`, trazo de 1.7 y puntas redondeadas. Es el
# estilo de Phosphor y Heroicons outline, y mezclarlo con iconos rellenos o de
# otro grosor se nota inmediatamente: la pantalla se ve armada con recortes.
module IconosHelper
  TRAZO = 1.7
  LADO = 20

  # ⚠️ Las claves van en español, como todo lo que se lee en una vista.
  #
  # Un `icono(:students)` dentro de una vista que dice "Alumnos" obliga a
  # traducir mentalmente en cada línea, y el resto del proyecto ya decidió que
  # las vistas hablan español.
  CAMINOS = {
    # ── el menú ─────────────────────────────────────────────────────────────
    panel: '<rect x="3" y="3" width="7" height="9" rx="1"/><rect x="14" y="3" width="7" height="5" rx="1"/>' \
           '<rect x="14" y="12" width="7" height="9" rx="1"/><rect x="3" y="16" width="7" height="5" rx="1"/>',
    alumnos: '<circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.3 2.7-5.5 6-5.5s6 2.2 6 5.5"/>' \
             '<path d="M17 11h4M19 9v4"/>',
    asistencia: '<rect x="3" y="4" width="18" height="17" rx="2"/><path d="M8 2v4M16 2v4M3 10h18"/>' \
                '<path d="m9 15 2 2 4-4"/>',
    inasistencias: '<rect x="3" y="4" width="18" height="17" rx="2"/><path d="M8 2v4M16 2v4M3 10h18"/>' \
                   '<path d="m10 15 4 4M14 15l-4 4"/>',
    boletines: '<path d="M5 3h14v18H5z"/><path d="M9 8h6M9 12h6M9 16h3"/>',
    constancias: '<path d="M12 3 3 8l9 5 9-5-9-5Z"/><path d="M7 11v5c0 1.7 2.2 3 5 3s5-1.3 5-3v-5"/>',
    secciones: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
    inscripciones: '<path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>' \
                   '<rect x="9" y="2" width="6" height="4" rx="1"/><path d="m9 14 2 2 4-4"/>',
    profesores: '<circle cx="12" cy="7" r="3.2"/><path d="M5 21c0-3.9 3.1-6.5 7-6.5s7 2.6 7 6.5"/>',
    representantes: '<path d="M12 21s-7-4.5-7-10a7 7 0 0 1 14 0c0 5.5-7 10-7 10Z"/><circle cx="12" cy="11" r="2.4"/>',
    # ⚠️ UN solo glifo para la flecha que sube, y va HACIA ARRIBA.
    #
    # Había DOS claves para esto —`subir` e `importar`— y la de `importar`
    # apuntaba la flecha hacia ABAJO: era `descargar` con otro nombre. Daniel,
    # señalando el importador: *«el ícono de flecha es hacia arriba»*.
    #
    # Importar es SUBIR un archivo. Con las dos claves conviviendo, la misma
    # acción se dibujaba de dos maneras según qué vista la pintara, y una de
    # las dos era idéntica a la acción contraria.
    subir: '<path d="M12 21V9M7 14l5-5 5 5"/><path d="M4 3h16"/>',
    notas: '<path d="M4 4h16v16H4z"/><path d="M4 9h16M9 4v16"/>',
    materias: '<path d="M4 4h11a3 3 0 0 1 3 3v13H7a3 3 0 0 1-3-3z"/><path d="M18 7h2v13H8"/>',
    grados: '<path d="M4 20V9l8-5 8 5v11"/><path d="M9 20v-6h6v6"/>',
    lapsos: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/>',
    calendario: '<rect x="3" y="4" width="18" height="17" rx="2"/><path d="M8 2v4M16 2v4M3 10h18"/>',
    colegio: '<path d="M3 10 12 3l9 7v10a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
    auditoria: '<path d="M12 3v4M12 17v4M3 12h4M17 12h4"/><circle cx="12" cy="12" r="4.5"/>',
    # Un engranaje de cuatro dientes, no de doce: a 18 px los doce se ven como
    # una mancha y la ruta ocupa doce líneas de código.
    configuracion: '<circle cx="12" cy="12" r="3.2"/>' \
                   '<path d="M12 2v3M12 19v3M22 12h-3M5 12H2"/>' \
                   '<path d="m18.4 5.6-2.1 2.1M7.7 16.3l-2.1 2.1M18.4 18.4l-2.1-2.1M7.7 7.7 5.6 5.6"/>',

    # ── las acciones ────────────────────────────────────────────────────────
    agregar: '<path d="M12 5v14M5 12h14"/>',
    editar: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>',
    borrar: '<path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2"/>' \
            '<path d="M19 6v14a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V6"/><path d="M10 11v6M14 11v6"/>',
    buscar: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    guardar: '<path d="M5 13l4 4L19 7"/>',
    descargar: '<path d="M12 3v12M7 10l5 5 5-5"/><path d="M4 21h16"/>',
    imprimir: '<path d="M7 8V3h10v5"/><rect x="3" y="8" width="18" height="8" rx="2"/><path d="M7 14h10v7H7z"/>',
    ver: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
    siguiente: '<path d="M5 12h14M13 6l6 6-6 6"/>',
    volver: '<path d="M19 12H5M11 18l-6-6 6-6"/>',
    cerrar: '<path d="M18 6 6 18M6 6l12 12"/>',
    filtrar: '<path d="M4 6h16M7 12h10M10 18h4"/>',
    correo: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>',
    llave: '<circle cx="8" cy="15" r="4"/><path d="m11 12 8-8 2 2-2 2 2 2-3 3-2-2-2 2"/>',
    salir: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="M16 17l5-5-5-5M21 12H9"/>',

    # ── los estados ─────────────────────────────────────────────────────────
    ok: '<circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/>',
    alerta: '<path d="M12 3 2 20h20L12 3Z"/><path d="M12 9v4M12 17h.01"/>',
    error: '<circle cx="12" cy="12" r="9"/><path d="M12 8v5M12 16h.01"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
    pendiente: '<circle cx="12" cy="12" r="9"/><path d="M12 8v4l2.5 2"/>'
  }.freeze

  # ⚠️ Un icono que no existe NO revienta la página.
  #
  # Un `icono(:inventado)` en una vista secundaria tumbaría una pantalla entera
  # por un adorno. Devuelve `nil` —el hueco se nota, la pantalla vive— y en
  # desarrollo además grita en el log para que se arregle antes de subir.
  def icono(nombre, titulo: nil, tamano: LADO, clase: nil)
    camino = CAMINOS[nombre.to_sym]

    if camino.nil?
      Rails.logger.warn("[iconos] no existe el icono :#{nombre}") unless Rails.env.production?
      return nil
    end

    tag.svg(camino.html_safe,
            class: [ "icono", clase ].compact.join(" "),
            width: tamano, height: tamano, viewBox: "0 0 24 24",
            fill: "none", stroke: "currentColor",
            "stroke-width": TRAZO, "stroke-linecap": "round", "stroke-linejoin": "round",
            **rol_accesible(titulo))
  end

  # Un icono decorativo se oculta; uno que carga el significado lo declara.
  def rol_accesible(titulo)
    return { "aria-hidden": "true", focusable: "false" } if titulo.blank?

    { role: "img", "aria-label": titulo }
  end

  # Un enlace de menú: icono + palabra, con el icono siempre decorativo porque
  # la palabra ya está ahí.
  def enlace_con_icono(texto, ruta, nombre_del_icono, **opciones)
    link_to ruta, **opciones do
      safe_join([ icono(nombre_del_icono, tamano: opciones.delete(:tamano) || 18), tag.span(texto) ])
    end
  end
end
