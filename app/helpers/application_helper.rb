module ApplicationHelper
  include Pagy::Frontend

  # Los métodos de rol y autorización están definidos en ApplicationController
  # y expuestos a las vistas vía helper_method

  # Plural en español, con las dos formas escritas a mano.
  #
  # `String#pluralize` de Rails usa el inflector INGLÉS, y la app está en español.
  # A veces coincide por casualidad —"alumno" → "alumnos"— y a veces no:
  #
  #     "boletín".pluralize(3)  # => "boletíns"   ✗
  #     "lápiz".pluralize(2)    # => "lápizs"     ✗
  #     "profesor".pluralize(2) # => "profesors"  ✗
  #
  # Que funcione en las palabras terminadas en vocal es lo peligroso: se usa sin
  # pensar, y el día que la palabra termina en consonante o lleva tilde sale un
  # texto roto en pantalla. Acá las dos formas van explícitas.
  #
  #     pluralizar(3, "boletín", "boletines")  # => "boletines"
  #     pluralizar(1, "boletín", "boletines")  # => "boletín"
  def pluralizar(cantidad, singular, plural)
    cantidad == 1 ? singular : plural
  end

  # Lo mismo con el número adelante: "3 boletines", "1 boletín".
  def contar(cantidad, singular, plural)
    "#{cantidad} #{pluralizar(cantidad, singular, plural)}"
  end

  # Los grados del colegio, agrupados por nivel, para un desplegable.
  #
  # ⚠️ `Grade.order(:name)` los revuelve, y en un colegio que dicta los tres
  # niveles el resultado es ilegible:
  #
  #     1er Año · 1er Grado · 1er Nivel · 2do Año · 2do Grado · 2do Nivel · …
  #
  # Tres escaleras distintas intercaladas. `en_orden` arregla la secuencia
  # —preescolar, primaria, bachillerato— pero sin los rótulos de nivel la lista
  # sigue siendo veintiún renglones seguidos: hay que agrupar para poder leer.
  #
  #     Preescolar     1er Nivel · 2do Nivel · 3er Nivel
  #     Primaria       1er Grado · … · 6to Grado
  #     Bachillerato   1er Año · … · 6to Año
  #
  # ⚠️ Y respeta el NIVEL DE LA SESIÓN. Era la queja exacta de Daniel: *«puede
  # ser confuso crear una sección y que me aparezcan preescolar, primaria y
  # bachillerato juntos»*. Con «Primaria» elegido arriba, el desplegable trae
  # seis grados y ningún rótulo de grupo, porque no hay nada que agrupar.
  #
  # Va acá y no en cada controller a propósito: son cuatro desplegables —el
  # filtro de secciones, el de inscripciones, el alta de sección y el que venga—
  # y el que se olvide es el que va a ofrecer «5to Año» en una sesión de
  # primaria.
  #
  # ⚠️ `incluyendo:` es el grado que el registro YA tiene, y en un formulario de
  # EDICIÓN no es opcional. Una sección de bachillerato abierta desde una sesión
  # parada en primaria mostraría un desplegable sin su propio grado: quedaría en
  # «Seleccione…» y guardar la dejaría sin ninguno.
  #
  # El nivel de la sesión es una preferencia de quien mira. No puede borrar un
  # dato, y esa es la línea entre esto y un `default_scope`.
  def grados_por_nivel(grados = nil, incluyendo: nil)
    grados = (grados || Grade.del_nivel_de_la_sesion.en_orden).to_a
    grados = (grados + [ incluyendo ]).sort_by { |g| g.orden || 99 } if incluyendo && grados.exclude?(incluyendo)

    grados.group_by(&:level).map do |nivel, del_nivel|
      [ GradoOficial.etiqueta(nivel),
        del_nivel.map { |g| [ g.name, g.id ] } ]
    end
  end

  # "15 de septiembre" — día y mes, sin el año.
  #
  # `l(fecha, format: :long)` agrega el año y `:short` abrevia el mes ("15 de
  # sep"). En la barra de contexto el año ya lo dice el nombre del período, así
  # que repetirlo es ruido.
  def dia_y_mes(fecha)
    "#{fecha.day} de #{I18n.t('date.month_names')[fecha.month]}"
  end

  # La calificación del AÑO, escrita según la escala del grado (MOR-129).
  #
  #     nota_del_ano(19, grado)   # media general → "19"
  #     nota_del_ano(19, grado)   # primaria      → "A (19)"
  #
  # Solo para las notas del AÑO. Las de lapso llevan la rúbrica que definió el
  # colegio (`MOR-136`) —«PA (17)»— y no el literal A–E: son dos vocabularios
  # sobre la misma escala, y el que el colegio eligió es el suyo.
  def nota_del_ano(nota, grado)
    EscalaLiteral.mostrar(nota, escala: grado&.escala) || "—"
  end

  # Cómo se escribe la relación del período con el día de hoy.
  #
  # Importa no mentir acá: en agosto no hay año escolar corriendo, y una barra
  # que dijera "activo" estaría afirmando algo falso sobre el colegio. Es el
  # mismo error que tenía el rótulo anterior, que anunciaba un dato y no lo traía.
  def situacion_del_periodo(periodo)
    case periodo.situacion
    when :en_curso     then "en curso"
    when :por_comenzar then "comienza el #{dia_y_mes(periodo.start_date)}"
    when :finalizado   then "finalizado el #{dia_y_mes(periodo.end_date)}"
    end
  end

  # El año escolar que le tocaría a un colegio hoy, para prellenar el formulario
  # de rescate del importador.
  #
  # En Venezuela va de mediados de septiembre a mediados de julio. Si estamos
  # antes de agosto seguimos dentro del año que empezó el septiembre pasado; de
  # agosto en adelante, el que arranca ahora.
  def ano_escolar_sugerido(hoy = Date.current)
    inicio = hoy.month >= 8 ? hoy.year : hoy.year - 1

    {
      nombre: "#{inicio}-#{inicio + 1}",
      desde: Date.new(inicio, 9, 15),
      hasta: Date.new(inicio + 1, 7, 31)
    }
  end

  # Marca el campo que falló, en los formularios escritos con `*_tag` (MOR-196).
  #
  # ## Por qué hace falta un helper y no lo pone Rails
  #
  # Rails envuelve en `.field_with_errors` los campos de un `form_for` atado a
  # un modelo. Los formularios que crean DOS cosas a la vez —el colegio y su
  # ubicación, el usuario y su rol— se escriben con `text_field_tag`, que no
  # sabe de ningún objeto: ahí Rails no marca nada.
  #
  # ⚠️ Y eso es lo que hizo invisible un error de verdad. Daniel: *«me faltó el
  # Código DEA y no me arrojó error, sino que me volvió a cargar la página»*. El
  # error SÍ estaba —el resumen rojo arriba del formulario, con «Código DEA no
  # puede estar en blanco»— pero el campo culpable se veía exactamente igual que
  # los otros ocho. En un formulario largo, un resumen sin campos marcados se
  # lee como si la página se hubiera recargado sola.
  #
  #     = text_field_tag "school[dea_code]", @colegio.dea_code,
  #                      class: clase_de_campo(@colegio, :dea_code)
  def clase_de_campo(objeto, campo, base: "form-control")
    return base if objeto.nil? || objeto.errors[campo].empty?

    "#{base} campo-con-error"
  end

  # ¿El modelo EXIGE este campo? (MOR-201)
  #
  # ## Por qué se deduce y no se escribe
  #
  # Daniel, creando un colegio con todo vacío: *«el form no validó los campos,
  # me permitió guardar sin decir los campos requeridos (todos)»*. Y era cierto:
  # **ni un solo formulario de la app declaraba `required`**. El servidor
  # rechazaba y pintaba el error, pero el navegador dejaba enviar — un viaje de
  # ida y vuelta para enterarse de algo que se sabía antes de salir.
  #
  # Escribir `required: true` a mano funciona el primer día y se despareja el
  # segundo: alguien afloja una validación del modelo y el asterisco se queda, o
  # agrega una y el campo sigue dejando pasar. Preguntándole al modelo, las dos
  # capas no pueden discrepar.
  #
  # ⚠️ Una presencia CONDICIONAL no cuenta. `validates :x, presence: true, if:
  # ...` significa «a veces», y marcar el campo como obligatorio siempre
  # impediría enviar el formulario justo en el caso en que no lo es. Igual con
  # `on: :create` en un formulario de edición.
  #
  # ⚠️ Y `required` NO reemplaza la validación del modelo: es la capa que evita
  # el viaje. Lo que llega por la API, por el importador o con el JavaScript
  # apagado lo sigue atajando el modelo. Son las mismas tres capas que
  # `campo-filtrado`.
  def requerido?(clase, atributo)
    clase.validators_on(atributo).any? do |validador|
      validador.is_a?(ActiveModel::Validations::PresenceValidator) &&
        validador.options.values_at(:if, :unless, :on, :allow_nil, :allow_blank).all?(&:blank?)
    end
  end

  # Un botón con su icono, en una línea (MOR-202).
  #
  # Daniel: *«debería haber un helper para los botones de primary que le pases
  # solo el ícono, name y title (opcional) y pinte los botones»*.
  #
  # Estaba escrito a mano en cada vista, siempre igual y siempre con la
  # posibilidad de escribirlo distinto:
  #
  #     = link_to ruta, class: "btn btn-primary" do
  #       = icono(:agregar, tamano: 16)
  #       %span Registrar alumno
  #
  # ⚠️ El `%span` alrededor del texto NO es decorativo y es lo que más se
  # olvidaba: sin él, el `gap` del botón no separa el icono de la palabra
  # —un nodo de texto suelto no es un ítem flex— y quedan pegados.
  #
  # El tamaño del icono tampoco se pasa: 16 px es el de un botón y 15 el de uno
  # `btn-sm`, y tenerlo acá evita el botón con el icono de otro tamaño.
  #
  #     = boton "Registrar alumno", new_student_path, icono: :agregar
  #     = boton "Copiar de otro año", ruta, icono: :copiar, tono: :accion, sm: true
  #     = boton "Años escolares", ruta, icono: :calendario, tooltip: "Crear y editar"
  def boton(nombre, ruta, icono:, tono: :primary, sm: false, tooltip: nil, **opciones)
    clases = [ "btn", "btn-#{tono}", ("btn-sm" if sm) ].compact.join(" ")
    datos = opciones.delete(:data) || {}
    datos = datos.merge(tooltip: tooltip) if tooltip

    link_to ruta, class: clases, data: datos, **opciones do
      safe_join([ icono(icono, tamano: sm ? 15 : 16), tag.span(nombre) ])
    end
  end

  # El botón que lleva a subir una planilla.
  #
  # ⚠️ Existe para que el nombre, el destino, el icono y el tono se escriban UNA
  # vez. Estaban repetidos en nueve vistas y ya habían divergido en los cuatro:
  # tres nombres para el pensum, dos iconos (uno con la flecha al revés) y algún
  # `tono: :secondary` suelto.
  #
  # El tono es `accion` (índigo) por MOR-172: una planilla carga trescientas
  # filas de una vez y «Agregar» carga una — que se distingan es el punto de esa
  # regla.
  def boton_de_importar(tipo, tono: :accion, **opciones)
    boton Importacion.accion_de(tipo), new_importacion_path(tipo: tipo),
          icono: :subir, tono: tono, **opciones
  end

  # Qué banda de notas cubre un nivel de la rúbrica (MOR-136).
  #
  # ⚠️ El TOPE no se guarda: se deduce del nivel de arriba. Con `valor` como
  # piso y una lista ordenada, las bandas quedan contiguas por construcción —
  # no puede haber un 16 sin nivel ni un 17 que caiga en dos. Guardar el tope
  # sería un segundo lugar donde vive la misma verdad, y el día que alguien
  # mueva un piso sin mover el tope de al lado, la boleta saca un renglón en
  # blanco y nadie se entera.
  def cobertura_de_la_rubrica(rubrica, todas)
    piso = rubrica.valor
    return "—" if piso.blank?

    pisos = todas.reject { |r| r.marked_for_destruction? }
                 .filter_map(&:valor).map(&:to_i).uniq.sort
    siguiente = pisos.find { |v| v > piso.to_i }
    tope = siguiente ? siguiente - 1 : NOTA_MAXIMA

    piso.to_i == tope ? "solo #{tope}" : "#{piso} a #{tope}"
  end

  # Un panel con pestañas, de los que alternan sin navegar (MOR-223).
  #
  #     = con_paneles [["Alumnos", "alumnos", 22], ["Áreas", "areas"]] do
  #       = panel_de "alumnos" do
  #         …
  #       = panel_de "areas" do
  #         …
  #
  # ⚠️ El primero de la lista es el que se ve al cargar, así que el ORDEN es
  # una decisión: va primero lo que más se usa, no lo que primero se escribió.
  def con_paneles(paneles, etiqueta: nil, &bloque)
    tag.div(class: "paneles-grupo", data: { controller: "paneles" }) do
      concat render("shared/paneles", paneles: paneles, etiqueta: etiqueta)
      concat capture(&bloque)
    end
  end

  # ⚠️ `hidden` lo pone el CONTROLADOR al conectar, no el servidor.
  #
  # Si el servidor escondiera todos menos el primero y Stimulus no cargara, la
  # pantalla mostraría un tercio de su contenido sin manera de llegar al resto.
  # Saliendo todos visibles, el fallo devuelve la pantalla de antes —apilada,
  # con scroll— que es incómoda pero completa.
  def panel_de(clave, &bloque)
    tag.section(class: "panel-contenido", id: "panel-#{clave}",
                role: "tabpanel", "aria-labelledby": "pestana-#{clave}",
                data: { paneles_target: "panel", panel: clave }, &bloque)
  end

  # El 20 del Artículo 108: es el techo de la escala, no una preferencia.
  NOTA_MAXIMA = 20
end
