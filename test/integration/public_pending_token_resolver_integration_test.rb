# frozen_string_literal: true

require "test_helper"

class PublicPendingTokenResolverIntegrationTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  test "resolver keeps tombstone context isolated from a new booking cycle" do
    client = Client.create!(name: "Client resolver integration", slug: "client-resolver-integration")
    enseigne = client.enseignes.create!(name: "Enseigne resolver integration")
    service = enseigne.services.create!(name: "Service resolver integration", duration_minutes: 30, price_cents: 2500)

    travel_to Time.zone.local(2026, 4, 1, 10, 0, 0) do
      expired_booking = client.bookings.create!(
        enseigne: enseigne,
        service: service,
        booking_start_time: Time.zone.local(2026, 4, 2, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 4, 2, 10, 30, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )
      expired_token = expired_booking.pending_access_token

      Bookings::PurgeExpiredPending.call(cutoff: Time.zone.now)
      first_old_result = Bookings::PublicPendingTokenResolver.call(client: client, token: expired_token)
      assert first_old_result.expired_purged?

      new_booking = client.bookings.create!(
        enseigne: enseigne,
        service: service,
        booking_start_time: Time.zone.local(2026, 4, 2, 11, 0, 0),
        booking_end_time: Time.zone.local(2026, 4, 2, 11, 30, 0),
        booking_status: :pending,
        booking_expires_at: 5.minutes.from_now
      )
      assert_not_equal expired_token, new_booking.pending_access_token

      new_result = Bookings::PublicPendingTokenResolver.call(client: client, token: new_booking.pending_access_token)
      second_old_result = Bookings::PublicPendingTokenResolver.call(client: client, token: expired_token)

      assert new_result.active_pending?
      assert_equal new_booking.id, new_result.booking.id
      assert second_old_result.expired_purged?
      assert_equal Date.new(2026, 4, 2), second_old_result.context[:date]
    end
  end
end
