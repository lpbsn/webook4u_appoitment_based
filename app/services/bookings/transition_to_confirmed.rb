# frozen_string_literal: true

module Bookings
  class TransitionToConfirmed
    Result = Struct.new(:allowed?, :error_code, keyword_init: true)

    def self.evaluate(booking:)
      return Result.new(allowed?: false, error_code: Errors::NOT_PENDING) unless booking.pending?
      return Result.new(allowed?: false, error_code: Errors::SESSION_EXPIRED) if booking.expired?

      Result.new(allowed?: true, error_code: nil)
    end
  end
end
