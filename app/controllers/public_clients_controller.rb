class PublicClientsController < ApplicationController
  layout :booking_layout
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
      assignment_mode_param: params[:assignment_mode],
      staff_id_param: params[:staff_id],
      search_mode_param: params[:search_mode],
      selected_start_time_param: params[:selected_start_time],
      date_param: params[:date],
      first_available_selected_days_of_week_param: params[:selected_days_of_week],
      first_available_start_time_min_param: params[:start_time_min],
      first_available_start_time_max_param: params[:start_time_max]
    ).call

    @client = page.client
    @enseignes = page.enseignes
    @selected_enseigne = page.selected_enseigne
    @services = page.services
    @selected_service = page.selected_service
    @assignment_mode = page.assignment_mode
    @eligible_staffs = page.eligible_staffs
    @selected_staff = page.selected_staff
    @search_mode = page.search_mode
    @selected_start_time = page.selected_start_time
    @date = page.date
    @slots = page.slots
    @precise_date_days = page.precise_date_days

    @first_available_selected_days_of_week = page.first_available_selected_days_of_week
    @first_available_start_time_min = page.first_available_start_time_min
    @first_available_start_time_max = page.first_available_start_time_max
    @first_available_available_days_of_week = page.first_available_available_days_of_week
    @first_available_errors = page.first_available_errors
    @first_available_slot = page.first_available_slot
    @first_available_search_performed = page.first_available_search_performed
  end

  private

  def booking_layout
    turbo_frame_request? ? false : "booking"
  end
end
