Rails.application.routes.draw do
  devise_for :users
  get 'inicio/index'

  # Solicitudes de demo (público)
  resources :demo_requests, only: [:new, :create, :index, :show, :update] do
    collection do
      get :success
    end
  end

  # Dashboards específicos por rol
  namespace :dashboards do
    get 'administrador', to: 'administrador#index'
    get 'profesor',      to: 'profesor#index'
    get 'estudiante',    to: 'estudiante#index'
    resources :activity_logs, only: [:index]
  end

  resources :evaluation_moments
  resources :evaluation_activities
  resources :grades do
    resources :grade_subjects, only: [:create, :destroy]
  end
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
