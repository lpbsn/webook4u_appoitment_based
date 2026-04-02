# frozen_string_literal: true

module Bookings
  class Confirm
    Result = Struct.new(:success?, :booking, :error_code, :error_message, keyword_init: true)

    def initialize(booking:, booking_params:)
      @booking = booking
      @booking_params = booking_params
    end

    def call
      assigned_staff = booking.staff
      return failure(Errors::SLOT_UNAVAILABLE) if assigned_staff.blank?

      result = nil

      SlotLock.with_service_rotation_lock(service: booking.service) do
        SlotLock.with_staff_lock(staff: assigned_staff) do
          result = confirm_under_lock
        end
      end

      result
    rescue ActiveRecord::RecordInvalid
      failure(Errors::FORM_INVALID)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
      raise unless Errors.booking_conflict_exception?(error)

      failure(Errors::SLOT_TAKEN_DURING_CONFIRM)
    end

    private

    attr_reader :booking, :booking_params

    def confirm_under_lock
      decision = revalidation_decision
      return failure(decision.error_code) unless decision.confirmable?

      booking.update!(
        confirmation_token: SecureRandom.uuid,
        customer_first_name: booking_params[:customer_first_name],
        customer_last_name: booking_params[:customer_last_name],
        customer_email: booking_params[:customer_email],
        booking_status: :confirmed
      )
      advance_assignment_cursor!(staff: booking.staff)

      success(booking)
    end

    def revalidation_decision
      Bookings::ConfirmStaffRevalidation.new(booking: booking).call
    end

    def advance_assignment_cursor!(staff:)
      cursor = ServiceAssignmentCursor.find_or_create_by!(service: booking.service)
      cursor.update!(last_confirmed_staff: staff)
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
