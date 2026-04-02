# frozen_string_literal: true

module Bookings
  # Builds the visible booking grid for the public UX on a given day.
  #
  # This service answers an interface question: which start times should still
  # be shown to the user right now?
  #
  # It intentionally remains separate from transactional booking validation:
  # CreatePending and Confirm rely on SlotDecision for business reservability,
  # while AvailableSlots only produces the currently visible slot list from
  # schedule intervals, booking window rules and blocking bookings.
  class AvailableSlots
    def initialize(client:, service:, date:, enseigne: nil)
      @client = client
      @service = service
      @date = date.to_date
      @enseigne = enseigne
    end

    def call
      return [] if enseigne.blank? || service.blank?
      return [] if service.enseigne_id != enseigne.id

      eligible_staffs.flat_map { |staff| slots_for_staff(staff) }.uniq.sort
    end

    private

    attr_reader :client, :service, :date, :enseigne

    def eligible_staffs
      @eligible_staffs ||= EligibleStaffsResolver.new(service: service, enseigne: enseigne).call
    end

    def slots_for_staff(staff)
      staff_windows = visible_windows_for_staff(staff)
      return [] if staff_windows.empty?

      slots = slots_from_windows(staff_windows)
      blocking_intervals = blocking_intervals_for_staff(staff, staff_windows)

      slots.reject do |slot|
        slot_end = slot + service.duration_minutes.minutes

        blocking_intervals.any? do |booking_start, booking_end|
          Availability.overlap?(booking_start, booking_end, slot, slot_end)
        end
      end
    end

    def visible_windows_for_staff(staff)
      StaffVisibleWindowsResolver.new(
        staff: staff,
        service: service,
        enseigne: enseigne,
        date: date
      ).call
    end

    def slots_from_windows(windows)
      result = []

      windows.each do |(start_of_day, end_of_day)|
        current_slot = start_of_day

        while current_slot + service.duration_minutes.minutes <= end_of_day
          result << current_slot
          current_slot += BookingRules.slot_duration
        end
      end

      result.reject { |slot| slot < BookingRules.minimum_bookable_time }
    end

    def blocking_intervals_for_staff(staff, windows)
      StaffBlockingBookings.intervals_for_range(
        staff: staff,
        range_start: windows.first.first,
        range_end: windows.last.last
      )
    end
  end
end
