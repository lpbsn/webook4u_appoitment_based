class BookingsController < ApplicationController
  layout "booking"
  before_action :authenticate_user!
  before_action :load_client
  before_action :ensure_current_user_matches_client!
  before_action :load_creation_context, only: %i[create_pending]
  before_action :load_public_pending_booking, only: %i[show create]
  before_action :load_booking_by_confirmation_token, only: %i[success]

  def create_pending
    result = Bookings::CreatePending.new(
      client: @client,
      enseigne: @enseigne,
      service: @service,
      booking_start_time: @booking_start_time,
      user: current_user,
      assignment_mode: create_pending_assignment_mode,
      staff_id: staff_id_param
    ).call

    unless result.success?
      redirect_to_pending_selection(result.error_message)
      return
    end

    redirect_to pending_booking_path(@client.slug, result.booking.pending_access_token)
  end

  def create
    result = Bookings::Confirm.new(
      booking: @booking,
      booking_params: booking_params
    ).call

    if result.success?
      redirect_to booking_success_path(@client.slug, @booking.confirmation_token)
    else
      if result.error_code == Bookings::Errors::FORM_INVALID
        hydrate_booking_view_context
        flash.now[:alert] = result.error_message
        render :show, status: :unprocessable_entity
      else
        redirect_to public_client_path(
          @client.slug,
          enseigne_id: redirect_enseigne_id(@enseigne),
          service_id: @service.id,
          date: @booking.booking_start_time.to_date
        ),
                    alert: result.error_message
      end
    end
  end

  def show
    hydrate_booking_view_context
    render :show
  end

  def success
  end

  private

  def load_client
    @client = Client.find_by!(slug: params[:slug])
  end

  def ensure_current_user_matches_client!
    return unless current_user
    return if current_user.client_id == @client.id

    sign_out(current_user)
    redirect_to new_user_session_path(redirect_to: request.fullpath),
                alert: "Your session does not match this booking context. Please sign in again."
  end

  def load_creation_context
    @enseigne = @client.enseignes.active.find(params[:enseigne_id])
    @service = @enseigne.services.find(params[:service_id])
    @booking_start_time = Bookings::Input.safe_time(params[:start_time])
    @booking_date = redirect_date(@booking_start_time)
    @assignment_mode = assignment_mode_param
    @staff_id = staff_id_param
    @search_mode = search_mode_param
    @selected_days_of_week = selected_days_of_week_param
    @start_time_min = start_time_min_param
    @start_time_max = start_time_max_param
  end

  def load_public_pending_booking
    resolution = Bookings::PublicPendingTokenResolver.call(client: @client, token: params[:token])

    if resolution.active_pending?
      @booking = resolution.booking
      hydrate_booking_relations
      return
    end

    if resolution.expired_pending? || resolution.expired_purged?
      redirect_to_session_expired_for(
        enseigne_id: resolution.context[:enseigne_id],
        service_id: resolution.context[:service_id],
        date: resolution.context[:date]
      )
      return
    end

    raise ActiveRecord::RecordNotFound
  end

  def redirect_to_session_expired_for(enseigne_id:, service_id:, date:)
    enseigne = @client.enseignes.find_by(id: enseigne_id)

    redirect_to public_client_path(
      @client.slug,
      enseigne_id: redirect_enseigne_id(enseigne),
      service_id: service_id,
      date: date
    ),
                alert: Bookings::Errors.message_for(Bookings::Errors::SESSION_EXPIRED)
  end

  def load_booking_by_confirmation_token
    @booking = @client.bookings.find_by!(confirmation_token: params[:token], user_id: [ current_user.id, nil ])
    hydrate_booking_relations
  end

  def booking_params
    params.require(:booking).permit(
      :customer_first_name,
      :customer_last_name,
      :customer_email
    )
  end

  def redirect_date(booking_start_time)
    Bookings::Input.safe_date(params[:date]) || booking_start_time&.to_date
  end

  def hydrate_booking_relations
    @service = @booking.service
    @enseigne = @booking.enseigne
  end

  def hydrate_booking_view_context
    hydrate_booking_relations
    prefill_booking_customer_from_current_user
    @booking_start_time = @booking.booking_start_time
    @booking_end_time = @booking.booking_end_time
  end

  def redirect_to_pending_selection(message)
    redirect_params = {
      enseigne_id: @enseigne.id,
      service_id: @service.id,
      date: @booking_date,
      assignment_mode: @assignment_mode,
      staff_id: @staff_id,
      search_mode: @search_mode
    }
  
    if @search_mode == "first_available"
      redirect_params[:selected_days_of_week] = @selected_days_of_week
      redirect_params[:start_time_min] = @start_time_min
      redirect_params[:start_time_max] = @start_time_max
    end
  
    redirect_to public_client_path(@client.slug, redirect_params), alert: message
  end

  def redirect_enseigne_id(enseigne)
    enseigne&.active? ? enseigne.id : nil
  end

  def assignment_mode_param
    params[:assignment_mode].presence
  end

  def create_pending_assignment_mode
    assignment_mode_param || "automatic"
  end

  def staff_id_param
    params[:staff_id].presence
  end

  def search_mode_param
    params[:search_mode].presence
  end
  
  def selected_days_of_week_param
    Array(params[:selected_days_of_week]).reject(&:blank?)
  end
  
  def start_time_min_param
    params[:start_time_min].presence
  end
  
  def start_time_max_param
    params[:start_time_max].presence
  end

  def prefill_booking_customer_from_current_user
    return unless current_user

    @booking.customer_first_name = current_user.first_name if @booking.customer_first_name.blank?
    @booking.customer_last_name = current_user.last_name if @booking.customer_last_name.blank?
    @booking.customer_email = current_user.email if @booking.customer_email.blank?
  end
end
