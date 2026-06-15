Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get    "login",  to: "sessions#new",     as: :login
  post   "login",  to: "sessions#create"
  get    "forgot-password", to: "sessions#forgot_password", as: :forgot_password
  post   "forgot-password/send-otp", to: "sessions#send_forgot_password_otp", as: :send_forgot_password_otp
  post   "forgot-password/reset", to: "sessions#reset_forgot_password", as: :reset_forgot_password
  get    "vrp-agreement", to: "sessions#agreement", as: :vrp_agreement
  post   "vrp-agreement", to: "sessions#complete_agreement"
  get    "logout", to: "sessions#destroy", as: nil
  delete "logout", to: "sessions#destroy", as: :logout

  root "sessions#new"
  get "dashboard", to: "modules#dashboard", as: :dashboard

  resources :users, except: [:show] do
    patch :toggle_status, on: :member
    patch :set_status, on: :member
  end

  resources :afls, only: [:index] do
    post :import, on: :collection
    get "import_reports/:id", action: :import_report, as: :import_report, on: :collection
  end

  resources :vrp_ics_mappings, only: [:index, :create, :destroy] do
    collection do
      get :ics_options
      get :village_options
      get :farmers
    end
  end

  resources :target_mappings, only: [:index, :create, :destroy] do
    get :vrp_mappings, on: :collection
  end

  resources :modules, param: :slug, only: [:show], controller: :modules do
    post :records, action: :create, on: :member
    post :import, action: :import, on: :member
    get :export, action: :export, on: :member
    patch :bulk_update, action: :bulk_update, on: :member

    resources :records, controller: :modules, only: [:edit, :update, :destroy] do
      patch :toggle, action: :toggle_status, on: :member
      patch :set_status, action: :set_status, on: :member
      patch :send_for_approval, action: :send_bill_for_approval, on: :member
      patch :set_bill_state, action: :set_bill_state, on: :member
      patch :approve_bill, action: :approve_bill, on: :member
      patch :reject_bill, action: :reject_bill, on: :member
      patch :return_bill, action: :return_bill, on: :member
      get :download_bill, action: :download_bill, on: :member
    end
  end

  resources :vrps, only: [:index, :new, :create, :edit, :update, :show, :destroy] do
    collection do
      get :approvals
    end

    member do
      patch :set_active
      patch :send_for_approval
      patch :approve
      patch :reject
    end
  end
end
