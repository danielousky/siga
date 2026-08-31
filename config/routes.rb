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
    get   "cuenta",        to: "devise/registrations#edit",   as: :edit_user_registration
    patch "cuenta",        to: "devise/registrations#update", as: :user_registration
    put   "cuenta",        to: "devise/registrations#update"
  end

  # El colegio que crea quien acaba de registrarse. No es `resources` porque no
  # se lista ni se borra: es un paso del camino de entrada.
  get  "mi-colegio/nuevo", to: "mi_colegio#new",    as: :nuevo_mi_colegio
  post "mi-colegio",       to: "mi_colegio#create", as: :mi_colegio
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
  resources :evaluation_activities, path: "evaluaciones" do
    # La planilla de carga. `notas/:student_id` hace upsert y borrado: mandar el
    # campo vacío devuelve al alumno a "sin nota", que NO es lo mismo que un 1.
    get   "notas",             to: "activity_grades#index",  as: :notas
    patch "notas/:student_id", to: "activity_grades#update", as: :nota
  end
  resources :grades, path: "grados" do
    resources :grade_subjects, path: "materias", only: [:create, :destroy]
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
  concern :con_codigo_de_acceso do
    post :codigo, on: :member, action: :generar_codigo
  end

  resources :representatives, path: "representantes", concerns: :con_codigo_de_acceso
  resources :departments, path: "departamentos", except: [ :show ]
  resources :subjects, path: "materias"
  resources :academic_periods, path: "anios-escolares", except: [ :show ]
  resources :sections, path: "secciones" do
    resources :teacher_sections, path: "profesores", only: [:create, :destroy]
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
