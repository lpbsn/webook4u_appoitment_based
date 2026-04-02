# frozen_string_literal: true

module Bookings
  class ScheduleResolver
    def initialize(client:, date:, enseigne: nil)
      @client = client
      @enseigne = enseigne
      @date = date.to_date
    end

    def call
      source_hours.map do |opening_hour|
        [
          build_time(opening_hour.opens_at),
          build_time(opening_hour.closes_at)
        ]
      end
    end

    private

    attr_reader :client, :enseigne, :date

    def source_hours
      hours_for(enseigne&.enseigne_opening_hours)
    end

    def hours_for(scope)
      return [] if scope.blank?

      scope.where(day_of_week: date.wday).order(:opens_at, :closes_at)
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
