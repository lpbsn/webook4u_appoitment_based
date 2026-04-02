# frozen_string_literal: true

module Bookings
  class ConfirmStaffRevalidation
    Result = Struct.new(:confirmable?, :error_code, :error_message, :staff, keyword_init: true)

    def initialize(booking:)
      @booking = booking
    end

    def call
      transition = TransitionToConfirmed.evaluate(booking: booking)
      return failure(transition.error_code) unless transition.allowed?
      return failure(Errors::SLOT_UNAVAILABLE) unless assigned_staff_valid?
      return failure(Errors::SLOT_UNAVAILABLE) if blocked_slot?

      success
    end

    private

    attr_reader :booking

    def assigned_staff
      @assigned_staff ||= booking.staff
    end

    def assigned_staff_valid?
      return false if assigned_staff.blank?

      assigned_staff.enseigne_id == booking.enseigne_id
    end

    def blocked_slot?
      StaffBlockingBookings.overlapping(
        staff: assigned_staff,
        start_time: booking.booking_start_time,
        end_time: booking.booking_end_time,
        exclude_booking_id: booking.id
      ).exists?
    end

    def success
      Result.new(
        confirmable?: true,
        error_code: nil,
        error_message: nil,
        staff: assigned_staff
      )
    end

    def failure(code)
      Result.new(
        confirmable?: false,
        error_code: code,
        error_message: Errors.message_for(code),
        staff: assigned_staff
      )
    end
  end
end
