require "test_helper"

class BookingRateLimitTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
    @previous_pending_limit = ENV["BOOKINGS_PENDING_RATE_LIMIT"]
    @previous_confirm_limit = ENV["BOOKINGS_CONFIRM_RATE_LIMIT"]
    @previous_window = ENV["BOOKINGS_RATE_LIMIT_WINDOW_SECONDS"]

    @client = Client.create!(name: "Rate Limit Salon", slug: "rate-limit-salon")
    @enseigne = @client.enseignes.create!(name: "Enseigne RL", full_address: "1 rue RL", active: true)
    create_weekday_opening_hours_for_enseigne(@enseigne)

    @service = @enseigne.services.create!(name: "Coupe RL", duration_minutes: 30, price_cents: 2500)
    @staff = @enseigne.staffs.create!(name: "Emma RL", active: true)
    @staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: @staff, service: @service)
    ServiceAssignmentCursor.find_or_create_by!(service: @service)
  end

  teardown do
    ENV["BOOKINGS_PENDING_RATE_LIMIT"] = @previous_pending_limit
    ENV["BOOKINGS_CONFIRM_RATE_LIMIT"] = @previous_confirm_limit
    ENV["BOOKINGS_RATE_LIMIT_WINDOW_SECONDS"] = @previous_window
    Rails.cache.clear
  end

  test "pending creation rate limit redirects to public page with alert" do
    ENV["BOOKINGS_PENDING_RATE_LIMIT"] = "1"
    ENV["BOOKINGS_RATE_LIMIT_WINDOW_SECONDS"] = "600"

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      first_slot = Time.zone.local(2026, 3, 16, 10, 0, 0)
      second_slot = Time.zone.local(2026, 3, 16, 10, 30, 0)

      assert_difference("Booking.count", 1) do
        post service_bookings_path(@client.slug, @service),
             params: { enseigne_id: @enseigne.id, start_time: first_slot, date: "2026-03-16" }
      end

      assert_no_difference("Booking.count") do
        post service_bookings_path(@client.slug, @service),
             params: { enseigne_id: @enseigne.id, start_time: second_slot, date: "2026-03-16" }
      end

      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: "2026-03-16"
      )
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::RATE_LIMIT_EXCEEDED), flash[:alert]
    end
  end

  test "confirmation rate limit returns 429 and keeps booking pending" do
    ENV["BOOKINGS_CONFIRM_RATE_LIMIT"] = "0"
    ENV["BOOKINGS_RATE_LIMIT_WINDOW_SECONDS"] = "600"

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = Booking.create!(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      post confirm_booking_path(@client.slug, booking.pending_access_token), params: {
        booking: {
          customer_first_name: "Jane",
          customer_last_name: "Doe",
          customer_email: "jane@example.com"
        }
      }

      assert_response :too_many_requests
      assert_equal Bookings::Errors.message_for(Bookings::Errors::RATE_LIMIT_EXCEEDED), response.body

      booking.reload
      assert_equal "pending", booking.booking_status
    end
  end

  test "rate limiter stays within limit under concurrent calls" do
    ENV["BOOKINGS_PENDING_RATE_LIMIT"] = "3"
    ENV["BOOKINGS_RATE_LIMIT_WINDOW_SECONDS"] = "600"

    results = []
    results_lock = Mutex.new

    threads = Array.new(12) do
      Thread.new do
        allowed = Bookings::RateLimiter.allowed?(
          client: @client,
          ip: "203.0.113.77",
          action: Bookings::RateLimiter::PENDING_ACTION
        )

        results_lock.synchronize { results << allowed }
      end
    end

    threads.each(&:join)

    assert_equal 12, results.size
    assert_operator results.count(true), :<=, 3
    assert_operator results.count(false), :>=, 9
  end
end
