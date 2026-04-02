# frozen_string_literal: true

module Bookings
  module StaffBlockingBookings
    module_function

    def overlapping(staff:, start_time:, end_time:, exclude_booking_id: nil)
      scope = staff.bookings
                   .blocking_slot
                   .where("booking_start_time < ? AND booking_end_time > ?", end_time, start_time)
      scope = scope.where.not(id: exclude_booking_id) if exclude_booking_id.present?
      scope
    end

    def intervals_for_range(staff:, range_start:, range_end:)
      overlapping(staff: staff, start_time: range_start, end_time: range_end)
        .pluck(:booking_start_time, :booking_end_time)
    end
  end
end
