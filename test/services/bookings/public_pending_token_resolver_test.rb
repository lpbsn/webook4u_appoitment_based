require "test_helper"

class Bookings::PublicPendingTokenResolverTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(name: "Client resolver", slug: "client-resolver")
    @enseigne = @client.enseignes.create!(name: "Enseigne resolver")
    @service = @enseigne.services.create!(name: "Service resolver", duration_minutes: 30, price_cents: 2000)
    @staff = @enseigne.staffs.create!(name: "Staff resolver", active: true)
  end

  test "returns active_pending for a non-expired pending booking" do
    travel_to Time.zone.local(2026, 4, 1, 10, 0, 0) do
      booking = create_pending_booking(
        starts_at: Time.zone.local(2026, 4, 2, 10, 0, 0),
        expires_at: 5.minutes.from_now
      )

      result = Bookings::PublicPendingTokenResolver.call(client: @client, token: booking.pending_access_token)

      assert result.active_pending?
      assert_equal booking, result.booking
      assert_nil result.context
    end
  end

  test "returns expired_pending for an expired pending booking still present in database" do
    travel_to Time.zone.local(2026, 4, 1, 10, 0, 0) do
      booking = create_pending_booking(
        starts_at: Time.zone.local(2026, 4, 2, 11, 0, 0),
        expires_at: 1.minute.ago
      )

      result = Bookings::PublicPendingTokenResolver.call(client: @client, token: booking.pending_access_token)

      assert result.expired_pending?
      assert_equal booking, result.booking
      assert_equal @enseigne.id, result.context[:enseigne_id]
      assert_equal @service.id, result.context[:service_id]
      assert_equal Date.new(2026, 4, 2), result.context[:date]
    end
  end

  test "returns expired_purged for an expired pending booking deleted after purge" do
    travel_to Time.zone.local(2026, 4, 1, 10, 0, 0) do
      booking = create_pending_booking(
        starts_at: Time.zone.local(2026, 4, 2, 12, 0, 0),
        expires_at: 1.minute.ago
      )
      token = booking.pending_access_token

      Bookings::PurgeExpiredPending.call(cutoff: Time.zone.now)

      result = Bookings::PublicPendingTokenResolver.call(client: @client, token: token)

      assert result.expired_purged?
      assert_nil result.booking
      assert_equal @enseigne.id, result.context[:enseigne_id]
      assert_equal @service.id, result.context[:service_id]
      assert_equal Date.new(2026, 4, 2), result.context[:date]
    end
  end

  test "does not recycle tombstone token when a new pending booking is created" do
    travel_to Time.zone.local(2026, 4, 1, 10, 0, 0) do
      expired_booking = create_pending_booking(
        starts_at: Time.zone.local(2026, 4, 2, 14, 0, 0),
        expires_at: 1.minute.ago
      )
      expired_token = expired_booking.pending_access_token

      Bookings::PurgeExpiredPending.call(cutoff: Time.zone.now)

      new_booking = create_pending_booking(
        starts_at: Time.zone.local(2026, 4, 2, 15, 0, 0),
        expires_at: 5.minutes.from_now
      )

      assert_not_equal expired_token, new_booking.pending_access_token

      old_token_result = Bookings::PublicPendingTokenResolver.call(client: @client, token: expired_token)
      new_token_result = Bookings::PublicPendingTokenResolver.call(client: @client, token: new_booking.pending_access_token)

      assert old_token_result.expired_purged?
      assert_nil old_token_result.booking
      assert new_token_result.active_pending?
      assert_equal new_booking, new_token_result.booking
    end
  end

  test "returns not_found for an unknown token" do
    result = Bookings::PublicPendingTokenResolver.call(client: @client, token: "unknown-token")

    assert result.not_found?
    assert_nil result.booking
    assert_nil result.context
  end

  test "returns not_found for a confirmed booking token" do
    booking = @client.bookings.create!(
      enseigne: @enseigne,
      service: @service,
      staff: @staff,
      booking_start_time: Time.zone.local(2026, 4, 2, 13, 0, 0),
      booking_end_time: Time.zone.local(2026, 4, 2, 13, 30, 0),
      booking_status: :confirmed,
      pending_access_token: SecureRandom.urlsafe_base64(24),
      customer_first_name: "Jean",
      customer_last_name: "Dupont",
      customer_email: "jean@example.com"
    )

    result = Bookings::PublicPendingTokenResolver.call(client: @client, token: booking.pending_access_token)

    assert result.not_found?
    assert_nil result.booking
    assert_nil result.context
  end

  private

  def create_pending_booking(starts_at:, expires_at:)
    @client.bookings.create!(
      enseigne: @enseigne,
      service: @service,
      booking_start_time: starts_at,
      booking_end_time: starts_at + 30.minutes,
      booking_status: :pending,
      booking_expires_at: expires_at
    )
  end
end
