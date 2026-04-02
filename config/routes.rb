Rails.application.routes.draw do
  get "/up", to: "rails/health#show", as: :rails_health_check

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
