# frozen_string_literal: true

module Bookings
  class StaffWeeklyAvailabilityResolver
    def initialize(staff:, date:)
      @staff = staff
      @date = date.to_date
    end

    def call
      return [] if staff.blank?

      weekly_windows_for_day.map do |availability|
        [
          build_time(availability.opens_at),
          build_time(availability.closes_at)
        ]
      end
    end

    private

    attr_reader :staff, :date

    def weekly_windows_for_day
      staff.staff_availabilities
           .where(day_of_week: date.wday)
           .where("opens_at < closes_at")
           .order(:opens_at, :closes_at)
    end

    def build_time(time_value)
      date.in_time_zone.change(
        hour: time_value.hour,
        min: time_value.min,
        sec: time_value.sec
      )
    end
  end
end
