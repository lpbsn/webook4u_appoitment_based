require "test_helper"

class Bookings::StaffBlockingBookingsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(name: "Client staff blocking", slug: "client-staff-blocking")
    @enseigne = @client.enseignes.create!(name: "Enseigne staff blocking")
    @service = @enseigne.services.create!(name: "Service", duration_minutes: 30, price_cents: 2500)
    @staff = @enseigne.staffs.create!(name: "Staff A", active: true)
    @other_staff = @enseigne.staffs.create!(name: "Staff B", active: true)
  end

  test "includes confirmed and active pending for the selected staff only" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :confirmed,
        customer_first_name: "Demo",
        customer_last_name: "A",
        customer_email: "demo.a@example.com"
      )

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @other_staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      intervals = Bookings::StaffBlockingBookings.intervals_for_range(
        staff: @staff,
        range_start: Time.zone.local(2026, 3, 16, 9, 0, 0),
        range_end: Time.zone.local(2026, 3, 16, 12, 0, 0)
      )

      assert_equal [
        [ Time.zone.local(2026, 3, 16, 10, 0, 0), Time.zone.local(2026, 3, 16, 10, 30, 0) ],
        [ Time.zone.local(2026, 3, 16, 11, 0, 0), Time.zone.local(2026, 3, 16, 11, 30, 0) ]
      ], intervals
    end
  end

  test "ignores expired pending bookings" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
        booking_status: :pending,
        booking_expires_at: 5.minutes.ago
      )

      intervals = Bookings::StaffBlockingBookings.intervals_for_range(
        staff: @staff,
        range_start: Time.zone.local(2026, 3, 16, 9, 0, 0),
        range_end: Time.zone.local(2026, 3, 16, 12, 0, 0)
      )

      assert_equal [], intervals
    end
  end
end
