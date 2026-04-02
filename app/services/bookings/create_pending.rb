# frozen_string_literal: true

module Bookings
  class CreatePending
    Result = Struct.new(:success?, :booking, :error_code, :error_message, keyword_init: true)

    def initialize(client:, service:, booking_start_time:, enseigne:, user: nil)
      @client = client
      @enseigne = enseigne
      @service = service
      @booking_start_time = booking_start_time
      @user = user
    end

    def call
      return failure(Errors::INVALID_SLOT) if booking_start_time.nil?
      return failure(Errors::PENDING_CREATION_FAILED) unless valid_enseigne_context?
      return failure(Errors::PENDING_CREATION_FAILED) unless valid_service_context?
      failure_code = Errors::SLOT_UNAVAILABLE

      SlotLock.with_service_rotation_lock(service: service) do
        candidates = service_assignment_cursor.eligible_staffs_in_rotation_order
        return failure(Errors::SLOT_UNAVAILABLE) if candidates.empty?

        candidates.each do |candidate_staff|
          created_booking = nil

          SlotLock.with_staff_lock(staff: candidate_staff) do
            decision = revalidation_decision(staff: candidate_staff)
            candidate_failure_code = failure_code_for(decision)
            failure_code = candidate_failure_code if candidate_failure_code.present? && candidate_failure_code != Errors::SLOT_UNAVAILABLE

            if decision.creatable?
              created_booking = Booking.create!(
                client: client,
                enseigne: enseigne,
                service: service,
                user: user,
                staff: candidate_staff,
                booking_start_time: decision.booking_start_time,
                booking_end_time: decision.booking_end_time,
                booking_status: :pending,
                booking_expires_at: BookingRules.pending_expires_at
              )
            end
          end

          return success(created_booking) if created_booking.present?
        end
      end

      failure(failure_code)
    rescue ActiveRecord::RecordInvalid
      failure(Errors::PENDING_CREATION_FAILED)
    rescue ActiveRecord::StatementInvalid => error
      raise unless Errors.booking_conflict_exception?(error)

      failure(Errors::SLOT_UNAVAILABLE)
    end

    private

    attr_reader :client, :enseigne, :service, :booking_start_time, :user

    def valid_enseigne_context?
      enseigne.present? && enseigne.active? && enseigne.client_id == client.id
    end

    def valid_service_context?
      service.present? && service.enseigne_id == enseigne.id
    end

    def service_assignment_cursor
      @service_assignment_cursor ||= ServiceAssignmentCursor.find_or_create_by!(service: service)
    end

    def revalidation_decision(staff:)
      Bookings::CreatePendingStaffRevalidation.new(
        client: client,
        enseigne: enseigne,
        service: service,
        booking_start_time: booking_start_time,
        staff: staff
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
