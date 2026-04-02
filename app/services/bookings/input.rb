# frozen_string_literal: true

module Bookings
  module Input
    def self.safe_date(date_param, today: BookingRules.business_today, max_future_days: BookingRules.max_future_days)
      return nil if date_param.blank?

      parsed_date = Date.iso8601(date_param)
      return nil if parsed_date < today
      return nil if parsed_date > today + max_future_days.days

      parsed_date
    rescue ArgumentError
      nil
    end

    def self.safe_time(time_param, now: Time.zone.now, max_future_days: BookingRules.max_future_days)
      return nil if time_param.blank?

      parsed_time = Time.zone.parse(time_param)
      return nil if parsed_time.nil?
      return nil if parsed_time < now
      return nil if parsed_time > now + max_future_days.days

      parsed_time
    rescue ArgumentError, TypeError
      nil
    end
  end
end
