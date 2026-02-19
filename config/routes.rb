Rails.application.routes.draw do
  devise_for :users
  get 'inicio/index'

  resources :evaluation_moments
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
