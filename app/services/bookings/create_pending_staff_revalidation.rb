# frozen_string_literal: true

module Bookings
  class CreatePendingStaffRevalidation
    Result = Struct.new(
      :bookable?,
      :error_code,
      :error_message,
      :booking_start_time,
      :booking_end_time,
      :staff,
      :matches_schedule_grid?,
      keyword_init: true
    ) do
      def creatable?
        bookable? && matches_schedule_grid?
      end
    end

    def initialize(client:, enseigne:, service:, staff:, booking_start_time:)
      @client = client
      @enseigne = enseigne
      @service = service
      @staff = staff
      @booking_start_time = booking_start_time
    end

    def call
      return failure(Errors::INVALID_SLOT, matches_schedule_grid: false) if booking_start_time.nil?
      return failure(Errors::SLOT_UNAVAILABLE, matches_schedule_grid: false) unless eligible_staff_candidate?

      schedule_grid_match = matches_schedule_grid?
      return failure(Errors::SLOT_UNAVAILABLE, matches_schedule_grid: schedule_grid_match) if blocked_slot?

      success(matches_schedule_grid: schedule_grid_match)
    end

    private

    attr_reader :client, :enseigne, :service, :staff, :booking_start_time

    def booking_end_time
      @booking_end_time ||= booking_start_time + service.duration_minutes.minutes
    end

    def eligible_staff_candidate?
      return false if client.blank? || enseigne.blank? || service.blank? || staff.blank?
      return false unless enseigne.client_id == client.id
      return false unless service.enseigne_id == enseigne.id
      return false unless staff.enseigne_id == enseigne.id
      return false unless staff.active?

      StaffServiceCapability.exists?(staff_id: staff.id, service_id: service.id)
    end

    def matches_schedule_grid?
      return false if booking_start_time.nil?

      staff_windows.any? do |window_start, window_end|
        fits_within_interval?(window_start, window_end) &&
          starts_on_interval_grid?(window_start) &&
          respects_minimum_notice?
      end
    end

    def staff_windows
      @staff_windows ||= StaffVisibleWindowsResolver.new(
        staff: staff,
        service: service,
        enseigne: enseigne,
        date: booking_start_time.to_date
      ).call
    end

    def blocked_slot?
      StaffBlockingBookings.overlapping(
        staff: staff,
        start_time: booking_start_time,
        end_time: booking_end_time
      ).exists?
    end

    def fits_within_interval?(interval_start, interval_end)
      booking_start_time >= interval_start && booking_end_time <= interval_end
    end

    def starts_on_interval_grid?(interval_start)
      offset_seconds = booking_start_time.to_i - interval_start.to_i
      return false if offset_seconds.negative?

      (offset_seconds % BookingRules.slot_duration.to_i).zero?
    end

    def respects_minimum_notice?
      booking_start_time >= BookingRules.minimum_bookable_time
    end

    def success(matches_schedule_grid:)
      Result.new(
        bookable?: true,
        error_code: nil,
        error_message: nil,
        booking_start_time: booking_start_time,
        booking_end_time: booking_end_time,
        staff: staff,
        matches_schedule_grid?: matches_schedule_grid
      )
    end

    def failure(code, matches_schedule_grid:)
      Result.new(
        bookable?: false,
        error_code: code,
        error_message: Errors.message_for(code),
        booking_start_time: booking_start_time,
        booking_end_time: booking_start_time.present? ? booking_end_time : nil,
        staff: staff,
        matches_schedule_grid?: matches_schedule_grid
      )
    end
  end
end
