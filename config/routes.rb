Rails.application.routes.draw do
  # ⚠️ LAS URLS VAN EN ESPAÑOL, EL CÓDIGO EN INGLÉS (MOR-162).
  #
  # `path:` es lo que separa las dos cosas, y no es un truco: es la opción que
  # Rails trae justamente para esto. `resources :students, path: "alumnos"` deja
  # el controller `StudentsController`, el helper `students_path` y el modelo
  # `Student` intactos, y le muestra `/alumnos` a la persona.
  #
  # ## El criterio, en una línea
  #
  # **Inglés donde Rails DEDUCE un nombre de otro. Español donde nadie deduce
  # nada.** Rails deduce en un solo lugar —modelo ↔ tabla ↔ asociación— y ahí el
  # inglés no es gusto: es lo que hace que el plural sea automático.
  #
  # En español no lo es, y no es opinión:
  #
  #     "seccion".pluralize     → "seccions"      ✗
  #     "profesor".pluralize    → "profesors"     ✗
  #     "materia".pluralize     → "materia"       ✗  (¡ni pluraliza!)
  #     "calificacion".pluralize → "calificacions" ✗
  #
  # Todo el modelo en español costaría una inflexión a medida por cada sustantivo
  # irregular —ya hay tres— más renombrar veintisiete tablas, y nada de eso lo ve
  # un director. Lo que sí ve es la barra de direcciones.

  # Dokku consulta esto antes de mandarle tráfico a un contenedor nuevo. Sin él,
  # un despliegue roto recibe usuarios igual.
  #
  # Va fuera de `authenticate_user!` y fuera de la protección de host: un health
  # check que necesita sesión o un `Host` correcto no sirve para nada.
  get "up", to: "rails/health#show", as: :rails_health_check

  # ⚠️ `/salud` NO reemplaza a `/up`, y no se pueden intercambiar (MOR-167).
  #
  #   /up     ¿arrancó el proceso web?      → lo mira DOKKU para dejar entrar
  #                                            una versión nueva
  #   /salud  ¿la cola está avanzando?      → lo mira un MONITOR externo
  #
  # Si Dokku mirara `/salud`, un worker caído impediría desplegar la corrección
  # que lo arregla.
  get "salud", to: "salud#show", as: :salud

  # ⚠️ NO hay registro público. Ver MOR-101.
  #
  # `:registerable` viene puesto por `rails generate devise User` y no es una
  # decisión: es el default. Pero en un SaaS vendido POR COLEGIO las cuentas
  # nacen de la matrícula o de la nómina, nunca de un formulario abierto en
  # internet. El colegio da de alta a su gente desde el panel — `/students/new`,
  # `/teachers/new`, `/admins/new`, que ya existen.
  #
  # El daño concreto no necesitaba ninguna sofisticación: `users.email` es único
  # en toda la plataforma, así que cualquiera podía **quemar** la dirección de un
  # profesor real registrándola antes que el colegio.
  #
  # Se salta `:registrations` entero y se devuelven a mano SOLO editar y
  # actualizar: un usuario tiene que poder cambiarse la contraseña estando
  # adentro. Lo que NO vuelve es `destroy` — que un alumno se borre a sí mismo de
  # un sistema académico no es una función, es una pérdida de datos.
  # ⚠️ La pantalla de contraseña de Devise redirige a `/activar/:token`.
  #
  # Son dos puertas a lo mismo con calidad distinta. La de Devise construye un
  # usuario EN BLANCO a partir del token y nunca carga la persona, así que no
  # puede decir de quién es la cuenta —"no sé de cuál usuario estoy
  # reseteando", textual— y ante un token vencido igual dibuja el formulario:
  # una trampa que solo falla al enviar.
  #
  # Va ANTES de `devise_for` porque gana la primera ruta que coincide.
  # 302 y no el 301 por defecto: la URL lleva un token de un solo uso, y un
  # navegador que cachee la redirección permanente se queda con el token viejo.
  get "users/password/edit",
      to: redirect(status: 302) { |_p, req| "/activar/#{req.params[:reset_password_token]}" }

  # ⚠️ El registro VUELVE a estar abierto (MOR-158), y revierte a `MOR-101`.
  #
  # Se cerró porque cualquiera podía quemar el correo de un profesor real
  # registrándolo antes que el colegio. Sigue siendo cierto, y se acepta: la
  # decisión de producto es **facilidad y velocidad de registro por encima de la
  # seguridad**, mientras el acceso sea compartir el enlace a mano y no haya
  # publicidad.
  #
  # Lo que hace que el riesgo sea tolerable es el aislamiento: registrarse crea
  # SIEMPRE un colegio nuevo, nunca se une a uno existente, así que el daño
  # máximo de un abuso es una fila que no ve nada de nadie.
  #
  # `destroy` NO vuelve: que alguien se borre a sí mismo de un sistema académico
  # no es una función, es una pérdida de datos.
  devise_for :users, skip: [:registrations],
                     controllers: { registrations: "registros" }

  devise_scope :user do
    get   "registrarse",   to: "registros#new",    as: :new_user_registration
    post  "registrarse",   to: "registros#create"
    # ⚠️ La comprobación del correo MIENTRAS se escribe (MOR-208). Daniel:
    # «tiene que ser una validación muy rápida… validamos de una vez allí si el
    # correo está correcto y no existe».
    get   "correo-disponible", to: "registros#correo_disponible", as: :correo_disponible
    get   "cuenta",        to: "devise/registrations#edit",   as: :edit_user_registration
    patch "cuenta",        to: "devise/registrations#update", as: :user_registration
    put   "cuenta",        to: "devise/registrations#update"
  end

  # ⚠️ `/mi-colegio/nuevo` YA NO EXISTE (MOR-208): el colegio se crea en el mismo
  # formulario del registro. Lo que queda es la pantalla que dice qué se creó.
  #
  # Daniel: *«el paso 2, que no lo ven, pero sí se debería decir: se ha
  # construido un andamiaje para su escuela… de modo que él sepa qué se creó»*.
  get "arranque/listo", to: "arranque#listo", as: :arranque_listo
  get "inicio/index"

  # Solicitudes de demo — SOLO lo público. Ver, listar y responder se mudó a
  # /siga (MOR-133): ese dato es de SIGA, no de ningún colegio, y vivir en el
  # panel del colegio lo dejó filtrándose tres veces.
  resources :demo_requests, only: [:new, :create] do
    collection do
      get :success
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # La administración de SIGA (MOR-133)
  # ═══════════════════════════════════════════════════════════════════════
  #
  # Otra app, adentro de esta por ahora. La decisión de Daniel fue "app aparte
  # en el mismo host de Dokku, si es posible; sino, inicialmente junto con la
  # principal" — y todavía no hay ningún despliegue funcionando (MOR-106), así
  # que duplicarlo antes de tener el primero sería pagar dos veces por nada.
  #
  # La frontera está puesta como si ya estuviera afuera: Siga::BaseController no
  # hereda de ApplicationController, tiene su propio layout, y adentro NO hay
  # colegio. Extraerlo el día que haya un Dokku andando es mover este bloque.
  namespace :siga do
    root "panel#index"
    resources :colegios, only: [:index, :show, :new, :create]
    resources :solicitudes, only: [:index, :show, :update]
    resources :cartera, only: [:index, :create, :update]
    resources :visitas, only: [:create, :destroy]

    # El catálogo vivo del sistema de diseño.
    #
    # ⚠️ Vive DENTRO de `/siga` a propósito, no en `/estilo`. Decisión de
    # Daniel: *«solo el equipo de SIGA»*. Colgando de `Siga::BaseController` la
    # puerta ya está puesta y no hay una autorización nueva que escribir — un
    # director rebota igual que en el resto del panel.
    get "estilo", to: "estilo#index"
  end

  # Dashboards específicos por rol
  namespace :dashboards do
    get "administrador", to: "administrador#index"
    get "profesor",      to: "profesor#index"
    get "estudiante",    to: "estudiante#index"
    get "notas",         to: "notas#index"
    resources :activity_logs, path: "actividad", only: [:index]
  end

  # Emisión de boletines (dirección y secretaría) y su verificación PÚBLICA.
  # La segunda va sin sesión a propósito: quien verifica normalmente no tiene
  # cuenta en el sistema. Ver MOR-98.
  resources :report_cards, only: [:index, :create], path: "boletines"

  # Constancias de estudio. NO se congelan como el boletín: certifican la
  # situación de hoy, no las calificaciones de un lapso. Ver el controller.
  resources :constancias, only: [:index, :create]
  # El año escolar que se está mirando (MOR-165). POST porque cambia el estado
  # de la sesión: un enlace se puede prefetchear o disparar desde otra pestaña.
  post "anio-escolar", to: "anio_escolar#update", as: :cambiar_anio_escolar
  post "nivel", to: "nivel_escolar#update", as: :cambiar_nivel
  # Los tres lapsos del año escolar, de un clic (MOR-163). Es la reparación de
  # los años creados ANTES de que el sembrado existiera, y el estado vacío de
  # `/lapsos` — que hasta ahora era una tabla sin filas y sin salida.
  post "lapsos/sembrar", to: "evaluation_moments#sembrar", as: :sembrar_lapsos

  # La planilla de reparación (MOR-168): la segunda oportunidad del Art. 112.
  #
  # Cuelga de la SECCIÓN y la MATERIA, que es como el profesor la piensa —«la
  # reparación de Matemática de 1er Año A»— y no de un `FinalGradeBook`, que es
  # una fila por alumno y no una pantalla.
  get   "reparaciones",                                     to: "reparaciones#index",  as: :reparaciones
  get   "reparaciones/:seccion_id/:materia_id",             to: "reparaciones#show",   as: :reparacion
  patch "reparaciones/:seccion_id/:materia_id/:student_id", to: "reparaciones#update", as: :nota_de_reparacion

  # Qué niveles dicta el colegio (MOR-153). Una pantalla y no un `resources`
  # porque no se crea ni se borra nada: se declara qué dicta y de ahí salen los
  # grados oficiales.
  # Quién no ha terminado de cargar sus notas (MOR-155). Solo GET: es una
  # pregunta, no una acción — el llamado de atención lo hace una persona.
  get "carga-de-notas", to: "carga_de_notas#index", as: :carga_de_notas

  # Los pasos opcionales del arranque que un colegio decide no hacer. Es lo
  # ÚNICO que la puesta en marcha guarda: todo lo demás se deduce de los datos.
  post "arranque/:clave/omitir", to: "arranque#omitir",  as: :omitir_paso
  post "arranque/:clave/retomar", to: "arranque#retomar", as: :retomar_paso

  get   "niveles", to: "niveles#edit",   as: :niveles_del_colegio
  patch "niveles", to: "niveles#update"

  get "verificar(/:code)", to: "verificaciones#show", as: :verificar

  # El portal del representante (MOR-110). Todo GET: es estrictamente de
  # lectura, y no alcanza con no poner botones — acá no hay ningún verbo que
  # escriba, así que construir la petición a mano tampoco sirve de nada.
  #
  # La excepción es el cambio de colegio, que solo toca la sesión.
  get  "representante",             to: "representante#index",  as: :representante
  get  "representante/hijo/:id",    to: "representante#hijo",   as: :hijo_representante
  post "representante/colegio",     to: "representante#cambiar_colegio", as: :cambiar_colegio_representante

  # Asistencia (MOR-111). La toma es de una SECCIÓN y un DÍA, y por eso el día
  # va como parámetro y no en la ruta: el caso normal es hoy, y escribir la
  # fecha en la URL sería pedirle al profesor que la piense.
  get  "asistencia",                    to: "asistencias#index",     as: :asistencias
  get  "asistencia/reporte",            to: "asistencias#reporte",   as: :reporte_asistencia
  get  "asistencia/alumno/:enrollment_id", to: "asistencias#historial", as: :historial_asistencia
  get  "asistencia/:seccion_id",        to: "asistencias#show",      as: :seccion_asistencia
  post "asistencia/:seccion_id",        to: "asistencias#create"

  resources :evaluation_moments, path: "lapsos", except: [ :show ]
  # El plan de evaluación de una sección: sus competencias e indicadores
  # (MOR-136). Cuelga de (sección, materia, lapso), que es la misma unidad de
  # trabajo de las evaluaciones.
  resources :competencies, path: "competencias", except: [ :show ] do
    collection do
      # Traer el plan del año pasado para revisarlo. POST porque escribe.
      post "sugerido", to: "competencies#sugerido", as: :traer
      # Copiarlo a las otras secciones que dicta este mismo profesor.
      post "copiar",   to: "competencies#copiar",   as: :copiar_a
    end

    # ⚠️ Los indicadores se editan UNO POR UNO, en su sitio (9 de septiembre).
    #
    # El formulario completo los sigue recibiendo todos juntos —separados por
    # líneas, para escribir el plan de cero o pegar los que uno ya tiene— y los
    # reemplaza enteros. Esto es la otra mitad: corregir una palabra en el
    # tercero sin volver a escribir los otros dos.
    resources :indicators, path: "indicadores", only: [ :create, :update, :destroy ]

    # ⚠️ El enganche se retiró de acá y vive en la EVALUACIÓN (9 de septiembre).
    #
    # Preguntaba al revés —de la competencia hacia las evaluaciones— cuando lo
    # que uno mira en el plan es la evaluación. Hoy son los chips de su fila, y
    # los guarda `evaluation_activities#update` con `competency_ids`. Una sola
    # puerta: dos maneras de hacer lo mismo es como se llegó a siete formas de
    # título.
  end

  resources :evaluation_activities, path: "evaluaciones" do
    # La planilla de carga. `notas/:student_id` hace upsert y borrado: mandar el
    # campo vacío devuelve al alumno a "sin nota", que NO es lo mismo que un 1.
    get   "notas",             to: "activity_grades#index",  as: :notas
    patch "notas/:student_id", to: "activity_grades#update", as: :nota
  end
  resources :grades, path: "grados" do
    resources :grade_subjects, path: "materias", only: [:create, :destroy]
  end
  # La rúbrica con que el colegio lee las notas de primaria (MOR-136).
  #
  # Singular por lo mismo que `colegio`: un colegio tiene UNA rúbrica, aunque
  # esté hecha de cinco niveles. `resources` daría `/rubricas/3/edit`, que es
  # pedirle a un director que edite un peldaño suelto de una escalera.
  resource :rubrica, only: [ :show, :update ], controller: "rubrics" do
    post :restablecer
  end

  # La identidad del colegio: nombre, ubicación y escudo. Singular porque un
  # colegio solo se administra a sí mismo — el suyo sale de la sesión.
  resource :colegio, only: [:show, :update], controller: "colegio" do
    delete :logo,  action: :quitar_logo,  as: :quitar_logo
    delete :firma, action: :quitar_firma, as: :quitar_firma
    delete :sello, action: :quitar_sello, as: :quitar_sello
  end

  # La activación del acceso (MOR-143). Es `recoverable` de Devise con otro
  # texto: el colegio genera el código, la persona elige su contraseña.
  #
  # ⚠️ PÚBLICA, y tiene que serlo: quien abre este enlace todavía no tiene
  # contraseña, así que no puede estar del otro lado de `authenticate_user!`.
  # Lo que la protege es el código, que es de un solo uso y caduca.
  get   "activar/:token", to: "activaciones#edit",   as: :activar
  patch "activar",        to: "activaciones#update", as: :activacion

  # Traer la matrícula de un colegio desde una planilla (MOR-126).
  #
  # `update` es el paso del MAPEO, no una edición: guarda qué columna del
  # archivo es cuál campo. Confirmar la carga es otro verbo y viene después.
  resources :importaciones, path: "importaciones", except: [:edit] do
    collection do
      # La planilla en blanco con su leyenda. Va en `collection` porque no
      # pertenece a ninguna importación: se descarga ANTES de que exista.
      get :plantilla
    end

    member do
      # Qué se va a cargar y qué no, ANTES de escribir nada.
      get :previsualizar

      # Qué pasó al cargarla. Es lo que la secretaria imprime para ir a pedir
      # los correos que faltan.
      get :resultado

      # Crear una sección que la planilla nombra y el colegio no tiene. Va acá
      # y no en `sections#create` porque el contexto importa: se crea sabiendo
      # cuántos alumnos de ESTA planilla la esperan, que es lo que distingue una
      # sección nueva de un error de tipeo.
      # Y el GRADO, cuando no existe ninguno que se le parezca. Va acá por lo
      # mismo que la sección: se crea sabiendo cuántas filas de ESTA planilla lo
      # esperan, que es lo que distingue un grado nuevo de un error de tipeo.
      # Y el AÑO ESCOLAR VIEJO con sus lapsos, que es lo que exige el historial:
      # una nota de 2023 no tiene dónde colgarse sin ellos.
      post :crear_ano_escolar

      post :crear_grado

      post :crear_seccion

      # La red de rescate: un colegio nuevo nace sin ningún año escolar, y sin
      # él no se puede crear ni una sección. Se ofrece donde falla, en vez de
      # mandar a la persona a Configuración a buscarlo.
      post :crear_periodo
    end
  end

  # ⚠️ El código de acceso es de la PERSONA, no de su rol, y por eso es la misma
  # ruta en los tres —y en el cuarto, el día que un alumno tenga que entrar—.
  #
  # POST y no GET: genera un código nuevo e invalida el anterior. Un enlace que
  # un navegador puede pre-cargar no debería cambiar nada.
  #
  # Cuelga de cada rol y no de un `/personas/:id` central a propósito: así el
  # `set_x` del controller, con el `default_scope` del rol, es el que decide si
  # esa persona es de este colegio. `User` no es `SchoolScoped` —una persona es
  # de la plataforma— y resolverlo a mano acá sería un IDOR que reparte llaves.
  # ⚠️ «Ya lo copié»: el enlace queda a la vista hasta que se descarta, y no un
  # solo render. Vive en la SESIÓN —no en el `flash`— porque el redirect de
  # Turbo produce DOS renders y el flash se consumía en el primero.
  #
  # Una sola ruta y no una por rol: en la sesión hay UN código, sea de un
  # representante, un profesor o un administrador.
  delete "codigo-a-la-vista", to: "codigos_a_la_vista#destroy", as: :codigo_a_la_vista

  concern :con_codigo_de_acceso do
    post :codigo, on: :member, action: :generar_codigo
  end

  # ⚠️ El mensaje cuelga del REPRESENTANTE (MOR-181). No es un recurso propio:
  # no se lista, no se edita y no se borra — se manda una vez y queda en la
  # auditoría. Un `resources :mensajes` habría prometido cuatro pantallas que no
  # existen.
  resources :representatives, path: "representantes", concerns: :con_codigo_de_acceso do
    member do
      post "mensaje", to: "mensajes#create", as: :mensaje_al
    end
  end
  resources :departments, path: "departamentos", except: [ :show ]
  resources :subjects, path: "materias"
  # ⚠️ Esta queda en INGLÉS, y es la excepción que confirma el criterio.
  #
  # «Años escolares» lleva ñ, y una URL no la admite: quedaba «anios-escolares»,
  # que no es español ni es nada. Daniel, viéndolo: «si no podemos escribir ñ o
  # acentos, es preferible en inglés».
  #
  # El resto de los recursos se escriben perfecto sin muletas —alumnos,
  # profesores, secciones, materias, grados, inscripciones, lapsos— y por eso van
  # en español. La regla no es «todo en español»: es que la URL se lea bien.
  resources :academic_periods, except: [ :show ] do
    # Copiar la estructura del año anterior (MOR-166): las secciones y quién
    # dicta qué. Cuelga del año DESTINO —es él quien recibe— y el origen viaja
    # en el cuerpo. POST y no GET: crea decenas de filas.
    member do
      get  "copiar", to: "copias_del_anio#new",    as: :copiar_al
      post "copiar", to: "copias_del_anio#create", as: :hacer_copia_al

      # Promover a los alumnos al año siguiente (MOR-169). Es la otra mitad de
      # septiembre: `copiar` arma el año nuevo y `promover` lo llena.
      get  "promover", to: "promociones#new",    as: :promover_al
      post "promover", to: "promociones#create", as: :hacer_promocion_al
    end
  end
  resources :sections, path: "secciones" do
    # ⚠️ La valoración descriptiva de Educación Inicial: un TEXTO por alumno y
    # área, guardado al salir del campo. No es una nota — ese nivel no las
    # tiene (ver `docs/specs/educacion-inicial.md`).
    patch "valoracion", to: "valoraciones#update", as: :valoracion

    # ⚠️ «Alumnos» es una PESTAÑA de la sección, con su propia URL (etapa ③).
    #
    # Era un panel que alternaba con `hidden`, y las otras tres —asistencia,
    # calificar, planificar— son pantallas de verdad con su controller. Media
    # fila de pestañas que navega y media que alterna no se puede explicar: el
    # botón de atrás funcionaría en unas y en otras no.
    # ⚠️ Las cuatro vistas de la sección viven EN la sección (etapa ③).
    #
    # Daniel: *«no me gustan ni Asistencia ni Planificación como URL, se
    # descontextualiza todo, se supone que estoy en mi espacio de trabajo —la
    # Sección— no para salir de él… no es solo "fingir" sino realmente estar en
    # la sección»*. Y tenía razón: una pestaña que te expulsa no divide nada.
    #
    # `/asistencia/:seccion_id` y `/competencias` siguen existiendo: son la
    # entrada por el MENÚ, para quien no viene de una sección.
    member do
      get "alumnos"
      get "asistencia"
      get "planificar"
    end

    resources :teacher_sections, path: "profesores", only: [:create, :destroy]

    # Los informes descriptivos del lapso (MOR-216). Cuelgan de la SECCIÓN
    # porque se escriben de a veinticinco, no de a uno: es una planilla, como
    # la de notas.
    #
    # `informes/:enrollment_id` guarda uno solo — el guardado es incremental y
    # cada informe viaja apenas se deja de escribir.
    get   "informes",                to: "informes#index",  as: :informes
    patch "informes/:enrollment_id", to: "informes#update", as: :informe
  end
  resources :enrollments, path: "inscripciones", except: [ :show ]
  # Los documentos oficiales del MPPE (MOR-99). Cuelgan del alumno o de su
  # inscripción, no de una sección: se emiten de a uno y a pedido de la familia.
  #
  # La 31059 acepta `.pdf` y `.xlsx`: el PDF es el documento terminado y el Excel
  # es el que el colegio completa mientras el formato se asienta.
  get "documentos/certificacion/:student_id",
      to: "documentos_oficiales#certificacion", as: :certificacion_de_calificaciones,
      defaults: { format: "pdf" }, constraints: { format: /pdf|xlsx/ }
  get "documentos/primaria/:enrollment_id",
      to: "documentos_oficiales#primaria", as: :documento_de_primaria

  # El buscador global de `⌘K` (MOR-149). Devuelve un fragmento, no una página:
  # el modal lo pega dentro de su `<turbo-frame>` mientras se escribe.
  get "buscar", to: "busquedas#show", as: :busqueda

  resources :students, path: "alumnos"
  resources :teachers, path: "profesores", concerns: :con_codigo_de_acceso
  resources :admins, path: "administradores", except: [ :show ], concerns: :con_codigo_de_acceso
  root "inicio#index"
end
