class PublicClientsController < ApplicationController
  layout "booking"
  # =========================================================
  # PAGE PRINCIPALE DE RÉSERVATION
  # 1️) choisir une enseigne
  # 2️) choisir une prestation
  # 3️) choisir une date
  # 4️) afficher les créneaux disponibles
  # =========================================================
  def show
    page = Bookings::PublicPage.new(
      slug: params[:slug],
      enseigne_id: params[:enseigne_id],
      service_id: params[:service_id],
      date_param: params[:date]
    ).call

    @client = page.client
    @enseignes = page.enseignes
    @selected_enseigne = page.selected_enseigne
    @services = page.services
    @selected_service = page.selected_service
    @date = page.date
    @slots = page.slots
  end
end
