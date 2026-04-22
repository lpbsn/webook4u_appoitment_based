Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations"
  }
  get "/up", to: "rails/health#show", as: :rails_health_check

  namespace :admin do
    root to: "bookings#index"
    resources :bookings, only: :index
    resources :clients, only: %i[index new create edit update]
    resources :users, only: %i[index new create edit update] do
      patch :toggle_active, on: :member
    end
  end

  namespace :client do
    root to: "bookings#index"
    resources :bookings, only: :index
  end

  namespace :booker do
    root to: "bookings#index"
    resources :bookings, only: :index
  end

  get "/:slug", to: "public_clients#show", as: :public_client

  # création explicite du booking pending
  post "/:slug/services/:service_id/bookings", to: "bookings#create_pending", as: :service_bookings

  # affichage du formulaire pour un booking pending existant
  get "/:slug/bookings/:token", to: "bookings#show", as: :pending_booking

  # confirmation du booking
  post "/:slug/bookings/:token/confirm", to: "bookings#create", as: :confirm_booking

  # page succès
  get "/:slug/bookings/:token/success", to: "bookings#success", as: :booking_success
end
