# frozen_string_literal: true

module Bookings
  class CreatePending
    Result = Struct.new(:success?, :booking, :error_code, :error_message, keyword_init: true)

    def initialize(client:, service:, booking_start_time:, enseigne:)
      @client = client
      @enseigne = enseigne
      @service = service
      @booking_start_time = booking_start_time
    end

    def call
      return failure(Errors::PENDING_CREATION_FAILED) unless valid_enseigne_context?
      return failure(Errors::PENDING_CREATION_FAILED) unless valid_service_context?

      resource = Resource.for_enseigne(client: client, enseigne: enseigne)
      decision = slot_decision(resource: resource)
      decision_failure_code = failure_code_for(decision)
      return failure(decision_failure_code) if decision_failure_code.present?

      booking = nil

      # Etape 1: on sérialise au niveau de l'enseigne entière.
      # Cela évite les conflits concurrents pendant la fenêtre critique,
      # au prix d'une concurrence plus faible entre créneaux indépendants
      # d'une même enseigne.
      SlotLock.with_lock(resource: resource) do
        locked_decision = slot_decision(resource: resource)
        locked_decision_failure_code = failure_code_for(locked_decision)
        return failure(locked_decision_failure_code) if locked_decision_failure_code.present?

        booking = Booking.create!(
          client: client,
          enseigne: enseigne,
          service: service,
          booking_start_time: locked_decision.booking_start_time,
          booking_end_time: locked_decision.booking_end_time,
          booking_status: :pending,
          booking_expires_at: BookingRules.pending_expires_at
        )
      end

      success(booking)
    rescue ActiveRecord::RecordInvalid
      failure(Errors::PENDING_CREATION_FAILED)
    rescue ActiveRecord::StatementInvalid => error
      raise unless Errors.booking_conflict_exception?(error)

      failure(Errors::SLOT_UNAVAILABLE)
    end

    private

    attr_reader :client, :enseigne, :service, :booking_start_time

    def valid_enseigne_context?
      enseigne.present? && enseigne.active? && enseigne.client_id == client.id
    end

    def valid_service_context?
      service.present? && service.enseigne_id == enseigne.id
    end

    def slot_decision(resource:)
      Bookings::SlotDecision.new(
        client: client,
        enseigne: enseigne,
        service: service,
        booking_start_time: booking_start_time,
        resource: resource
      ).call
    end

    def failure_code_for(decision)
      return decision.error_code unless decision.bookable?
      return Errors::SLOT_NOT_BOOKABLE unless decision.creatable?

      nil
    end

    def success(booking)
      Result.new(success?: true, booking: booking, error_code: nil, error_message: nil)
    end

    def failure(code)
      Result.new(
        success?: false,
        booking: nil,
        error_code: code,
        error_message: Errors.message_for(code)
      )
    end
  end
end
