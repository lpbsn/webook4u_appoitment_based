# frozen_string_literal: true

module Bookings
  class Availability
    def self.overlap?(start_a, end_a, start_b, end_b)
      start_a < end_b && end_a > start_b
    end
  end
end
