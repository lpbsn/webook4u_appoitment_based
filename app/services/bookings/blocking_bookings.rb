# frozen_string_literal: true

module Bookings
  module BlockingBookings
    module_function

    # Returns a relation of blocking bookings (confirmed + active pending)
    # whose intervals [booking_start_time, booking_end_time) overlap the given range
    # for the provided reservable resource.
    #
    # Today this resource is still resolved from the enseigne context.
    # The future multi-capacity target is a staff-backed resource, so callers
    # should keep passing an explicit Resource instead of reasoning directly
    # with enseigne ids in blocking queries.
    def overlapping(client:, resource:, start_time:, end_time:, exclude_booking_id: nil)
      scope = (resource&.bookings_scope || client.bookings)
        .blocking_slot
        .where("booking_start_time < ? AND booking_end_time > ?", end_time, start_time)
      scope = scope.where.not(id: exclude_booking_id) if exclude_booking_id.present?
      scope
    end

    # Returns pairs [booking_start_time, booking_end_time] for blocking bookings
    # that overlap the given range [range_start, range_end).
    def intervals_for_range(client:, resource:, range_start:, range_end:)
      overlapping(client: client, resource: resource, start_time: range_start, end_time: range_end)
        .pluck(:booking_start_time, :booking_end_time)
    end
  end
end
