# frozen_string_literal: true

module Bookings
  class TransitionToFailedFromPayment
    Result = Struct.new(:allowed?, :error_code, keyword_init: true)

    def self.evaluate(booking:)
      return Result.new(allowed?: false, error_code: Errors::NOT_PENDING) unless booking.pending?

      Result.new(allowed?: true, error_code: nil)
    end
  end
end
