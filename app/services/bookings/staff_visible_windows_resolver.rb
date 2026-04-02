# frozen_string_literal: true

module Bookings
  class StaffVisibleWindowsResolver
    def initialize(staff:, service:, enseigne:, date:)
      @staff = staff
      @service = service
      @enseigne = enseigne
      @date = date.to_date
    end

    def call
      return [] if staff.blank? || service.blank? || enseigne.blank?
      return [] if service.duration_minutes.blank?
      return [] if staff.enseigne_id != enseigne.id
      return [] if service.enseigne_id != enseigne.id

      enseigne_windows = ScheduleResolver.new(client: enseigne.client, enseigne: enseigne, date: date).call
      return [] if enseigne_windows.empty?

      weekly_windows = StaffWeeklyAvailabilityResolver.new(staff: staff, date: date).call
      return [] if weekly_windows.empty?

      staff_real_windows = StaffUnavailabilitySubtractor.new(
        staff: staff,
        date: date,
        windows: weekly_windows
      ).call
      return [] if staff_real_windows.empty?

      intersected_windows(enseigne_windows: enseigne_windows, staff_windows: staff_real_windows)
        .select { |start_time, end_time| end_time - start_time >= minimum_window_seconds }
    end

    private

    attr_reader :staff, :service, :enseigne, :date

    def minimum_window_seconds
      @minimum_window_seconds ||= service.duration_minutes.minutes
    end

    def intersected_windows(enseigne_windows:, staff_windows:)
      results = []

      enseigne_windows.each do |enseigne_start, enseigne_end|
        staff_windows.each do |staff_start, staff_end|
          next unless Availability.overlap?(enseigne_start, enseigne_end, staff_start, staff_end)

          intersection_start = [ enseigne_start, staff_start ].max
          intersection_end = [ enseigne_end, staff_end ].min
          next unless intersection_start < intersection_end

          results << [ intersection_start, intersection_end ]
        end
      end

      results.sort_by(&:first)
    end
  end
end
