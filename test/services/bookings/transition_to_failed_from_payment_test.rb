require "test_helper"

class Bookings::TransitionToFailedFromPaymentTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(name: "Client failed transition", slug: "client-failed-transition")
    @enseigne = @client.enseignes.create!(name: "Enseigne failed transition")
    @service = @enseigne.services.create!(name: "Service failed transition", duration_minutes: 30, price_cents: 1800)
    @staff = @enseigne.staffs.create!(name: "Staff failed transition", active: true)
  end

  test "allows transition for pending booking" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 9, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 9, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      result = Bookings::TransitionToFailedFromPayment.evaluate(booking: booking)

      assert result.allowed?
      assert_nil result.error_code
    end
  end

  test "forbids transition when booking is already confirmed" do
    booking = @client.bookings.create!(
      enseigne: @enseigne,
      service: @service,
      staff: @staff,
      booking_start_time: Time.zone.local(2026, 3, 16, 9, 30, 0),
      booking_end_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
      booking_status: :confirmed,
      customer_first_name: "Grace",
      customer_last_name: "Hopper",
      customer_email: "grace@example.com"
    )

    result = Bookings::TransitionToFailedFromPayment.evaluate(booking: booking)

    assert_not result.allowed?
    assert_equal Bookings::Errors::NOT_PENDING, result.error_code
  end
end
