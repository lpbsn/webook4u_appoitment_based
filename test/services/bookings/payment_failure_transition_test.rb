require "test_helper"

class Bookings::PaymentFailureTransitionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(name: "Client payment failure", slug: "client-payment-failure")
    @enseigne = @client.enseignes.create!(name: "Enseigne payment failure")
    @service = @enseigne.services.create!(name: "Service payment failure", duration_minutes: 30, price_cents: 2000)
    @staff = @enseigne.staffs.create!(name: "Staff payment failure", active: true)
  end

  test "transitions a pending booking to failed through payment seam" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      result = Bookings::PaymentFailureTransition.new(
        booking: booking,
        stripe_session_id: "cs_test_123",
        stripe_payment_intent: "pi_test_456"
      ).call

      assert result.success?
      booking.reload
      assert_equal "failed", booking.booking_status
      assert_equal "cs_test_123", booking.stripe_session_id
      assert_equal "pi_test_456", booking.stripe_payment_intent
    end
  end

  test "rejects payment failure transition when booking is not pending" do
    booking = @client.bookings.create!(
      enseigne: @enseigne,
      service: @service,
      staff: @staff,
      booking_start_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
      booking_end_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
      booking_status: :confirmed,
      customer_first_name: "Ada",
      customer_last_name: "Lovelace",
      customer_email: "ada@example.com"
    )

    result = Bookings::PaymentFailureTransition.new(booking: booking).call

    assert_not result.success?
    assert_equal Bookings::Errors::NOT_PENDING, result.error_code
    booking.reload
    assert_equal "confirmed", booking.booking_status
  end
end
