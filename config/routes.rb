Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#login"
      get "auth/me", to: "auth#me"

      resources :medications, only: :index
      resources :patients, only: %i[index show]
      resources :prescriptions, only: %i[index show create]
      resources :doses, only: %i[index update]
      get "adherence", to: "adherence#show"
      resources :audit_logs, only: :index
    end
  end
end
