# frozen_string_literal: true

module Bookings
  class PublicPendingTokenResolver
    Result = Struct.new(:status, :booking, :context, keyword_init: true) do
      def active_pending?
        status == :active_pending
      end

      def expired_pending?
        status == :expired_pending
      end

      def expired_purged?
        status == :expired_purged
      end

      def not_found?
        status == :not_found
      end
    end

    def self.call(client:, token:)
      new(client: client, token: token).call
    end

    def initialize(client:, token:)
      @client = client
      @token = token
    end

    def call
      booking_with_token = client.bookings.find_by(pending_access_token: token)
      if booking_with_token.present?
        return active_pending_result(booking_with_token) if booking_with_token.pending? && !booking_with_token.expired?
        return expired_pending_result(booking_with_token) if booking_with_token.pending?

        # Defensive precedence: if a booking currently carries this token, never resolve to
        # a historical tombstone context.
        return Result.new(status: :not_found, booking: nil, context: nil)
      end

      expired_link = ExpiredBookingLink.find_by(client_id: client.id, pending_access_token: token)
      return expired_purged_result(expired_link) if expired_link.present?

      Result.new(status: :not_found, booking: nil, context: nil)
    end

    private

    attr_reader :client, :token

    def active_pending_result(booking)
      Result.new(status: :active_pending, booking: booking, context: nil)
    end

    def expired_pending_result(booking)
      Result.new(
        status: :expired_pending,
        booking: booking,
        context: context_hash(
          enseigne_id: booking.enseigne_id,
          service_id: booking.service_id,
          date: booking.booking_start_time.to_date
        )
      )
    end

    def expired_purged_result(expired_link)
      Result.new(
        status: :expired_purged,
        booking: nil,
        context: context_hash(
          enseigne_id: expired_link.enseigne_id,
          service_id: expired_link.service_id,
          date: expired_link.booking_date
        )
      )
    end

    def context_hash(enseigne_id:, service_id:, date:)
      {
        enseigne_id: enseigne_id,
        service_id: service_id,
        date: date
      }
    end
  end
end
