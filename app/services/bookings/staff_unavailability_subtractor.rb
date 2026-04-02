# frozen_string_literal: true

module Bookings
  class StaffUnavailabilitySubtractor
    def initialize(staff:, date:, windows:)
      @staff = staff
      @date = date.to_date
      @windows = windows
    end

    def call
      return [] if staff.blank?

      remaining_windows = normalized_windows
      return [] if remaining_windows.empty?

      day_unavailabilities.each do |unavailability|
        remaining_windows = subtract_interval(
          windows: remaining_windows,
          blocked_start: unavailability.starts_at,
          blocked_end: unavailability.ends_at
        )
        break if remaining_windows.empty?
      end

      remaining_windows
    end

    private

    attr_reader :staff, :date, :windows

    def normalized_windows
      Array(windows).filter_map do |window|
        start_time, end_time = window
        next if start_time.blank? || end_time.blank?
        next unless start_time < end_time

        [ start_time, end_time ]
      end.sort_by(&:first)
    end

    def day_unavailabilities
      staff.staff_unavailabilities
           .where("starts_at < ? AND ends_at > ?", day_end, day_start)
           .order(:starts_at, :ends_at)
    end

    def day_start
      @day_start ||= date.in_time_zone.beginning_of_day
    end

    def day_end
      @day_end ||= day_start + 1.day
    end

    def subtract_interval(windows:, blocked_start:, blocked_end:)
      windows.flat_map do |window_start, window_end|
        subtract_from_window(
          window_start: window_start,
          window_end: window_end,
          blocked_start: blocked_start,
          blocked_end: blocked_end
        )
      end
    end

    def subtract_from_window(window_start:, window_end:, blocked_start:, blocked_end:)
      return [ [ window_start, window_end ] ] unless Availability.overlap?(window_start, window_end, blocked_start, blocked_end)

      segments = []
      segments << [ window_start, blocked_start ] if window_start < blocked_start
      segments << [ blocked_end, window_end ] if blocked_end < window_end
      segments
    end
  end
end
