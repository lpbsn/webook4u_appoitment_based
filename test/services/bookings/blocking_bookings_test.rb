require "test_helper"

class Bookings::BlockingBookingsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(name: "Salon", slug: "salon")
    @enseigne = @client.enseignes.create!(name: "Enseigne salon")
    @other_enseigne = @client.enseignes.create!(name: "Enseigne annexe")
    @service = @enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)
  end

  test "blocking_overlaps returns blocking bookings overlapping given interval" do
    travel_to Time.zone.local(2026, 3, 16, 8, 0, 0) do
      # One confirmed booking from 10:00 to 10:30
      blocking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time:   Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :confirmed,
        customer_first_name: "Léonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      # Interval 10:15–10:45 should overlap
      overlaps = Bookings::BlockingBookings.overlapping(
        client: @client,
        resource: Bookings::Resource.for_enseigne(client: @client, enseigne: @enseigne),
        start_time: Time.zone.local(2026, 3, 16, 10, 15, 0),
        end_time:   Time.zone.local(2026, 3, 16, 10, 45, 0)
      )

      assert_includes overlaps, blocking
    end
  end

  test "blocking_intervals_for_range returns intervals for overlapping bookings only" do
    travel_to Time.zone.local(2026, 3, 16, 8, 0, 0) do
      day_start = Time.zone.local(2026, 3, 16, 9, 0, 0)
      day_end   = Time.zone.local(2026, 3, 16, 18, 0, 0)

      # Booking fully inside range
      inside = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time:   Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :confirmed,
        customer_first_name: "Léonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      # Booking starting before range and ending inside
      cross = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 8, 30, 0),
        booking_end_time:   Time.zone.local(2026, 3, 16, 9, 30, 0),
        booking_status: :confirmed,
        customer_first_name: "Other",
        customer_last_name: "User",
        customer_email: "other@example.com"
      )

      # Booking completely before range should not appear
      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 7, 0, 0),
        booking_end_time:   Time.zone.local(2026, 3, 16, 8, 0, 0),
        booking_status: :confirmed,
        customer_first_name: "Too",
        customer_last_name: "Early",
        customer_email: "early@example.com"
      )

      intervals = Bookings::BlockingBookings.intervals_for_range(
        client: @client,
        resource: Bookings::Resource.for_enseigne(client: @client, enseigne: @enseigne),
        range_start: day_start,
        range_end: day_end
      )

      assert_includes intervals, [ inside.booking_start_time, inside.booking_end_time ]
      assert_includes intervals, [ cross.booking_start_time, cross.booking_end_time ]
      # Just ensure only two intervals are returned in this scenario
      assert_equal 2, intervals.size
    end
  end

  test "blocking bookings are scoped to enseigne" do
    travel_to Time.zone.local(2026, 3, 16, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :confirmed,
        customer_first_name: "Jean",
        customer_last_name: "Dupont",
        customer_email: "jean@example.com"
      )

      overlaps = Bookings::BlockingBookings.overlapping(
        client: @client,
        resource: Bookings::Resource.for_enseigne(client: @client, enseigne: @other_enseigne),
        start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        end_time: Time.zone.local(2026, 3, 16, 10, 30, 0)
      )

      assert_not_includes overlaps, booking
    end
  end
end
