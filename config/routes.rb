Rails.application.routes.draw do
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
  devise_for :users, skip: [:registrations]

  devise_scope :user do
    get   "cuenta",        to: "devise/registrations#edit",   as: :edit_user_registration
    patch "cuenta",        to: "devise/registrations#update", as: :user_registration
    put   "cuenta",        to: "devise/registrations#update"
  end
  get "inicio/index"

  # Solicitudes de demo (público)
  resources :demo_requests, only: [:new, :create, :index, :show, :update] do
    collection do
      get :success
    end
  end

  # Dashboards específicos por rol
  namespace :dashboards do
    get "administrador", to: "administrador#index"
    get "profesor",      to: "profesor#index"
    get "estudiante",    to: "estudiante#index"
    get "notas",         to: "notas#index"
    resources :activity_logs, only: [:index]
  end

  # Emisión de boletines (dirección y secretaría) y su verificación PÚBLICA.
  # La segunda va sin sesión a propósito: quien verifica normalmente no tiene
  # cuenta en el sistema. Ver MOR-98.
  resources :report_cards, only: [:index, :create], path: "boletines"
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

  resources :evaluation_moments
  resources :evaluation_activities do
    # La planilla de carga. `notas/:student_id` hace upsert y borrado: mandar el
    # campo vacío devuelve al alumno a "sin nota", que NO es lo mismo que un 1.
    get   "notas",             to: "activity_grades#index",  as: :notas
    patch "notas/:student_id", to: "activity_grades#update", as: :nota
  end
  resources :grades do
    resources :grade_subjects, only: [:create, :destroy]
  end
  resources :representatives, path: "representantes"
  resources :departments
  resources :subjects
  resources :academic_periods
  resources :sections do
    resources :teacher_sections, only: [:create, :destroy]
  end
  resources :enrollments
  resources :students
  resources :teachers
  resources :admins

  root "inicio#index"
end
