# Single source of truth for booking-related business rules.
# Used by: Bookings::AvailableSlots, Bookings::Input, Bookings::CreatePending, Booking model.
# Do not put domain logic here—only constants and simple predicates.

module BookingRules
  SLOT_DURATION_MINUTES = 30
  MIN_NOTICE_MINUTES = 30
  MAX_FUTURE_DAYS = 30
  PENDING_EXPIRATION_MINUTES = 5

  class << self
    def business_today
      Time.current.in_time_zone(business_timezone).to_date
    end

    def slot_duration
      SLOT_DURATION_MINUTES.minutes
    end

    def min_notice_minutes
      MIN_NOTICE_MINUTES
    end

    def minimum_bookable_time(now: Time.zone.now)
      now + min_notice_minutes.minutes
    end

    def max_future_days
      MAX_FUTURE_DAYS
    end

    def pending_expiration_minutes
      PENDING_EXPIRATION_MINUTES
    end

    def pending_expires_at(from: Time.zone.now)
      from + pending_expiration_minutes.minutes
    end

    # Predicate: is this booking past its expiration time? (single source for temporal validity rule)
    def booking_expired?(booking, now: Time.zone.now)
      return true if booking.booking_expires_at.blank?
      booking.booking_expires_at <= now
    end

    private

    def business_timezone
      Rails.application.config.time_zone
    end
  end
end
