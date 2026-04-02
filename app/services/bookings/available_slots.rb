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
      return [] if opening_intervals.empty?

      slots.reject { |slot| slot_overlaps_blocking_booking?(slot) }
    end

    private

    attr_reader :client, :service, :date, :enseigne

    def slots
      # Generate the theoretical schedule grid before filtering out slots that
      # should no longer be shown in the public UX.
      result = []

      opening_intervals.each do |(start_of_day, end_of_day)|
        current_slot = start_of_day

        while current_slot + service.duration_minutes.minutes <= end_of_day
          result << current_slot
          current_slot += BookingRules.slot_duration
        end
      end

      result.reject { |slot| slot < BookingRules.minimum_bookable_time }
    end

    def blocking_intervals_for_day
      @blocking_intervals_for_day ||= begin
        resource = Resource.for_enseigne(client: client, enseigne: enseigne)

        BlockingBookings.intervals_for_range(
          client: client,
          resource: resource,
          range_start: opening_intervals.first.first,
          range_end: opening_intervals.last.last
        )
      end
    end

    def opening_intervals
      @opening_intervals ||= ScheduleResolver.new(
        client: client,
        enseigne: enseigne,
        date: date
      ).call
    end

    def slot_overlaps_blocking_booking?(slot_start)
      slot_end = slot_start + service.duration_minutes.minutes

      blocking_intervals_for_day.any? do |(booking_start, booking_end)|
        Availability.overlap?(booking_start, booking_end, slot_start, slot_end)
      end
    end
  end
end
