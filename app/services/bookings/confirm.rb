# frozen_string_literal: true

module Bookings
  class Confirm
    Result = Struct.new(:success?, :booking, :error_code, :error_message, keyword_init: true)

    def initialize(booking:, booking_params:)
      @booking = booking
      @booking_params = booking_params
    end

    def call
      transition = TransitionToConfirmed.evaluate(booking: booking)
      return failure(transition.error_code) unless transition.allowed?

      resource = Resource.for_enseigne(client: booking.client, enseigne: booking.enseigne)

      # Etape 1: la confirmation est sérialisée au niveau de l'enseigne entière.
      # Ce n'est pas la granularité métier cible long terme; c'est un compromis
      # temporaire avant l'introduction d'une ressource (staff) plus fine à réserver.
      SlotLock.with_lock(resource: resource) do
        decision = slot_decision(resource: resource)
        return failure(decision.error_code) unless decision.bookable?

        booking.update!(
          confirmation_token: SecureRandom.uuid,
          customer_first_name: booking_params[:customer_first_name],
          customer_last_name: booking_params[:customer_last_name],
          customer_email: booking_params[:customer_email],
          booking_status: :confirmed
        )
      end

      success(booking)
    rescue ActiveRecord::RecordInvalid
      failure(Errors::FORM_INVALID)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
      raise unless Errors.booking_conflict_exception?(error)

      failure(Errors::SLOT_TAKEN_DURING_CONFIRM)
    end

    private

    attr_reader :booking, :booking_params

    def slot_decision(resource:)
      Bookings::SlotDecision.new(
        client: booking.client,
        enseigne: booking.enseigne,
        service: booking.service,
        booking_start_time: booking.booking_start_time,
        exclude_booking_id: booking.id,
        resource: resource
      ).call
    end

    def success(booking)
      Result.new(success?: true, booking: booking, error_code: nil, error_message: nil)
    end

    def failure(code)
      Result.new(
        success?: false,
        booking: booking,
        error_code: code,
        error_message: Errors.message_for(code)
      )
    end
  end
end
