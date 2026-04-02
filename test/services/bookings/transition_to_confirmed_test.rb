require "test_helper"

class Bookings::TransitionToConfirmedTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(name: "Client transitions", slug: "client-transitions")
    @enseigne = @client.enseignes.create!(name: "Enseigne transitions")
    @service = @enseigne.services.create!(name: "Service transitions", duration_minutes: 30, price_cents: 1500)
  end

  test "allows transition to confirmed for non-expired pending booking" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      result = Bookings::TransitionToConfirmed.evaluate(booking: booking)

      assert result.allowed?
      assert_nil result.error_code
    end
  end

  test "forbids transition to confirmed for failed booking" do
    booking = @client.bookings.create!(
      enseigne: @enseigne,
      service: @service,
      booking_start_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
      booking_end_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
      booking_status: :failed
    )

    result = Bookings::TransitionToConfirmed.evaluate(booking: booking)

    assert_not result.allowed?
    assert_equal Bookings::Errors::NOT_PENDING, result.error_code
  end

  test "forbids transition to confirmed for confirmed booking" do
    booking = @client.bookings.create!(
      enseigne: @enseigne,
      service: @service,
      booking_start_time: Time.zone.local(2026, 3, 16, 12, 0, 0),
      booking_end_time: Time.zone.local(2026, 3, 16, 12, 30, 0),
      booking_status: :confirmed,
      customer_first_name: "Jean",
      customer_last_name: "Dupont",
      customer_email: "jean@example.com"
    )

    result = Bookings::TransitionToConfirmed.evaluate(booking: booking)

    assert_not result.allowed?
    assert_equal Bookings::Errors::NOT_PENDING, result.error_code
  end
end
